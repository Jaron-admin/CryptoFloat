// Isolated native regression tests: all windows stay hidden. Popup tracking,
// mouse hooks and monitor geometry are replaced at the OS boundary so these
// tests never capture input, open a menu, or interact with the user's desktop.
#include <windows.h>
#include <flutter_windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>
#include <commctrl.h>
#include <shellapi.h>
#include <algorithm>
#include <cmath>
#include <functional>
#include <iostream>
#include <memory>
#include <string>
#include <type_traits>
#include <vector>

namespace fixture {
UINT dpi = 96;
UINT monitor_dpi_override = 0;
RECT work{0, 0, 1600, 1000};
HOOKPROC mouse_hook = nullptr;
int hooks_started = 0;
int hooks_stopped = 0;
HWND mouse_target = nullptr;
HWND host = nullptr;
std::vector<std::wstring> menu_labels;
bool system_menu_items = true;
bool checked_topmost = false;
UINT menu_selection = 0;
int failures = 0;
int checks = 0;
int layered_attribute_calls = 0;
std::wstring notification_text;
bool accept_notifications = true;

void Expect(bool condition, const char* message) {
  ++checks;
  if (!condition) {
    ++failures;
    std::cerr << "FAIL: " << message << '\n';
  }
}
BOOL LayeredAttributes(HWND window, COLORREF key, BYTE alpha, DWORD flags) {
  ++layered_attribute_calls;
  return SetLayeredWindowAttributes(window, key, alpha, flags);
}
UINT MonitorDpi(HMONITOR) { return monitor_dpi_override ? monitor_dpi_override : dpi; }
UINT WindowDpi(HWND) { return dpi; }
BOOL MonitorInfo(HMONITOR, LPMONITORINFO info) {
  info->rcWork = work;
  info->rcMonitor = work;
  info->dwFlags = MONITORINFOF_PRIMARY;
  if (info->cbSize == sizeof(MONITORINFOEXW)) {
    wcscpy_s(reinterpret_cast<MONITORINFOEXW*>(info)->szDevice, L"TEST_DISPLAY");
  }
  return TRUE;
}
BOOL Foreground(HWND) { return TRUE; }
HHOOK InstallHook(int type, HOOKPROC callback, HINSTANCE, DWORD) {
  Expect(type == WH_MOUSE_LL, "settings installs only a mouse hook");
  mouse_hook = callback;
  ++hooks_started;
  return reinterpret_cast<HHOOK>(1);
}
BOOL RemoveHook(HHOOK) {
  mouse_hook = nullptr;
  ++hooks_stopped;
  return TRUE;
}
LRESULT NextHook(HHOOK, int, WPARAM, LPARAM) { return 0; }
HWND MouseTarget(POINT) { return mouse_target; }
DWORD ProcessId(HWND window, LPDWORD process) {
  if (window == reinterpret_cast<HWND>(1)) {
    *process = GetCurrentProcessId() + 1;
    return 0;
  }
  return GetWindowThreadProcessId(window, process);
}
BOOL Visible(HWND window) {
  return window == host ? TRUE : IsWindowVisible(window);
}
HRESULT TrayIcon(HINSTANCE, PCWSTR, int, HICON* icon) {
  *icon = CopyIcon(LoadIconW(nullptr, IDI_APPLICATION));
  return *icon ? S_OK : E_FAIL;
}
BOOL NotifyIcon(DWORD operation, PNOTIFYICONDATAW data) {
  if (operation == NIM_MODIFY && (data->uFlags & NIF_INFO) != 0) {
    notification_text = data->szInfo;
    Expect((data->dwInfoFlags & NIIF_INFO) != 0, "saved notice uses information icon");
    return accept_notifications ? TRUE : FALSE;
  }
  return TRUE;
}
BOOL TrackMenu(HMENU menu, UINT flags, int, int, HWND, LPTPMPARAMS) {
  Expect((flags & TPM_RETURNCMD) != 0, "menu returns command to caller");
  menu_labels.clear();
  system_menu_items = true;
  checked_topmost = false;
  for (int index = 0; index < GetMenuItemCount(menu); ++index) {
    wchar_t text[128]{};
    MENUITEMINFOW info{};
    info.cbSize = sizeof(info);
    info.fMask = MIIM_FTYPE | MIIM_STRING | MIIM_STATE;
    info.dwTypeData = text;
    info.cch = 127;
    GetMenuItemInfoW(menu, static_cast<UINT>(index), TRUE, &info);
    system_menu_items = system_menu_items && (info.fType & MFT_OWNERDRAW) == 0;
    if ((info.fType & MFT_SEPARATOR) == 0) menu_labels.emplace_back(text);
    if (index == 3) checked_topmost = (info.fState & MFS_CHECKED) != 0;
  }
  return static_cast<BOOL>(menu_selection);
}
}  // namespace fixture

