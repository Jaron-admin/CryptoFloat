#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <commctrl.h>
#include <windowsx.h>

#include <algorithm>
#include <cmath>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(std::lround(source * scale_factor));
}

double MonitorScale(HMONITOR monitor) {
  return std::max(1.0, FlutterDesktopGetDpiForMonitor(monitor) / 96.0);
}

HMONITOR PrimaryMonitor() {
  return MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
}

struct DisplaySearch {
  const std::wstring* id;
  HMONITOR result = nullptr;
};

BOOL CALLBACK FindDisplay(HMONITOR monitor, HDC, LPRECT, LPARAM parameter) {
  auto search = reinterpret_cast<DisplaySearch*>(parameter);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (GetMonitorInfoW(monitor, reinterpret_cast<MONITORINFO*>(&info)) &&
      *search->id == info.szDevice) {
    search->result = monitor;
    return FALSE;
  }
  return TRUE;
}

RECT VisibleBounds(RECT desired, HMONITOR monitor) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) return desired;
  const LONG work_width = info.rcWork.right - info.rcWork.left;
  const LONG work_height = info.rcWork.bottom - info.rcWork.top;
  if (work_width <= 0 || work_height <= 0) return desired;
  const double scale = MonitorScale(monitor);
  const LONG width = std::min(
      work_width, std::max(static_cast<LONG>(Scale(320, scale)),
                           desired.right - desired.left));
  const LONG height = std::min(
      work_height, std::max(static_cast<LONG>(Scale(180, scale)),
                            desired.bottom - desired.top));
  const LONG left = std::clamp(desired.left, info.rcWork.left,
                              info.rcWork.right - width);
  const LONG top = std::clamp(desired.top, info.rcWork.top,
                             info.rcWork.bottom - height);
  return RECT{left, top, left + width, top + height};
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindowEx(
      WS_EX_LAYERED, window_class, title.c_str(),
      WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX | WS_CLIPCHILDREN,
      origin.x, origin.y,
      Scale(static_cast<int>(size.width), scale_factor),
      Scale(static_cast<int>(size.height), scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);
  // Commit the frameless client rectangle before creating the Flutter child.
  // Otherwise the initial frame can remain cached until the first resize.
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
  SetOpacity(0.96);
  ClampToVisibleWorkArea();

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_NCCALCSIZE:
      // Retain the resize style while Flutter paints the complete client area.
      return 0;

    case WM_NCHITTEST:
      return ResizeHitTest(lparam);

    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      const double scale = MonitorScale(monitor);
      LONG min_width = Scale(320, scale);
      LONG min_height = Scale(settings_mode_ ? 360 : 180, scale);
      MONITORINFO work_area{};
      work_area.cbSize = sizeof(work_area);
      if (GetMonitorInfoW(monitor, &work_area)) {
        min_width = std::min(min_width,
                            work_area.rcWork.right - work_area.rcWork.left);
        min_height = std::min(min_height,
                             work_area.rcWork.bottom - work_area.rcWork.top);
      }
      info->ptMinTrackSize.x = min_width;
      info->ptMinTrackSize.y = min_height;
      return 0;
    }

    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      const RECT suggested = *reinterpret_cast<RECT*>(lparam);
      const RECT visible = VisibleBounds(
          suggested, MonitorFromRect(&suggested, MONITOR_DEFAULTTONEAREST));
      SetWindowPos(hwnd, nullptr, visible.left, visible.top,
                   visible.right - visible.left, visible.bottom - visible.top,
                   SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
    case WM_DWMCOMPOSITIONCHANGED:
    case WM_THEMECHANGED:
      UpdateTheme(hwnd);
      return 0;

    case WM_DISPLAYCHANGE:
      ClampToVisibleWorkArea();
      return 0;

    case WM_SETTINGCHANGE:
      if (wparam == SPI_SETWORKAREA) ClampToVisibleWorkArea();
      break;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  SetWindowSubclass(content, ChildSubclassProc, 1,
                    reinterpret_cast<DWORD_PTR>(this));
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

LRESULT CALLBACK Win32Window::ChildSubclassProc(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam,
    UINT_PTR subclass_id, DWORD_PTR reference_data) {
  auto owner = reinterpret_cast<Win32Window*>(reference_data);
  if (message == WM_NCHITTEST && owner->ResizeHitTest(lparam) != HTCLIENT) {
    return HTTRANSPARENT;
  }
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, ChildSubclassProc, subclass_id);
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

LRESULT Win32Window::ResizeHitTest(LPARAM screen_point) const {
  RECT rect{};
  if (!GetWindowRect(window_handle_, &rect)) return HTCLIENT;
  const LONG border = Scale(
      8, MonitorScale(MonitorFromWindow(window_handle_, MONITOR_DEFAULTTONEAREST)));
  const LONG x = GET_X_LPARAM(screen_point);
  const LONG y = GET_Y_LPARAM(screen_point);
  const bool left = x >= rect.left && x < rect.left + border;
  const bool right = x < rect.right && x >= rect.right - border;
  const bool top = y >= rect.top && y < rect.top + border;
  const bool bottom = y < rect.bottom && y >= rect.bottom - border;
  if (top && left) return HTTOPLEFT;
  if (top && right) return HTTOPRIGHT;
  if (bottom && left) return HTBOTTOMLEFT;
  if (bottom && right) return HTBOTTOMRIGHT;
  if (left) return HTLEFT;
  if (right) return HTRIGHT;
  if (top) return HTTOP;
  if (bottom) return HTBOTTOM;
  return HTCLIENT;
}

Win32Window::Bounds Win32Window::GetWindowBounds() const {
  Bounds bounds;
  GetWindowRect(window_handle_, &bounds.rect);
  const HMONITOR monitor =
      MonitorFromWindow(window_handle_, MONITOR_DEFAULTTONEAREST);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (GetMonitorInfoW(monitor, reinterpret_cast<MONITORINFO*>(&info))) {
    bounds.display_id = info.szDevice;
  }
  bounds.scale = MonitorScale(monitor);
  return bounds;
}

void Win32Window::ApplyWindowBounds(const Bounds& bounds) {
  HMONITOR monitor = nullptr;
  if (!bounds.display_id.empty()) {
    DisplaySearch search{&bounds.display_id};
    EnumDisplayMonitors(nullptr, nullptr, FindDisplay,
                        reinterpret_cast<LPARAM>(&search));
    monitor = search.result;
  } else {
    monitor = MonitorFromRect(&bounds.rect, MONITOR_DEFAULTTONULL);
  }
  // A stale desktop layout can leave saved coordinates beyond every display,
  // even when its former display device name is still enumerated.
  if (!MonitorFromRect(&bounds.rect, MONITOR_DEFAULTTONULL)) {
    monitor = PrimaryMonitor();
  }
  if (!monitor) monitor = PrimaryMonitor();
  const double ratio = MonitorScale(monitor) / std::max(0.5, bounds.scale);
  RECT desired = bounds.rect;
  desired.right = desired.left + Scale(bounds.rect.right - bounds.rect.left, ratio);
  desired.bottom = desired.top + Scale(bounds.rect.bottom - bounds.rect.top, ratio);
  const RECT visible = VisibleBounds(desired, monitor);
  SetWindowPos(window_handle_, nullptr, visible.left, visible.top,
               visible.right - visible.left, visible.bottom - visible.top,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

void Win32Window::ClampToVisibleWorkArea() {
  RECT current{};
  if (!GetWindowRect(window_handle_, &current)) return;
  HMONITOR monitor = MonitorFromRect(&current, MONITOR_DEFAULTTONULL);
  if (!monitor) monitor = PrimaryMonitor();
  const RECT visible = VisibleBounds(current, monitor);
  if (EqualRect(&current, &visible)) return;
  SetWindowPos(window_handle_, nullptr, visible.left, visible.top,
               visible.right - visible.left, visible.bottom - visible.top,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

bool Win32Window::SetAlwaysOnTop(bool enabled) {
  return SetWindowPos(window_handle_, enabled ? HWND_TOPMOST : HWND_NOTOPMOST,
                      0, 0, 0, 0,
                      SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE) != FALSE;
}

bool Win32Window::SetOpacity(double opacity) {
  panel_opacity_ = std::clamp(opacity, 0.4, 1.0);
  return ApplyOpacity();
}

bool Win32Window::ApplyOpacity() {
  const auto alpha = static_cast<BYTE>(std::lround(
      (settings_mode_ ? 1.0 : panel_opacity_) * 255.0));
  return SetLayeredWindowAttributes(window_handle_, 0, alpha, LWA_ALPHA) != FALSE;
}

void Win32Window::SetSettingsMode(bool enabled) {
  if (enabled == settings_mode_) return;
  settings_mode_ = enabled;
  ApplyOpacity();
  if (enabled) {
    panel_bounds_ = GetWindowBounds();
    Bounds settings = panel_bounds_;
    settings.rect.right = settings.rect.left + Scale(920, settings.scale);
    settings.rect.bottom = settings.rect.top + Scale(720, settings.scale);
    ApplyWindowBounds(settings);
  } else {
    ApplyWindowBounds(panel_bounds_);
  }
}

bool Win32Window::BeginMoveOrResize(int hit_test) {
  POINT cursor{};
  GetCursorPos(&cursor);
  ReleaseCapture();
  return PostMessage(window_handle_, WM_NCLBUTTONDOWN,
                     static_cast<WPARAM>(hit_test),
                     MAKELPARAM(cursor.x, cursor.y)) != FALSE;
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  // Keep WS_THICKFRAME for native resizing, but let Flutter own every pixel
  // of the frame. WM_NCCALCSIZE alone does not control DWM border decoration.
  const DWMNCRENDERINGPOLICY rendering_policy = DWMNCRP_DISABLED;
  DwmSetWindowAttribute(window, DWMWA_NCRENDERING_POLICY,
                        &rendering_policy, sizeof(rendering_policy));

  // Windows 11 has a separate border-color attribute. Its documented numeric
  // value also lets this runner build with older SDKs; Windows 10 ignores it.
  constexpr DWORD kBorderColorAttribute = 34;  // DWMWA_BORDER_COLOR
  constexpr COLORREF kNoBorderColor = 0xFFFFFFFE;  // DWMWA_COLOR_NONE
  DwmSetWindowAttribute(window, kBorderColorAttribute,
                        &kNoBorderColor, sizeof(kNoBorderColor));

  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
