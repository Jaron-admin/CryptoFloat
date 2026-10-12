#ifndef RUNNER_CONTEXT_MENU_H_
#define RUNNER_CONTEXT_MENU_H_

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>

#include <functional>
#include <memory>
#include <string>

struct ContextMenuStyle {
  COLORREF background = RGB(32, 32, 32);
  COLORREF foreground = RGB(250, 250, 250);
  COLORREF secondary = RGB(190, 190, 190);
  COLORREF border = RGB(65, 65, 65);
  COLORREF hover = RGB(52, 52, 52);
  COLORREF accent = RGB(96, 205, 255);
  std::wstring font_family;
};

// A native popup is independent of the Flutter surface, so even a short panel
// can display the complete menu. Windows owns focus, dismissal and navigation.
class ContextMenu : public std::enable_shared_from_this<ContextMenu> {
 public:
  using Result = flutter::MethodResult<flutter::EncodableValue>;
  using Action = std::function<void(const std::string&)>;

  explicit ContextMenu(HWND window);
  ~ContextMenu();
  void Shutdown();
  void SetAppearance(const ContextMenuStyle& style);
  void ShowPanel(POINT screen_point, bool always_on_top,
                 const ContextMenuStyle& style, std::unique_ptr<Result> result);
  void ShowTray(POINT screen_point, Action action);
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam, LRESULT* result);

 private:
  struct Session;
  void Queue(std::shared_ptr<Session> session);
  void Display();

  HWND window_;
  bool stopped_ = false;
  ContextMenuStyle last_style_;
  std::shared_ptr<Session> session_;
};

#endif  // RUNNER_CONTEXT_MENU_H_
