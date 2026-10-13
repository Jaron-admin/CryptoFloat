#include "taskbar_protocol.h"
#include <atomic>
#include <deque>
#include <mutex>
#include <thread>

namespace {
void Close(HANDLE* handle) { if (*handle && *handle != INVALID_HANDLE_VALUE) CloseHandle(*handle); *handle = nullptr; }
struct Child {
  HANDLE input = nullptr, output = nullptr, process = nullptr, job = nullptr;
  ~Child() {
    Close(&input); Close(&output);
    if (process && WaitForSingleObject(process, 200) != WAIT_OBJECT_0) TerminateProcess(process, 0);
    Close(&process); Close(&job);
  }
  bool Start() {
    SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    HANDLE child_input = nullptr, child_output = nullptr, parent = nullptr;
    const bool pipes = CreatePipe(&child_input, &input, &security, 65536) &&
        CreatePipe(&output, &child_output, &security, 65536) &&
        SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0) &&
        SetHandleInformation(output, HANDLE_FLAG_INHERIT, 0) &&
        DuplicateHandle(GetCurrentProcess(), GetCurrentProcess(), GetCurrentProcess(), &parent,
                        SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, TRUE, 0);
    auto cleanup = [&] { Close(&child_input); Close(&child_output); Close(&parent); };
    if (!pipes) { cleanup(); return false; }
    HANDLE inherited[] = {child_input, child_output, parent};
    SIZE_T size = 0; InitializeProcThreadAttributeList(nullptr, 1, 0, &size);
    std::vector<uint8_t> attributes(size);
    STARTUPINFOEXW startup{}; startup.StartupInfo.cb = sizeof(startup);
    startup.lpAttributeList = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributes.data());
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &size)) { cleanup(); return false; }
    bool allowed = UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
        inherited, sizeof(inherited), nullptr, nullptr) != FALSE;
    wchar_t module[32768]{}; DWORD length = GetModuleFileNameW(nullptr, module, 32768);
    std::wstring path(module, length); auto slash = path.find_last_of(L"\\/");
    if (slash == std::wstring::npos || length == 0 || length >= 32768) allowed = false;
    path.resize(slash == std::wstring::npos ? 0 : slash + 1);
#ifdef TASKBAR_ISOLATED_TEST
    path += L"taskbar_isolated_helper.exe";
#else
    path += L"metricperch_taskbar.exe";