#define FlutterDesktopGetDpiForMonitor fixture::MonitorDpi
#define GetDpiForWindow fixture::WindowDpi
#define GetMonitorInfoW fixture::MonitorInfo
#define SetForegroundWindow fixture::Foreground
#define SetWindowsHookExW fixture::InstallHook
#define UnhookWindowsHookEx fixture::RemoveHook
#define CallNextHookEx fixture::NextHook
#define WindowFromPoint fixture::MouseTarget
#define GetWindowThreadProcessId fixture::ProcessId
#define IsWindowVisible fixture::Visible
#define TrackPopupMenuEx fixture::TrackMenu
#define LoadIconMetric fixture::TrayIcon
#define Shell_NotifyIconW fixture::NotifyIcon
#define SetLayeredWindowAttributes fixture::LayeredAttributes
#include "../win32_window.cpp"
#include "../context_menu.cpp"
#include "../notification_tray.cpp"
#undef FlutterDesktopGetDpiForMonitor
#undef GetDpiForWindow
#undef GetMonitorInfoW
#undef SetForegroundWindow
#undef SetWindowsHookExW
#undef UnhookWindowsHookEx
#undef CallNextHookEx
#undef WindowFromPoint
#undef GetWindowThreadProcessId
#undef IsWindowVisible
#undef TrackPopupMenuEx
#undef LoadIconMetric
#undef Shell_NotifyIconW
#undef SetLayeredWindowAttributes

class HiddenWindow : public Win32Window {
 public:
  using Win32Window::MessageHandler;
};

class CompositionFixtureWindow : public HiddenWindow {
 public:
  LONG_PTR creation_style = 0;
 protected:
  LRESULT MessageHandler(HWND window, UINT message, WPARAM wparam,
                         LPARAM lparam) noexcept override {
    if (message == WM_CREATE) creation_style = GetWindowLongPtrW(window, GWL_EXSTYLE);
    return HiddenWindow::MessageHandler(window, message, wparam, lparam);
  }
};

template <typename T, typename = void>
struct HasProbeCreate : std::false_type {};
template <typename T>
struct HasProbeCreate<T, std::void_t<decltype(std::declval<T>().Create(
    std::wstring{}, Win32Window::Point{0, 0}, Win32Window::Size{320, 180},
    DpiDiagnostics::Options{}))>> : std::true_type {};

template <typename Window = CompositionFixtureWindow,
          typename Options = DpiDiagnostics::Options>
