// Exercise the production UIA bounds policy using synthetic provider properties.
// This fixture never queries desktop windows or creates an automation client.
#include "taskbar_layout.h"
#include <cwchar>
namespace alignment_fixture {
LSTATUS registry_status = ERROR_SUCCESS;
DWORD registry_value = 1;
bool windows11 = true, version_known = true, valid_query = true;
int version_calls = 0;
LSTATUS WINAPI ReadRegistry(HKEY key, LPCWSTR subkey, LPCWSTR value_name, DWORD flags,
                           LPDWORD type, PVOID data, LPDWORD bytes) {
  valid_query &= key == HKEY_CURRENT_USER && subkey && value_name &&
      std::wcscmp(subkey, L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced") == 0 &&
      std::wcscmp(value_name, L"TaskbarAl") == 0 && flags == RRF_RT_REG_DWORD &&
      data && bytes && *bytes == sizeof(DWORD);
  if (registry_status == ERROR_SUCCESS && data && bytes && *bytes >= sizeof(DWORD)) {
    *static_cast<DWORD*>(data) = registry_value; *bytes = sizeof(DWORD);
    if (type) *type = REG_DWORD;
  }
  return registry_status;
}
BOOL WINAPI CheckVersion(LPOSVERSIONINFOEXW version, DWORD mask, DWORDLONG condition) {
  ++version_calls;
  valid_query &= version && version->dwBuildNumber == 22000 && mask == VER_BUILDNUMBER &&
      condition == VerSetConditionMask(0, VER_BUILDNUMBER, VER_GREATER_EQUAL);
  if (!version_known) { SetLastError(ERROR_INVALID_PARAMETER); return FALSE; }
  if (!windows11) { SetLastError(ERROR_OLD_WIN_VERSION); return FALSE; }
  return TRUE;
}
}
#define RegGetValueW alignment_fixture::ReadRegistry
#define VerifyVersionInfoW alignment_fixture::CheckVersion
#include "../windows/runner/taskbar_layout.cpp"
#undef VerifyVersionInfoW
#undef RegGetValueW
#include <cstdio>

int main() {
  int failures = 0;
  auto check = [&failures](bool result, const char* label) {
    std::printf("%s %s\n", result ? "PASS" : "FAIL", label);
    if (!result) ++failures;
  };
  using taskbar::TaskbarAlignment;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::centered,
        "read-only explicit centered setting selects far-left placement");
  alignment_fixture::registry_value = 0;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::left && alignment_fixture::version_calls == 0,
        "explicit left setting retains legacy placement without guessing from OS");
  alignment_fixture::registry_value = 2;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::unknown,
        "unknown alignment value is not treated as centered or left");
  alignment_fixture::registry_status = ERROR_FILE_NOT_FOUND;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::centered,
        "missing setting uses documented centered Windows 11 default");
  alignment_fixture::windows11 = false;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::left,
        "missing setting on pre-Windows-11 keeps legacy placement");
  alignment_fixture::version_known = false;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::unknown,
        "unknown OS with missing setting fails closed");
  alignment_fixture::registry_status = ERROR_ACCESS_DENIED;
  const auto denied = taskbar::ReadTaskbarAlignment();
  check(denied.value == TaskbarAlignment::unknown && denied.error == ERROR_ACCESS_DENIED,
        "denied alignment read fails closed and preserves diagnostic error");
  alignment_fixture::registry_status = ERROR_UNSUPPORTED_TYPE;
  check(taskbar::ReadTaskbarAlignment().value == TaskbarAlignment::unknown,
        "wrong registry value type fails closed");
  check(alignment_fixture::valid_query && alignment_fixture::version_calls == 3,
        "alignment adapter uses bounded read-only DWORD query and explicit Win11 build condition");
  taskbar::AutomationWalk walk;
  walk.bounds = {0, 0, 1200, 48};
  bool complete = walk.RecordBounds(FALSE, TRUE, {0, 0, 400, 48}, UIA_ButtonControlTypeId, true, 1);
  complete &= walk.RecordBounds(FALSE, TRUE, {1000, 0, 1200, 48}, UIA_ButtonControlTypeId, false, 1);
  complete &= walk.RecordBounds(FALSE, FALSE, {0, 0, 0, 0}, UIA_CustomControlTypeId, false, 2);
  complete &= walk.RecordBounds(FALSE, TRUE, {0, 0, 0, 0}, UIA_ButtonControlTypeId, false, 2);
  taskbar::LayoutSnapshot layout{walk.bounds, walk.occupied, complete, true, 96};
  check(complete && taskbar::FitFreeRegion(layout, 360, 34).status == taskbar::Status::displaying,
        "empty raw UIA placeholder preserves valid free taskbar region");
  check(walk.controls == 2 && walk.occupied.size() == 2,
        "empty UIA placeholder provides no occupied or completeness evidence");
  check(!walk.RecordBounds(FALSE, TRUE, {100, 0, 50, 48}, UIA_ButtonControlTypeId, false, 1),
        "inverted occupied bounds still invalidate discovery");
  check(!walk.RecordBounds(FALSE, TRUE, {0, 0, 100001, 48}, UIA_ButtonControlTypeId, false, 1),
        "out of range occupied bounds still invalidate discovery");
  check(walk.RecordBounds(FALSE, FALSE, {400, 0, 1000, 48}, UIA_CustomControlTypeId, false, 1),
        "unknown visible raw leaf remains occupied");
  layout.occupied = walk.occupied; layout.complete = true;
  check(taskbar::FitFreeRegion(layout, 360, 34).status == taskbar::Status::noSpace,
        "unknown occupied fragment cannot become an alleged free gap");
  HWND own_popup = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", nullptr, WS_POPUP,
      400, 0, 600, 48, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  std::vector<RECT> occupied;
  taskbar::NativeWalk native{nullptr, {0, 0, 1200, 48}, &occupied};
  taskbar::CollectNative(own_popup, reinterpret_cast<LPARAM>(&native));
  check(own_popup && native.ignored_own == 1 && occupied.empty(),
        "self-process popup is excluded before visibility or occupancy queries");
  if (own_popup) DestroyWindow(own_popup);
  return failures == 0 ? 0 : 1;
}