#endif
    std::wstring command = L"\"" + path + L"\" " +
        std::to_wstring(reinterpret_cast<uintptr_t>(child_input)) + L" " +
        std::to_wstring(reinterpret_cast<uintptr_t>(child_output)) + L" " +
        std::to_wstring(reinterpret_cast<uintptr_t>(parent));
    PROCESS_INFORMATION info{};
    bool launched = allowed && CreateProcessW(path.c_str(), command.data(), nullptr, nullptr, TRUE,
        CREATE_NO_WINDOW | CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT,
        nullptr, nullptr, &startup.StartupInfo, &info) != FALSE;
    DeleteProcThreadAttributeList(startup.lpAttributeList); cleanup();
    if (!launched) return false;
    process = info.hProcess;
    job = CreateJobObjectW(nullptr, nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    // Parent handle + pipe watchdog still ensures teardown when a containing job
    // disallows nested assignment (e.g. an older Windows launcher).
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits)) ||
        !AssignProcessToJobObject(job, process)) Close(&job);
    const bool resumed = ResumeThread(info.hThread) != static_cast<DWORD>(-1); CloseHandle(info.hThread);
    return resumed;
  }
};
}
struct TaskbarHost::Impl {
  HANDLE stop = nullptr;
  std::thread worker;
  std::mutex mutex;
  TaskbarFrame pending;
  uint64_t revision = 0;
  taskbar::Status status = taskbar::Status::disabled;
  std::deque<std::string> actions;
  std::atomic<HANDLE> child_process{nullptr};
  Impl() {
    pending.enabled = false; stop = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (stop) worker = std::thread([this] { Run(); });
    else status = taskbar::Status::error;
  }
  ~Impl() {
    if (stop) SetEvent(stop);
    if (worker.joinable()) {
      CancelSynchronousIo(worker.native_handle());
      // No waiting on a pipe/provider from the UI thread. Only this owned helper
      // may be terminated, after its graceful disconnect window expires.
      if (WaitForSingleObject(worker.native_handle(), 600) != WAIT_OBJECT_0) {
        std::lock_guard<std::mutex> lock(mutex);
        HANDLE process = child_process.load(); if (process) TerminateProcess(process, 0);
        CancelSynchronousIo(worker.native_handle());
      }
      worker.join();
    }
    Close(&stop);
  }
  void Run() {
    while (WaitForSingleObject(stop, 20) == WAIT_TIMEOUT) {
      bool enabled;
      { std::lock_guard<std::mutex> lock(mutex); enabled = pending.enabled; }
      if (!enabled) continue;
      Child child;
      if (!child.Start()) {
        { std::lock_guard<std::mutex> lock(mutex); status = taskbar::Status::error; }
        WaitForSingleObject(stop, 2000); continue;
      }
      { std::lock_guard<std::mutex> lock(mutex); child_process.store(child.process); status = taskbar::Status::waiting; }
      uint64_t sent = 0; std::vector<uint8_t> buffer;
      while (WaitForSingleObject(stop, 10) == WAIT_TIMEOUT && WaitForSingleObject(child.process, 0) == WAIT_TIMEOUT) {
        TaskbarFrame frame; uint64_t current;
        { std::lock_guard<std::mutex> lock(mutex); frame = pending; current = revision; }
        if (current != sent) {
          std::vector<uint8_t> payload;
          if (!taskbar::EncodeFrame(frame, &payload) || !taskbar::WritePacket(child.input, taskbar::PacketType::frame, payload)) break;
          sent = current;
        }
        std::vector<taskbar::Packet> packets;
        if (!taskbar::ReadPipeAvailable(child.output, &buffer, &packets)) break;
        bool valid = true;
        for (const auto& packet : packets) {
          uint32_t code;
          if ((packet.type != taskbar::PacketType::status && packet.type != taskbar::PacketType::action) ||
              !taskbar::DecodeCode(packet.payload, 5, &code)) { valid = false; break; }
          std::lock_guard<std::mutex> lock(mutex);
          if (packet.type == taskbar::PacketType::status) {
            status = pending.enabled ? static_cast<taskbar::Status>(code) : taskbar::Status::disabled;
          } else if (code != 0 && actions.size() < 32) actions.emplace_back(taskbar::ActionName(static_cast<taskbar::Action>(code)));
        }
        if (!valid) break;
      }
      { std::lock_guard<std::mutex> lock(mutex);
        child_process.store(nullptr); status = pending.enabled ? taskbar::Status::waiting : taskbar::Status::disabled;
      }
      // Disconnect before the retry delay so an old display is withdrawn now.
      Close(&child.input); Close(&child.output);
      // Child destructor bounds shutdown of this owned process. Retry after
      // Explorer/helper failures without spinning.
      if (WaitForSingleObject(stop, 1000) == WAIT_OBJECT_0) break;
    }
  }
};
TaskbarHost::TaskbarHost(HWND owner) : impl_(std::make_unique<Impl>()) { (void)owner; }
TaskbarHost::~TaskbarHost() = default;
std::string TaskbarHost::Update(const TaskbarFrame& frame) {
  if (!taskbar::ValidateFrame(frame)) return "error";
  std::lock_guard<std::mutex> lock(impl_->mutex);
  impl_->pending = frame; ++impl_->revision;
  if (!frame.enabled) impl_->status = taskbar::Status::disabled;
  else if (impl_->status == taskbar::Status::disabled) impl_->status = taskbar::Status::waiting;
  return taskbar::StatusName(impl_->status);
}
std::string TaskbarHost::TakeAction() {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  if (impl_->actions.empty()) return {};
  auto result = std::move(impl_->actions.front()); impl_->actions.pop_front(); return result;
}