void ProbeCompositionLifetimeTest() {
  if constexpr (!HasProbeCreate<Window>::value) {
    fixture::Expect(false, "hidden native host accepts isolated diagnostic composition");
  } else {
    using Mode = decltype(Options{}.composition);
    fixture::dpi = 96;
    fixture::work = RECT{0, 0, 1600, 1000};
    const Options layered = DpiDiagnostics::ParseArguments(
        {"--dpi-diagnostics", "--dpi-probe-isolated", "--dpi-probe-opaque-layered"});
    const Options nonlayered = DpiDiagnostics::ParseArguments(
        {"--dpi-diagnostics", "--dpi-probe-isolated", "--dpi-probe-opaque-nonlayered"});
    Options missing_diagnostics = nonlayered;
    missing_diagnostics.enabled = false;
    Options missing_isolation = layered;
    missing_isolation.isolated = false;
    for (const auto& options : std::vector<Options>{Options{}, layered,
             nonlayered, missing_diagnostics, missing_isolation}) {
      const bool opaque = options.enabled && options.isolated &&
          options.composition != Mode::kDefault;
      const bool use_layered = !(opaque && options.composition == Mode::kOpaqueNonLayered);
      Window window;
      const int calls_before = fixture::layered_attribute_calls;
      fixture::Expect(window.Create(L"Hidden composition probe", {100, 100},
          {320, 180}, options), "diagnostic composition fixture created hidden");
      fixture::Expect(((window.creation_style & WS_EX_LAYERED) != 0) == use_layered,
          "probe composition applies when HWND is created");
      auto check_policy = [&](BYTE expected_alpha) {
        fixture::Expect(((GetWindowLongPtrW(window.GetHandle(), GWL_EXSTYLE) &
            WS_EX_LAYERED) != 0) == use_layered,
            "composition remains unchanged throughout the HWND lifetime");
        if (use_layered) {
          BYTE alpha = 0; DWORD flags = 0;
          fixture::Expect(GetLayeredWindowAttributes(window.GetHandle(), nullptr,
              &alpha, &flags) != FALSE && flags == LWA_ALPHA &&
              alpha == expected_alpha, "effective alpha obeys normal or forced opaque policy");
        } else {
          fixture::Expect(fixture::layered_attribute_calls == calls_before,
              "nonlayered probe never calls SetLayeredWindowAttributes");
        }
        fixture::Expect(!IsWindowVisible(window.GetHandle()), "probe fixture remains hidden");
      };
      check_policy(opaque ? 255 : 245);
      fixture::Expect(window.SetOpacity(0.4), "opacity request succeeds under each probe policy");
      check_policy(opaque ? 255 : 102);
      window.SetSettingsMode(true);
      check_policy(255);
      window.SetOpacity(0.6);
      check_policy(255);
      window.SetSettingsMode(false);
      check_policy(opaque ? 255 : 153);
      for (const UINT dpi : {168U, 96U}) {
        fixture::dpi = dpi;
        RECT suggested{100, 100, 660, 415};
        SendMessageW(window.GetHandle(), WM_DPICHANGED, MAKELONG(dpi, dpi),
            reinterpret_cast<LPARAM>(&suggested));
        const RECT bounds = window.GetWindowBounds().rect;
        fixture::Expect(bounds.right - bounds.left == (dpi == 168 ? 560 : 320) &&
            bounds.bottom - bounds.top == (dpi == 168 ? 315 : 180),
            "all composition policies preserve the same 320x180 DIP geometry");
        check_policy(opaque ? 255 : 153);
      }
      window.Destroy();
      fixture::Expect(window.Create(L"Hidden ordinary recreation", {100, 100}, {320, 180}),
          "recreating without probe options restores ordinary startup");
      BYTE alpha = 0; DWORD flags = 0;
      fixture::Expect((GetWindowLongPtrW(window.GetHandle(), GWL_EXSTYLE) & WS_EX_LAYERED) != 0 &&
          GetLayeredWindowAttributes(window.GetHandle(), nullptr, &alpha, &flags) != FALSE &&
          alpha == 245, "probe policy does not leak to a recreated ordinary HWND");
      fixture::Expect(!IsWindowVisible(window.GetHandle()), "recreated fixture remains hidden");
    }
  }
}

void Pump(HWND window) {
  MSG message{};
  while (PeekMessageW(&message, window, 0, 0, PM_REMOVE)) {
    DispatchMessageW(&message);
  }
}

void DpiChange(HiddenWindow& window, UINT dpi, RECT suggestion) {
  fixture::dpi = dpi;
  window.MessageHandler(window.GetHandle(), WM_DPICHANGED,
      MAKELONG(dpi, dpi), reinterpret_cast<LPARAM>(&suggestion));
}

