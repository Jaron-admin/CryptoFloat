#include <windows.h>

#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "single_instance.h"

namespace {

constexpr DWORD kTimeout = 8000;
constexpr DWORD kForwardedExit = 10;
constexpr DWORD kFailureExit = 20;

class Handle {
 public:
  explicit Handle(HANDLE value = nullptr) : value_(value) {}
  ~Handle() {
    if (value_) CloseHandle(value_);
  }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  HANDLE get() const { return value_; }
  explicit operator bool() const { return value_ != nullptr; }

 private:
  HANDLE value_;
};

struct Counts {
  volatile LONG primary;
  volatile LONG forwarded;
  volatile LONG errors;
};

std::wstring Name(const std::wstring& scope, const wchar_t* suffix) {
  return L"Local\\" + scope + suffix;
}

HANDLE Event(const std::wstring& scope, const wchar_t* suffix) {
  return CreateEventW(nullptr, TRUE, FALSE, Name(scope, suffix).c_str());
}

LONG ReadCount(volatile LONG* count) {
  return InterlockedCompareExchange(count, 0, 0);
}

struct Fixture {
  explicit Fixture(int index)
      : scope(L"CryptoFloat.Test." + std::to_wstring(GetCurrentProcessId()) +
              L"." + std::to_wstring(GetTickCount64()) + L"." +
              std::to_wstring(index)),
        go(Event(scope, L".Go")),
        release(Event(scope, L".Release")),
        ready(Event(scope, L".Ready")),
        activated(Event(scope, L".Activated")),
        attach(Event(scope, L".Attach")),
        keeper_release(Event(scope, L".KeeperRelease")),
        done(CreateSemaphoreW(nullptr, 0, 32, Name(scope, L".Done").c_str())),
        mapping(CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE,
                                   0, sizeof(Counts),
                                   Name(scope, L".Counts").c_str())) {
    if (mapping) {
      counts = static_cast<Counts*>(
          MapViewOfFile(mapping.get(), FILE_MAP_ALL_ACCESS, 0, 0, sizeof(Counts)));
    }
  }
  ~Fixture() {
    if (counts) UnmapViewOfFile(counts);
  }
  bool valid() const {
    return go && release && ready && activated && attach && keeper_release &&
           done && counts;
  }
  bool WaitDone(int total) const {
    const auto deadline = GetTickCount64() + kTimeout;
    for (int i = 0; i < total; ++i) {
      const auto now = GetTickCount64();
      if (now >= deadline ||
          WaitForSingleObject(done.get(), static_cast<DWORD>(deadline - now)) !=
              WAIT_OBJECT_0) {
        return false;
      }
    }
    return true;
  }
  std::wstring scope;
  Handle go, release, ready, activated, attach, keeper_release, done, mapping;
  Counts* counts = nullptr;
};

class Child {
 public:
  explicit Child(HANDLE process) : process_(process) {}
  ~Child() {
    // Only handles created by this harness reach here. A failed assertion must
    // never leave a hidden helper process running after the check has finished.
    if (WaitForSingleObject(process_.get(), 0) == WAIT_TIMEOUT) {
      TerminateProcess(process_.get(), kFailureExit);
      WaitForSingleObject(process_.get(), kTimeout);
    }
  }
  bool Join(DWORD expected) const {
    if (WaitForSingleObject(process_.get(), kTimeout) != WAIT_OBJECT_0) {
      return false;
    }
    DWORD result = 0;
    return GetExitCodeProcess(process_.get(), &result) && result == expected;
  }
  bool JoinPrimaryOrForwarded() const {
    if (WaitForSingleObject(process_.get(), kTimeout) != WAIT_OBJECT_0) {
      return false;
    }
    DWORD result = 0;
    return GetExitCodeProcess(process_.get(), &result) &&
           (result == 0 || result == kForwardedExit);
  }
  bool Crash() const { return TerminateProcess(process_.get(), 99) != FALSE; }

 private:
  Handle process_;
};

std::unique_ptr<Child> Launch(const Fixture& fixture, const wchar_t* mode) {
  std::vector<wchar_t> path(32768);
  const DWORD length =
      GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) return nullptr;
  const std::wstring command = L"\"" + std::wstring(path.data(), length) +
                               L"\" --child " + mode + L" " + fixture.scope;
  std::vector<wchar_t> writable(command.begin(), command.end());
  writable.push_back(0);
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(path.data(), writable.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    return nullptr;
  }
  CloseHandle(process.hThread);
  return std::make_unique<Child>(process.hProcess);
}

bool WaitEvent(HANDLE event) {
  return WaitForSingleObject(event, kTimeout) == WAIT_OBJECT_0;
}

