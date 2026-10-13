#include "single_instance.h"

#include <sddl.h>

#include <utility>
#include <vector>

namespace {

class ScopedHandle {
 public:
  explicit ScopedHandle(HANDLE value) : value_(value) {}
  ~ScopedHandle() {
    if (value_) CloseHandle(value_);
  }
  ScopedHandle(const ScopedHandle&) = delete;
  ScopedHandle& operator=(const ScopedHandle&) = delete;
  HANDLE get() const { return value_; }

 private:
  HANDLE value_;
};

std::wstring CurrentUserSid() {
  HANDLE raw_token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &raw_token)) return {};
  const ScopedHandle token(raw_token);
  DWORD bytes = 0;
  GetTokenInformation(token.get(), TokenUser, nullptr, 0, &bytes);
  if (bytes == 0 || GetLastError() != ERROR_INSUFFICIENT_BUFFER) return {};
  std::vector<BYTE> buffer(bytes);
  if (!GetTokenInformation(token.get(), TokenUser, buffer.data(), bytes, &bytes)) {
    return {};
  }
  const auto user = reinterpret_cast<const TOKEN_USER*>(buffer.data());
  LPWSTR raw_sid = nullptr;
  if (!ConvertSidToStringSidW(user->User.Sid, &raw_sid)) return {};
  const std::wstring sid(raw_sid);
  LocalFree(raw_sid);
  return sid;
}

struct WindowSearch {
  const std::wstring& property;
  HWND result = nullptr;
};

BOOL CALLBACK FindInstanceWindow(HWND window, LPARAM parameter) {
  auto& search = *reinterpret_cast<WindowSearch*>(parameter);
  if (GetPropW(window, search.property.c_str())) {
    search.result = window;
    return FALSE;
  }
  return TRUE;
}

}  // namespace

SingleInstance::SingleInstance(std::wstring protocol_namespace)
    : protocol_namespace_(std::move(protocol_namespace)) {}

SingleInstance::~SingleInstance() {
  DetachWindow();
  // The owning main thread keeps this mutex until the window and engine are gone.
  if (owns_mutex_) ReleaseMutex(mutex_);
  if (activation_event_) CloseHandle(activation_event_);
  if (mutex_) CloseHandle(mutex_);
}

UINT SingleInstance::ActivationMessage() {
  static const UINT message =
      RegisterWindowMessageW(L"CryptoFloat.SingleInstance.Activate.v1");
  return message;
}

SingleInstance::StartResult SingleInstance::Start() {
  if (mutex_ || ActivationMessage() == 0) return StartResult::kError;
  // Leave room for even the longest textual SID within Windows object names.
  // Disallow namespace separators so an override cannot escape the Local scope.
  if (protocol_namespace_.empty() || protocol_namespace_.size() > 48 ||
      protocol_namespace_.find_first_not_of(
          L"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_") !=
          std::wstring::npos) {
    return StartResult::kError;
  }
  const std::wstring sid = CurrentUserSid();
  if (sid.empty()) return StartResult::kError;

  // Local confines the gate to this login session; the SID separates run-as
  // users. Keep this protocol name stable across portable locations and versions.
  const std::wstring scope = L"Local\\" + protocol_namespace_ + L"." + sid;
  window_property_ = protocol_namespace_ + L".Window." + sid;
  mutex_ = CreateMutexW(nullptr, FALSE, (scope + L".Mutex").c_str());
  if (!mutex_) return StartResult::kError;
  activation_event_ =
      CreateEventW(nullptr, FALSE, FALSE, (scope + L".Activate").c_str());
  if (!activation_event_) return StartResult::kError;

  const DWORD acquired = WaitForSingleObject(mutex_, 0);
  if (acquired == WAIT_OBJECT_0 || acquired == WAIT_ABANDONED) {
    owns_mutex_ = true;
    return StartResult::kPrimary;
  }
  if (acquired != WAIT_TIMEOUT) return StartResult::kError;

  WindowSearch search{window_property_};
  EnumWindows(FindInstanceWindow, reinterpret_cast<LPARAM>(&search));
  if (search.result) {
    DWORD process_id = 0;
    GetWindowThreadProcessId(search.result, &process_id);
    // The second launch normally originates from the foreground shell. Transfer
    // its activation permission before the running process handles the request.
    if (process_id != 0) AllowSetForegroundWindow(process_id);
  }

  // Recover a primary that exited during discovery. A held/abandoned mutex is
  // decided by ownership, not ERROR_ALREADY_EXISTS (waiters keep handles alive).
  const DWORD retry = WaitForSingleObject(mutex_, 0);
  if (retry == WAIT_OBJECT_0 || retry == WAIT_ABANDONED) {
    owns_mutex_ = true;
    return StartResult::kPrimary;
  }
  if (retry != WAIT_TIMEOUT) return StartResult::kError;

  // An auto-reset event retains an early request until the primary attaches its
  // window. No window polling, second Flutter engine, or blocking UI wait is used.
  // Several launch requests may coalesce into one activation, which is enough.
  return SetEvent(activation_event_) ? StartResult::kForwarded
                                     : StartResult::kError;
}

bool SingleInstance::AttachWindow(HWND window) {
  if (!owns_mutex_ || activation_wait_ || !IsWindow(window)) return false;
  if (!SetPropW(window, window_property_.c_str(), reinterpret_cast<HANDLE>(1))) {
    return false;
  }
  window_ = window;
  if (!RegisterWaitForSingleObject(&activation_wait_, activation_event_,
                                   OnActivation, this, INFINITE,
                                   WT_EXECUTEDEFAULT)) {
    RemovePropW(window_, window_property_.c_str());
    window_ = nullptr;
    activation_wait_ = nullptr;
    return false;
  }
  return true;
}

void SingleInstance::DetachWindow() {
  if (activation_wait_) {
    // The callback only posts a message, never waits on the window thread. Drain
    // it before destroying the HWND or closing its event to avoid lifetime races.
    UnregisterWaitEx(activation_wait_, INVALID_HANDLE_VALUE);
    activation_wait_ = nullptr;
  }
  if (window_) {
    RemovePropW(window_, window_property_.c_str());
    window_ = nullptr;
  }
}

void CALLBACK SingleInstance::OnActivation(void* context, BOOLEAN timed_out) {
  if (timed_out) return;
  const auto instance = static_cast<SingleInstance*>(context);
  PostMessageW(instance->window_, ActivationMessage(), 0, 0);
}
