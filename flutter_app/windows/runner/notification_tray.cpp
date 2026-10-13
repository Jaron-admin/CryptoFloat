#include "notification_tray.h"

#include <commctrl.h>
#include <shellapi.h>
#include <windowsx.h>

#include <utility>

#include "resource.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 0x35;
constexpr UINT kTrayId = 1;
}  // namespace

NotificationTray::NotificationTray(HWND window, Action action, Menu menu)
    : window_(window),
      action_(std::move(action)),
      menu_(std::move(menu)),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {}

NotificationTray::~NotificationTray() {
  RemoveIcon();
  if (icon_) DestroyIcon(icon_);
}

bool NotificationTray::EnsureIcon() {
  if (!window_ || !IsWindow(window_)) return false;
  if (!icon_ && FAILED(LoadIconMetric(GetModuleHandleW(nullptr),
                                    MAKEINTRESOURCEW(IDI_APP_ICON),
                                    LIM_SMALL, &icon_))) {
    return false;
  }
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kTrayId;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = kTrayMessage;
  data.hIcon = icon_;
  wcscpy_s(data.szTip, L"MetricPerch");
  if (registered_ && Shell_NotifyIconW(NIM_MODIFY, &data)) return true;
  registered_ = Shell_NotifyIconW(NIM_ADD, &data) != FALSE;
  if (!registered_) return false;
  data.uVersion = NOTIFYICON_VERSION_4;
  if (!Shell_NotifyIconW(NIM_SETVERSION, &data)) {
    RemoveIcon();
    return false;
  }
  return true;
}

void NotificationTray::RemoveIcon() {
  if (!registered_) return;
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kTrayId;
  Shell_NotifyIconW(NIM_DELETE, &data);
  registered_ = false;
}

bool NotificationTray::HideWindow() {
  if (!EnsureIcon()) return false;
  ::ShowWindow(window_, SW_HIDE);
  return IsWindowVisible(window_) == FALSE;
}

bool NotificationTray::ShowWindow() {
  if (!IsWindow(window_)) return false;
  ::ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window_);
  return IsWindowVisible(window_) != FALSE;
}

void NotificationTray::Dispatch(const std::string& action) {
  if (action == "show" || action == "settings") ShowWindow();
  if (action_) action_(action);
}

void NotificationTray::ShowMenu(POINT point) {
  if (point.x == -1 && point.y == -1) {
    NOTIFYICONIDENTIFIER identifier{};
    identifier.cbSize = sizeof(identifier);
    identifier.hWnd = window_;
    identifier.uID = kTrayId;
    RECT bounds{};
    if (SUCCEEDED(Shell_NotifyIconGetRect(&identifier, &bounds))) {
      point = POINT{bounds.left, bounds.bottom};
    } else {
      GetCursorPos(&point);
    }
  }
  // The shared native menu service owns the popup and its nested-loop lifetime.
  if (menu_) menu_(point);
}

bool NotificationTray::HandleMessage(UINT message, WPARAM wparam,
                                      LPARAM lparam) {
  if (taskbar_created_ != 0 && message == taskbar_created_) {
    registered_ = false;
    if (!EnsureIcon() && !IsWindowVisible(window_)) Dispatch("show");
    return true;
  }
  if (message == WM_DPICHANGED || message == WM_SETTINGCHANGE) {
    // Shell chooses the small-icon metric appropriate for the current display.
    if (icon_) DestroyIcon(icon_);
    icon_ = nullptr;
    if (!EnsureIcon() && !IsWindowVisible(window_)) Dispatch("show");
    return false;  // The host still has to process its own DPI/work-area change.
  }
  if (message != kTrayMessage || HIWORD(lparam) != kTrayId) return false;
  switch (LOWORD(lparam)) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
      Dispatch("show");
      break;
    case WM_CONTEXTMENU:
      ShowMenu(POINT{GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam)});
      break;
  }
  return true;
}