#define CHECK(condition)                                                    \
  do {                                                                      \
    if (!(condition)) {                                                     \
      std::cerr << "FAIL line " << __LINE__ << ": " << #condition << '\n';  \
      return false;                                                         \
    }                                                                       \
  } while (false)

bool ConcurrentLaunches() {
  Fixture fixture(1);
  CHECK(fixture.valid());
  std::vector<std::unique_ptr<Child>> children;
  for (int i = 0; i < 8; ++i) {
    auto child = Launch(fixture, L"hold");
    CHECK(child);
    children.push_back(std::move(child));
  }
  CHECK(SetEvent(fixture.go.get()));
  CHECK(fixture.WaitDone(8));
  CHECK(ReadCount(&fixture.counts->primary) == 1);
  CHECK(ReadCount(&fixture.counts->forwarded) == 7);
  CHECK(ReadCount(&fixture.counts->errors) == 0);
  CHECK(WaitEvent(fixture.ready.get()));
  CHECK(WaitEvent(fixture.activated.get()));
  CHECK(SetEvent(fixture.release.get()));
  for (const auto& child : children) CHECK(child->JoinPrimaryOrForwarded());
  std::cout << "PASS concurrent starts: one primary, seven forwarded\n";
  return true;
}

bool EarlyActivation() {
  Fixture fixture(2);
  CHECK(fixture.valid());
  CHECK(SetEvent(fixture.go.get()));
  auto primary = Launch(fixture, L"late-window");
  CHECK(primary && fixture.WaitDone(1));
  CHECK(ReadCount(&fixture.counts->primary) == 1);
  auto second = Launch(fixture, L"notify");
  CHECK(second && fixture.WaitDone(1));
  CHECK(second->Join(kForwardedExit));
  CHECK(WaitForSingleObject(fixture.activated.get(), 0) == WAIT_TIMEOUT);
  CHECK(SetEvent(fixture.attach.get()));
  CHECK(WaitEvent(fixture.ready.get()));
  CHECK(WaitEvent(fixture.activated.get()));
  CHECK(SetEvent(fixture.release.get()));
  CHECK(primary->Join(0));
  std::cout << "PASS activation queued before a window exists\n";
  return true;
}

bool Takeover(bool crash) {
  Fixture fixture(crash ? 4 : 3);
  CHECK(fixture.valid());
  CHECK(SetEvent(fixture.go.get()));
  auto primary = Launch(fixture, L"hold");
  CHECK(primary && fixture.WaitDone(1) && WaitEvent(fixture.ready.get()));
  auto keeper = Launch(fixture, L"keep-forwarded");
  CHECK(keeper && fixture.WaitDone(1));
  CHECK(ReadCount(&fixture.counts->forwarded) == 1);
  // The forwarded helper retains its SingleInstance object/handles. This tests
  // an existing, now unowned/abandoned mutex rather than a newly created object.
  if (crash) {
    CHECK(primary->Crash());
    CHECK(primary->Join(99));
  } else {
    CHECK(SetEvent(fixture.release.get()));
    CHECK(primary->Join(0));
  }
  CHECK(ResetEvent(fixture.ready.get()));
  CHECK(ResetEvent(fixture.release.get()));
  auto replacement = Launch(fixture, L"hold");
  CHECK(replacement && fixture.WaitDone(1) && WaitEvent(fixture.ready.get()));
  CHECK(ReadCount(&fixture.counts->primary) == 2);
  CHECK(ReadCount(&fixture.counts->forwarded) == 1);
  CHECK(ReadCount(&fixture.counts->errors) == 0);
  CHECK(SetEvent(fixture.release.get()));
  CHECK(replacement->Join(0));
  CHECK(SetEvent(fixture.keeper_release.get()));
  CHECK(keeper->Join(kForwardedExit));
  std::cout << (crash ? "PASS abandoned mutex recovered after helper crash\n"
                     : "PASS mutex ownership reacquired after normal exit\n");
  return true;
}