void DpiGeometryTest() {
  fixture::dpi = 96;
  fixture::work = RECT{0, 0, 1600, 1000};
  HiddenWindow window;
  fixture::Expect(window.Create(L"Hidden geometry regression",
      Win32Window::Point(100, 100), Win32Window::Size(601, 301)),
      "hidden host created");
  // A 601 x 301 DIP panel cannot fit on this simulated 150% display.
  fixture::work = RECT{0, 0, 800, 600};
  DpiChange(window, 144, RECT{100, 100, 1002, 552});
  RECT bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 800,
      "high DPI display clamps oversized physical window");
  // Windows derives its next suggestion from the now-clamped 800px width.
  fixture::work = RECT{0, 0, 1600, 1000};
  DpiChange(window, 96, RECT{100, 100, 633, 401});
  bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 601,
      "return to 100% restores original logical width after work-area clamp");
  fixture::Expect(bounds.bottom - bounds.top == 301,
      "return to 100% restores original logical height");
  for (int count = 0; count < 20; ++count) {
    DpiChange(window, 144, RECT{100, 100, 1002, 552});
    DpiChange(window, 96, RECT{100, 100, 702, 402});
  }
  bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 601 &&
      bounds.bottom - bounds.top == 301,
      "repeated DPI transitions do not accumulate integer rounding");
  SIZE candidate{601, 301};
  const auto handled = window.MessageHandler(window.GetHandle(),
      WM_GETDPISCALEDSIZE, 144, reinterpret_cast<LPARAM>(&candidate));
  fixture::Expect(handled == TRUE && candidate.cx == 902 && candidate.cy == 452,
      "Windows receives the desired size before choosing cross-screen position");
  window.SetSettingsMode(true);
  fixture::work = RECT{0, 0, 800, 600};
  DpiChange(window, 144, RECT{100, 100, 1480, 1180});
  window.SetSettingsMode(false);
  fixture::work = RECT{0, 0, 1600, 1000};
  DpiChange(window, 96, RECT{100, 100, 633, 401});
  bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 601 &&
      bounds.bottom - bounds.top == 301,
      "closing settings after a DPI change preserves panel logical geometry");
  fixture::work = RECT{0, 0, 3000, 2000};
  DpiChange(window, 144, RECT{100, 100, 1002, 552});
  window.SetSettingsMode(true);
  DpiChange(window, 192, RECT{100, 100, 1940, 1540});
  window.SetSettingsMode(false);
  bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 1202 &&
      bounds.bottom - bounds.top == 602,
      "settings restoration keeps fractional DIP precision across three scales");
}

void NativeMenuTest() {
  HiddenWindow window;
  fixture::dpi = 96;
  fixture::work = RECT{0, 0, 1600, 1000};
  window.Create(L"Hidden menu regression", Win32Window::Point(100, 100),
      Win32Window::Size(601, 301));
  auto menu = std::make_shared<ContextMenu>(window.GetHandle());
  ContextMenuStyle style;
  style.hide_label = L"隐藏到托盘";
  style.refresh_label = L"立即刷新";
  style.topmost_label = L"窗口置顶";
  style.settings_label = L"设置";
  style.exit_label = L"退出";
  menu->ShowPanel(POINT{150, 150}, true, style, nullptr);
  LRESULT result = 0;
  menu->HandleMessage(WM_APP + 0x36, 0, 0, &result);
  fixture::Expect(fixture::system_menu_items,
      "Windows renders every menu item without owner drawing");
  fixture::Expect(fixture::menu_labels.size() == 5 &&
      fixture::menu_labels[0] == L"隐藏到托盘" &&
      fixture::menu_labels[3] == L"设置",
      "localized labels are native accessible menu strings");
  fixture::Expect(fixture::checked_topmost,
      "always-on-top uses Windows checked item state");
  std::string action;
  fixture::menu_selection = 3;
  menu->ShowTray(POINT{150, 150}, [&](const std::string& value) { action = value; });
  menu->HandleMessage(WM_APP + 0x36, 0, 0, &result);
  fixture::Expect(action == "settings", "native tray command dispatches settings");
}

void NativeResizeAndDisplayChangeTest() {
  fixture::dpi = 96;
  fixture::work = RECT{0, 0, 3000, 2000};
  HiddenWindow window;
  window.Create(L"Hidden edge resize regression", Win32Window::Point(100, 100),
      Win32Window::Size(601, 301));
  RECT bounds = window.GetWindowBounds().rect;
  fixture::Expect(window.MessageHandler(window.GetHandle(), WM_NCHITTEST, 0,
      MAKELPARAM(bounds.right - 1, bounds.bottom - 1)) == HTBOTTOMRIGHT,
      "native bottom-right resize remains available without Flutter arrow");
  fixture::Expect(window.MessageHandler(window.GetHandle(), WM_NCHITTEST, 0,
      MAKELPARAM(bounds.left + 40, bounds.top + 40)) == HTCLIENT,
      "panel interior does not become a native resize handle");
  RECT resized{100, 100, 877, 433};
  window.MessageHandler(window.GetHandle(), WM_SIZING, WMSZ_BOTTOMRIGHT,
      reinterpret_cast<LPARAM>(&resized));
  DpiChange(window, 144, RECT{100, 100, 1266, 600});
  bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 1166 &&
      bounds.bottom - bounds.top == 500,
      "manual edge resizing becomes the next DPI scaling baseline");
  // Display topology changes can move a window without a prior DPI message.
  fixture::dpi = 96;
  window.ClampToVisibleWorkArea();
  bounds = window.GetWindowBounds().rect;
  fixture::Expect(bounds.right - bounds.left == 777 &&
      bounds.bottom - bounds.top == 333,
      "display-layout recovery uses the destination monitor DPI once");
}

