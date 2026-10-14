#include "context_menu.h"

#include <algorithm>
#include <cwctype>
#include <utility>
#include <vector>

namespace {
constexpr UINT kShowMenu = WM_APP + 0x36;

struct Entry {
  std::wstring label;
  std::string action;
  wchar_t key = 0;
  UINT id = 0;
  bool checked = false;
  bool separator = false;
};
}  // namespace

struct ContextMenu::Session {
  POINT point{};
  ContextMenuStyle style;
  std::unique_ptr<Result> result;
  Action action;
  std::vector<std::unique_ptr<Entry>> entries;
  HMENU menu = nullptr;
  bool displaying = false;

  ~Session() {
    if (menu) DestroyMenu(menu);
  }

  void Add(const wchar_t* label, const char* command, wchar_t key,
            bool checked = false) {
    auto entry = std::make_unique<Entry>();
    entry->label = label;
    entry->action = command;
    entry->key = key;
    entry->id = static_cast<UINT>(entries.size() + 1);
    entry->checked = checked;
    entry->separator = entry->label.empty();
    entries.push_back(std::move(entry));
  }

  bool Prepare(HWND) {
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    const HMONITOR target = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
    if (!GetMonitorInfoW(target, &monitor)) return false;
    point.x = std::clamp(point.x, monitor.rcWork.left, monitor.rcWork.right - 1);
    point.y = std::clamp(point.y, monitor.rcWork.top, monitor.rcWork.bottom - 1);
    menu = CreatePopupMenu();
    if (!menu) return false;
    for (const auto& entry : entries) {
      MENUITEMINFOW item{};
      item.cbSize = sizeof(item);
      item.fMask = MIIM_FTYPE | MIIM_ID | MIIM_STATE;
      item.fType = entry->separator ? MFT_SEPARATOR : MFT_STRING;
      item.fState = entry->checked ? MFS_CHECKED : MFS_UNCHECKED;
      item.wID = entry->id;
      if (!entry->separator) {
        // Windows owns text, accessibility, font, colors, DPI and checkmarks.
        // Keep the appearance payload for compatibility, but do not owner-draw.
        item.fMask |= MIIM_STRING;
        item.dwTypeData = entry->label.data();
        item.cch = static_cast<UINT>(entry->label.size());
      }
      if (!InsertMenuItemW(menu, entry->id - 1, TRUE, &item)) return false;
    }
    return true;
  }
};

ContextMenu::ContextMenu(HWND window) : window_(window) {}
ContextMenu::~ContextMenu() { Shutdown(); }

void ContextMenu::SetAppearance(const ContextMenuStyle& style) {
  last_style_ = style;
}

void ContextMenu::Shutdown() {
  if (stopped_) return;
  stopped_ = true;
  if (!session_) return;
  // Drop channel results while the messenger is still alive. A menu's nested
  // loop may outlive the owning PlatformChannel until TrackPopupMenuEx returns.
  session_->result.reset();
  session_->action = nullptr;
  if (session_->displaying) EndMenu();
  session_.reset();
}

void ContextMenu::ShowPanel(POINT screen_point, bool always_on_top,
                            const ContextMenuStyle& style,
                            std::unique_ptr<Result> result) {
  last_style_ = style;
  auto session = std::make_shared<Session>();
  session->point = screen_point;
  session->style = style;
  session->result = std::move(result);
  session->Add(session->style.hide_label.c_str(), "hide", L'h');
  session->Add(session->style.refresh_label.c_str(), "refresh", L'r');
  session->Add(L"", "", 0);
  session->Add(session->style.topmost_label.c_str(), "topmost", L't', always_on_top);
  session->Add(session->style.settings_label.c_str(), "settings", L's');
  session->Add(L"", "", 0);
  session->Add(session->style.exit_label.c_str(), "exit", L'q');
  Queue(std::move(session));
}

void ContextMenu::ShowTray(POINT screen_point, Action action) {
  auto session = std::make_shared<Session>();
  session->point = screen_point;
  session->style = last_style_;
  session->action = std::move(action);
  session->Add(session->style.show_label.c_str(), "show", L'h');
  session->Add(session->style.refresh_label.c_str(), "refresh", L'r');
  session->Add(session->style.settings_label.c_str(), "settings", L's');
  session->Add(L"", "", 0);
  session->Add(session->style.exit_label.c_str(), "exit", L'q');
  Queue(std::move(session));
}

void ContextMenu::Queue(std::shared_ptr<Session> session) {
  if (stopped_ || session_ || !IsWindow(window_)) {
    if (session->result) session->result->Success(flutter::EncodableValue());
    return;
  }
  session_ = std::move(session);
  // Return from the channel handler first: the nested menu loop must not retain
  // its stack-owned method result while an application exit tears down Flutter.
  if (!PostMessageW(window_, kShowMenu, 0, 0)) {
    auto failed = std::move(session_);
    if (failed->result) failed->result->Error("window_operation_failed",
                                              "Windows could not open the menu.");
  }
}

void ContextMenu::Display() {
  // Keep both this owner and its item data alive through the native nested loop.
  const auto retained = shared_from_this();
  static_cast<void>(retained);
  const auto session = session_;
  if (stopped_ || !session || session->displaying) return;
  if (!session->Prepare(window_)) {
    session_.reset();
    if (session->result) session->result->Error("window_operation_failed",
                                               "Windows could not open the menu.");
    return;
  }
  SetForegroundWindow(window_);
  if (stopped_) return;
  session->displaying = true;
  const UINT alignment = GetSystemMetrics(SM_MENUDROPALIGNMENT)
      ? TPM_RIGHTALIGN : TPM_LEFTALIGN;
  const UINT selected = TrackPopupMenuEx(session->menu,
      TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | alignment,
      session->point.x, session->point.y, window_, nullptr);
  session->displaying = false;
  if (stopped_) return;
  PostMessageW(window_, WM_NULL, 0, 0);
  std::string action;
  for (const auto& entry : session->entries) {
    if (entry->id == selected && !entry->separator) action = entry->action;
  }
  session_.reset();
  if (session->result) {
    session->result->Success(action.empty() ? flutter::EncodableValue()
                                          : flutter::EncodableValue(action));
    session->result.reset();
  } else if (!action.empty() && session->action) {
    session->action(action);
  }
}

bool ContextMenu::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam,
                                LRESULT* result) {
  if (message == kShowMenu) {
    Display();
    *result = 0;
    return true;
  }
  const auto session = session_;
  if (!session || stopped_) return false;
  if (message == WM_MENUCHAR && reinterpret_cast<HMENU>(lparam) == session->menu) {
    const wchar_t key = static_cast<wchar_t>(towlower(LOWORD(wparam)));
    for (size_t index = 0; index < session->entries.size(); ++index) {
      if (session->entries[index]->key == key && key != 0) {
        *result = MAKELRESULT(static_cast<WORD>(index), MNC_EXECUTE);
        return true;
      }
    }
    *result = MAKELRESULT(0, MNC_IGNORE);
    return true;
  }
  return false;
}