LRESULT CALLBACK HiddenWindowProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (message == SingleInstance::ActivationMessage()) {
    // Verify production notification delivery without ever showing a window or
    // stealing focus. The application's real restore handler is not executed.
    const auto event =
        reinterpret_cast<HANDLE>(GetWindowLongPtrW(window, GWLP_USERDATA));
    SetEvent(event);
    return 0;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

DWORD PumpHiddenWindow(SingleInstance& instance, HANDLE release,
                       HANDLE ready, HANDLE activated) {
  WNDCLASSW window_class{};
  window_class.lpfnWndProc = HiddenWindowProc;
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.lpszClassName = L"CryptoFloat.SingleInstance.HiddenCheck";
  if (!RegisterClassW(&window_class)) return kFailureExit;
  HWND window = CreateWindowExW(
      WS_EX_TOOLWINDOW, window_class.lpszClassName, L"CryptoFloat native check",
      WS_POPUP, 0, 0, 1, 1, nullptr, nullptr, window_class.hInstance, activated);
  if (!window) return kFailureExit;
  if (!instance.AttachWindow(window)) {
    DestroyWindow(window);
    return kFailureExit;
  }
  SetEvent(ready);
  const auto deadline = GetTickCount64() + 20000;
  DWORD result = kFailureExit;
  for (;;) {
    const auto now = GetTickCount64();
    if (now >= deadline) break;
    const DWORD wait = MsgWaitForMultipleObjectsEx(
        1, &release, static_cast<DWORD>(deadline - now), QS_ALLINPUT,
        MWMO_INPUTAVAILABLE);
    if (wait == WAIT_OBJECT_0) {
      result = IsWindowVisible(window) ? kFailureExit : 0;
      break;
    }
    if (wait != WAIT_OBJECT_0 + 1) break;
    MSG message{};
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&message);
      DispatchMessageW(&message);
    }
  }
  instance.DetachWindow();
  DestroyWindow(window);
  UnregisterClassW(window_class.lpszClassName, window_class.hInstance);
  return result;
}

DWORD ChildMain(const std::wstring& mode, const std::wstring& scope) {
  // Never allow this helper to touch the application protocol namespace.
  if (scope.rfind(L"CryptoFloat.Test.", 0) != 0) return kFailureExit;
  const Handle go(OpenEventW(SYNCHRONIZE, FALSE, Name(scope, L".Go").c_str()));
  const Handle release(
      OpenEventW(SYNCHRONIZE, FALSE, Name(scope, L".Release").c_str()));
  const Handle attach(
      OpenEventW(SYNCHRONIZE, FALSE, Name(scope, L".Attach").c_str()));
  const Handle keeper_release(
      OpenEventW(SYNCHRONIZE, FALSE, Name(scope, L".KeeperRelease").c_str()));
  const Handle ready(
      OpenEventW(EVENT_MODIFY_STATE, FALSE, Name(scope, L".Ready").c_str()));
  const Handle activated(
      OpenEventW(EVENT_MODIFY_STATE, FALSE, Name(scope, L".Activated").c_str()));
  const Handle done(OpenSemaphoreW(SEMAPHORE_MODIFY_STATE, FALSE,
                                   Name(scope, L".Done").c_str()));
  const Handle mapping(OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE,
                                       Name(scope, L".Counts").c_str()));
  if (!go || !release || !attach || !keeper_release || !ready || !activated ||
      !done || !mapping) {
    return kFailureExit;
  }
  auto counts = static_cast<Counts*>(
      MapViewOfFile(mapping.get(), FILE_MAP_ALL_ACCESS, 0, 0, sizeof(Counts)));
  if (!counts || !WaitEvent(go.get())) {
    if (counts) UnmapViewOfFile(counts);
    return kFailureExit;
  }
  SingleInstance instance(scope);
  const auto result = instance.Start();
  if (result == SingleInstance::StartResult::kPrimary) {
    InterlockedIncrement(&counts->primary);
  } else if (result == SingleInstance::StartResult::kForwarded) {
    InterlockedIncrement(&counts->forwarded);
  } else {
    InterlockedIncrement(&counts->errors);
  }
  ReleaseSemaphore(done.get(), 1, nullptr);
  UnmapViewOfFile(counts);
  if (result == SingleInstance::StartResult::kError) return kFailureExit;
  if (result == SingleInstance::StartResult::kForwarded) {
    if (mode == L"keep-forwarded" &&
        WaitForSingleObject(keeper_release.get(), 20000) != WAIT_OBJECT_0) {
      return kFailureExit;
    }
    return kForwardedExit;
  }
  if (mode == L"notify" || mode == L"keep-forwarded") return kFailureExit;
  if (mode == L"late-window" && !WaitEvent(attach.get())) return kFailureExit;
  return PumpHiddenWindow(instance, release.get(), ready.get(), activated.get());
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc == 4 && std::wstring(argv[1]) == L"--child") {
    return static_cast<int>(ChildMain(argv[2], argv[3]));
  }
  if (argc != 1) return static_cast<int>(kFailureExit);
  if (!ConcurrentLaunches() || !EarlyActivation() || !Takeover(false) ||
      !Takeover(true)) {
    return 1;
  }
  std::cout << "All 4 native single-instance checks passed.\n";
  return 0;
}