template <typename T, typename = void>
struct HasOutsideClickCallback : std::false_type {};
template <typename T>
struct HasOutsideClickCallback<T, std::void_t<decltype(
    std::declval<T>().SetSettingsOutsideClickCallback(std::function<void()>{}))>>
    : std::true_type {};

template <typename Window = HiddenWindow>
void OutsideClickTest() {
  if constexpr (!HasOutsideClickCallback<Window>::value) {
    fixture::Expect(false, "settings exposes outside click notifications");
  } else {
  Window window;
  fixture::dpi = 96;
  fixture::work = RECT{0, 0, 1600, 1000};
  window.Create(L"Hidden outside click regression", Win32Window::Point(100, 100),
      Win32Window::Size(601, 301));
  fixture::host = window.GetHandle();
  int clicks = 0;
  window.SetSettingsOutsideClickCallback([&]() { ++clicks; });
  fixture::Expect(fixture::mouse_hook == nullptr, "panel does not monitor mouse input");
  window.SetSettingsMode(true);
  fixture::Expect(fixture::mouse_hook != nullptr, "settings starts mouse observation");
  MSLLHOOKSTRUCT input{};
  input.pt = POINT{1500, 900};
  fixture::mouse_target = reinterpret_cast<HWND>(1);
  fixture::mouse_hook(HC_ACTION, WM_MOUSEMOVE, reinterpret_cast<LPARAM>(&input));
  window.MessageHandler(window.GetHandle(), WM_ACTIVATE, WA_INACTIVE, 0);
  Pump(window.GetHandle());
  fixture::Expect(clicks == 0, "hover and focus loss do not dismiss settings");
  fixture::mouse_target = window.GetHandle();
  fixture::mouse_hook(HC_ACTION, WM_LBUTTONDOWN, reinterpret_cast<LPARAM>(&input));
  Pump(window.GetHandle());
  fixture::Expect(clicks == 0, "own-process windows do not dismiss settings");
  fixture::mouse_target = reinterpret_cast<HWND>(1);
  EnableWindow(window.GetHandle(), FALSE);
  fixture::mouse_hook(HC_ACTION, WM_LBUTTONDOWN, reinterpret_cast<LPARAM>(&input));
  Pump(window.GetHandle());
  fixture::Expect(clicks == 0, "disabled owner waits for its native modal dialog");
  EnableWindow(window.GetHandle(), TRUE);
  fixture::mouse_hook(HC_ACTION, WM_LBUTTONDOWN, reinterpret_cast<LPARAM>(&input));
  Pump(window.GetHandle());
  fixture::Expect(clicks == 1, "outside mouse press notifies settings once");
  fixture::mouse_hook(HC_ACTION, WM_RBUTTONDOWN, reinterpret_cast<LPARAM>(&input));
  window.SetSettingsMode(false);
  window.SetSettingsMode(true);
  Pump(window.GetHandle());
  fixture::Expect(clicks == 1, "old queued click cannot close a reopened settings session");
  window.SetSettingsMode(false);
  fixture::Expect(fixture::mouse_hook == nullptr,
      "settings exit releases mouse hook immediately");
  window.SetSettingsMode(true);
  window.Destroy();
  fixture::Expect(fixture::mouse_hook == nullptr,
      "destruction releases settings mouse hook");
  fixture::host = nullptr;
  }
}

template <typename T, typename = void>
struct HasSavedNotification : std::false_type {};
template <typename T>
struct HasSavedNotification<T, std::void_t<decltype(
    std::declval<T>().NotifySettingsSaved(true))>> : std::true_type {};

template <typename Tray = NotificationTray>
void SavedNotificationTest() {
  if constexpr (!HasSavedNotification<Tray>::value) {
    fixture::Expect(false, "hidden panel has a settings-saved notification");
  } else {
    HiddenWindow window;
    window.Create(L"Hidden saved notification regression", Win32Window::Point(100, 100),
        Win32Window::Size(601, 301));
    Tray tray(window.GetHandle(), nullptr, nullptr);
    fixture::Expect(tray.NotifySettingsSaved(true), "Chinese saved notice accepted");
    fixture::Expect(fixture::notification_text == L"设置已自动保存。", "Chinese saved text");
    fixture::Expect(tray.NotifySettingsSaved(false), "English saved notice accepted");
    fixture::Expect(fixture::notification_text == L"Settings saved automatically.",
        "English saved text");
    fixture::accept_notifications = false;
    fixture::Expect(!tray.NotifySettingsSaved(false), "notification rejection is reported");
    fixture::accept_notifications = true;
  }
}

