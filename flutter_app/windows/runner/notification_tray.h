#ifndef RUNNER_NOTIFICATION_TRAY_H_
#define RUNNER_NOTIFICATION_TRAY_H_

#include <windows.h>

#include <functional>
#include <string>

// Owns the notification-area entry. The panel is never hidden without an entry
// that Windows accepted, including after Explorer restarts.
class NotificationTray {
 public:
  using Action = std::function<void(const std::string&)>;
  using Menu = std::function<void(POINT)>;

  NotificationTray(HWND window, Action action, Menu menu);
  ~NotificationTray();

  bool EnsureIcon();
  bool HideWindow();
  bool ShowWindow();
  bool NotifySettingsSaved(bool chinese);
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void RemoveIcon();
  void ShowMenu(POINT point);
  void Dispatch(const std::string& action);

  HWND window_;
  Action action_;
  Menu menu_;
  UINT taskbar_created_;
  HICON icon_ = nullptr;
  bool registered_ = false;
};

#endif  // RUNNER_NOTIFICATION_TRAY_H_