void DpiMinimumDuringTransitionTest() {
  HiddenWindow window;
  fixture::dpi = 168;
  fixture::work = RECT{0, 0, 1920, 1080};
  window.Create(L"Hidden DPI minimum regression", Win32Window::Point(100, 100),
      Win32Window::Size(320, 180));
  // During WM_DPICHANGED the window's DPI is already the destination DPI,
  // while MonitorFromWindow may still identify its old physical rectangle.
  fixture::monitor_dpi_override = 168;
  DpiChange(window, 96, RECT{100, 100, 420, 280});
  MINMAXINFO limits{};
  window.MessageHandler(window.GetHandle(), WM_GETMINMAXINFO, 0,
      reinterpret_cast<LPARAM>(&limits));
  fixture::Expect(limits.ptMinTrackSize.x == 320 && limits.ptMinTrackSize.y == 180,
      "transition minimum uses new window DPI instead of old monitor DPI");
  const auto bounds = window.GetWindowBounds();
  fixture::Expect(bounds.rect.right - bounds.rect.left == 320 &&
      bounds.rect.bottom - bounds.rect.top == 180,
      "transition work-area clamp uses destination DPI for minimum size");
  fixture::monitor_dpi_override = 0;
}

template <typename T, typename = void>
struct HasCloseLifecycle : std::false_type {};
template <typename T>
struct HasCloseLifecycle<T, std::void_t<decltype(
    std::declval<T>().SetCloseRequestCallback(std::function<void()>{})),
    decltype(std::declval<T>().RequestExit())>> : std::true_type {};

template <typename Window = HiddenWindow>
void TaskbarPresenceAndCloseTest() {
  Window window;
  fixture::dpi = 96;
  fixture::work = RECT{0, 0, 1600, 1000};
  window.Create(L"Hidden close regression", Win32Window::Point(100, 100),
      Win32Window::Size(601, 301));
  auto extended = GetWindowLongPtrW(window.GetHandle(), GWL_EXSTYLE);
  fixture::Expect((extended & WS_EX_TOOLWINDOW) != 0 &&
      (extended & WS_EX_APPWINDOW) == 0, "floating panel has no taskbar button");
  window.SetSettingsMode(true);
  extended = GetWindowLongPtrW(window.GetHandle(), GWL_EXSTYLE);
  fixture::Expect((extended & WS_EX_TOOLWINDOW) == 0 &&
      (extended & WS_EX_APPWINDOW) != 0, "settings has a taskbar button");
  fixture::Expect(!IsWindowVisible(window.GetHandle()),
      "changing taskbar presence never reveals a hidden fixture");
  window.SetSettingsMode(false);
  fixture::Expect((GetWindowLongPtrW(window.GetHandle(), GWL_EXSTYLE) &
      WS_EX_TOOLWINDOW) != 0, "returning to panel removes taskbar presence");
  if constexpr (!HasCloseLifecycle<Window>::value) {
    fixture::Expect(false, "user close and explicit exit have separate paths");
  } else {
    int requests = 0;
    window.SetCloseRequestCallback([&]() { ++requests; });
    const HWND handle = window.GetHandle();
    window.MessageHandler(handle, WM_CLOSE, 0, 0);
    fixture::Expect(requests == 1 && IsWindow(handle),
        "user close requests save or hide without terminating the host");
    window.SetCloseRequestCallback(nullptr);
    window.MessageHandler(handle, WM_CLOSE, 0, 0);
    fixture::Expect(IsWindow(handle), "missing close handler keeps recovery window alive");
    window.RequestExit();
    fixture::Expect(IsWindow(handle), "explicit exit is queued after channel reply");
    Pump(handle);
    fixture::Expect(!IsWindow(handle), "explicit Exit destroys the host");
  }
}

int main() {
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  DpiGeometryTest();
  NativeMenuTest();
  NativeResizeAndDisplayChangeTest();
  SavedNotificationTest();
  OutsideClickTest();
  DpiMinimumDuringTransitionTest();
  TaskbarPresenceAndCloseTest();
  ProbeCompositionLifetimeTest();
  if (fixture::failures != 0) return 1;
  std::cout << fixture::checks << " native window checks passed.\n";
  return 0;
}
