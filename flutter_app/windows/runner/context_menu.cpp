#include "context_menu.h"

#include <flutter_windows.h>
#include <oleacc.h>

#include <algorithm>
#include <cmath>
#include <cwctype>
#include <utility>
#include <vector>

namespace {
constexpr UINT kShowMenu = WM_APP + 0x36;

struct Entry {
  // Windows accessibility reads this first member for owner-drawn item names.
  MSAAMENUINFO accessibility{};
  std::wstring label;
  std::string action;
  wchar_t key = 0;
  UINT id = 0;
  bool checked = false;
  bool separator = false;
};

int Pixels(int logical, UINT dpi) {
  return MulDiv(logical, static_cast<int>(dpi), 96);
}

ContextMenuStyle AccessibleStyle(ContextMenuStyle style) {
  HIGHCONTRASTW contrast{};
  contrast.cbSize = sizeof(contrast);
  if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
      (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0) {
    style.background = GetSysColor(COLOR_MENU);
    style.foreground = GetSysColor(COLOR_MENUTEXT);
    style.secondary = GetSysColor(COLOR_MENUTEXT);
    style.border = GetSysColor(COLOR_MENUTEXT);
    style.hover = GetSysColor(COLOR_HIGHLIGHT);
    style.accent = GetSysColor(COLOR_HIGHLIGHTTEXT);
  }
  return style;
}

void Line(HDC dc, int x1, int y1, int x2, int y2) {
  MoveToEx(dc, x1, y1, nullptr);
  LineTo(dc, x2, y2);
}

void Icon(HDC dc, const std::string& action, int left, int top, UINT dpi,
          COLORREF color) {
  const auto x = [left, dpi](int value) { return left + Pixels(value, dpi); };
  const auto y = [top, dpi](int value) { return top + Pixels(value, dpi); };
  HPEN pen = CreatePen(PS_SOLID, std::max(1, Pixels(1, dpi)), color);
  const HGDIOBJ old_pen = SelectObject(dc, pen);
  const HGDIOBJ old_brush = SelectObject(dc, GetStockObject(NULL_BRUSH));
  if (action == "settings") {
    Ellipse(dc, x(4), y(4), x(12), y(12));
    Ellipse(dc, x(7), y(7), x(9), y(9));
    Line(dc, x(8), y(1), x(8), y(4));
    Line(dc, x(8), y(12), x(8), y(15));
    Line(dc, x(1), y(8), x(4), y(8));
    Line(dc, x(12), y(8), x(15), y(8));
    Line(dc, x(3), y(3), x(5), y(5));
    Line(dc, x(11), y(11), x(13), y(13));
    Line(dc, x(3), y(13), x(5), y(11));
    Line(dc, x(11), y(5), x(13), y(3));
  } else if (action == "refresh") {
    Arc(dc, x(2), y(2), x(14), y(14), x(13), y(4), x(13), y(12));
    Line(dc, x(13), y(1), x(13), y(5));
    Line(dc, x(9), y(5), x(13), y(5));
  } else if (action == "topmost") {
    Line(dc, x(4), y(2), x(12), y(2));
    Line(dc, x(5), y(2), x(5), y(7));
    Line(dc, x(11), y(2), x(11), y(7));
    Line(dc, x(3), y(9), x(5), y(7));
    Line(dc, x(11), y(7), x(13), y(9));
    Line(dc, x(3), y(9), x(13), y(9));
    Line(dc, x(8), y(9), x(8), y(15));
  } else if (action == "exit") {
    Line(dc, x(8), y(2), x(3), y(2));
    Line(dc, x(3), y(2), x(3), y(14));
    Line(dc, x(3), y(14), x(8), y(14));
    Line(dc, x(7), y(8), x(15), y(8));
    Line(dc, x(11), y(4), x(15), y(8));
    Line(dc, x(11), y(12), x(15), y(8));
  } else {
    Rectangle(dc, x(2), y(2), x(14), y(12));
    Line(dc, x(5), y(15), x(11), y(15));
    if (action == "hide") {
      Line(dc, x(5), y(7), x(11), y(7));
    } else {
      Line(dc, x(8), y(5), x(8), y(10));
      Line(dc, x(5), y(8), x(8), y(5));
      Line(dc, x(8), y(5), x(11), y(8));
    }
  }
  SelectObject(dc, old_brush);
  SelectObject(dc, old_pen);
  DeleteObject(pen);
}
}  // namespace

struct ContextMenu::Session {
  POINT point{};
  ContextMenuStyle style;
  std::unique_ptr<Result> result;
  Action action;
  std::vector<std::unique_ptr<Entry>> entries;
  HMENU menu = nullptr;
  HFONT font = nullptr;
  HBRUSH background = nullptr;
  UINT dpi = 96;
  UINT width = 220;
  bool displaying = false;

  ~Session() {
    if (menu) DestroyMenu(menu);
    if (font) DeleteObject(font);
    if (background) DeleteObject(background);
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
    entry->accessibility.dwMSAASignature = MSAA_MENU_SIG;
    entry->accessibility.cchWText = static_cast<DWORD>(entry->label.size());
    entry->accessibility.pszWText = entry->label.data();
    entries.push_back(std::move(entry));
  }

  Entry* Find(ULONG_PTR data) const {
    for (const auto& entry : entries) {
      if (reinterpret_cast<ULONG_PTR>(entry.get()) == data) return entry.get();
    }
    return nullptr;
  }

  bool Prepare(HWND window) {
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    const HMONITOR target_monitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
    if (!GetMonitorInfoW(target_monitor, &monitor)) {
      return false;
    }
    point.x = std::clamp(point.x, monitor.rcWork.left, monitor.rcWork.right - 1);
    point.y = std::clamp(point.y, monitor.rcWork.top, monitor.rcWork.bottom - 1);
    // The notification area can live on a different display than the panel.
    // Match the display containing the popup anchor, including mixed-DPI setups.
    dpi = FlutterDesktopGetDpiForMonitor(target_monitor);
    if (dpi == 0) dpi = GetDpiForWindow(window);
    if (dpi == 0) dpi = 96;
    style = AccessibleStyle(style);
    LOGFONTW logical{};
    NONCLIENTMETRICSW metrics{};
    metrics.cbSize = sizeof(metrics);
    if (SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, sizeof(metrics),
                                    &metrics, 0, dpi)) {
      logical = metrics.lfMenuFont;
    }
    logical.lfHeight = -Pixels(14, dpi);
    logical.lfWeight = FW_NORMAL;
    logical.lfQuality = CLEARTYPE_QUALITY;
    if (!style.font_family.empty() && style.font_family.size() < LF_FACESIZE) {
      std::fill(std::begin(logical.lfFaceName), std::end(logical.lfFaceName), L'\0');
      std::copy(style.font_family.begin(), style.font_family.end(), logical.lfFaceName);
    }
    font = CreateFontIndirectW(&logical);
    background = CreateSolidBrush(style.background);
    menu = CreatePopupMenu();
    if (!font || !background || !menu) return false;
    int text_width = 0;
    HDC context = GetDC(window);
    if (context) {
      const HGDIOBJ previous = SelectObject(context, font);
      for (const auto& entry : entries) {
        SIZE measured{};
        GetTextExtentPoint32W(context, entry->label.c_str(),
            static_cast<int>(entry->label.size()), &measured);
        text_width = std::max(text_width, static_cast<int>(measured.cx));
      }
      SelectObject(context, previous);
      ReleaseDC(window, context);
    }
    width = static_cast<UINT>(std::max(1L, std::min(
        static_cast<LONG>(std::max(Pixels(208, dpi), text_width + Pixels(76, dpi))),
        monitor.rcWork.right - monitor.rcWork.left - Pixels(12, dpi))));
    MENUINFO appearance{};
    appearance.cbSize = sizeof(appearance);
    appearance.fMask = MIM_BACKGROUND | MIM_STYLE | MIM_MAXHEIGHT;
    appearance.hbrBack = background;
    appearance.dwStyle = MNS_NOCHECK;
    appearance.cyMax = static_cast<UINT>(std::max(1L,
        monitor.rcWork.bottom - monitor.rcWork.top - Pixels(8, dpi)));
    SetMenuInfo(menu, &appearance);
    for (const auto& entry : entries) {
      MENUITEMINFOW item{};
      item.cbSize = sizeof(item);
      item.fMask = MIIM_FTYPE | MIIM_ID | MIIM_STATE | MIIM_DATA;
      item.fType = MFT_OWNERDRAW | (entry->separator ? MFT_SEPARATOR : 0);
      item.fState = entry->checked ? MFS_CHECKED : MFS_UNCHECKED;
      item.wID = entry->id;
      item.dwItemData = reinterpret_cast<ULONG_PTR>(entry.get());
      if (!InsertMenuItemW(menu, entry->id - 1, TRUE, &item)) return false;
    }
    return true;
  }

  void Draw(const DRAWITEMSTRUCT& draw, const Entry& entry) const {
    HDC context = draw.hDC;
    const int saved = SaveDC(context);
    FillRect(context, &draw.rcItem, background);
    if (entry.separator) {
      HPEN pen = CreatePen(PS_SOLID, 1, style.border);
      SelectObject(context, pen);
      const int middle = (draw.rcItem.top + draw.rcItem.bottom) / 2;
      Line(context, draw.rcItem.left + Pixels(10, dpi), middle,
           draw.rcItem.right - Pixels(10, dpi), middle);
      RestoreDC(context, saved);
      DeleteObject(pen);
      return;
    }
    const bool selected = (draw.itemState & ODS_SELECTED) != 0;
    const bool disabled = (draw.itemState & ODS_DISABLED) != 0;
    COLORREF text = disabled ? style.secondary : style.foreground;
    HIGHCONTRASTW contrast{};
    contrast.cbSize = sizeof(contrast);
    if (selected && SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast),
          &contrast, 0) && (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0) {
      text = GetSysColor(COLOR_HIGHLIGHTTEXT);
    }
    if (selected && !disabled) {
      RECT highlight = draw.rcItem;
      InflateRect(&highlight, -Pixels(4, dpi), -Pixels(2, dpi));
      HBRUSH brush = CreateSolidBrush(style.hover);
      SelectObject(context, brush);
      SelectObject(context, GetStockObject(NULL_PEN));
      RoundRect(context, highlight.left, highlight.top, highlight.right,
                highlight.bottom, Pixels(6, dpi), Pixels(6, dpi));
      SelectObject(context, GetStockObject(NULL_BRUSH));
      DeleteObject(brush);
    }
    SetBkMode(context, TRANSPARENT);
    SetTextColor(context, text);
    SelectObject(context, font);
    RECT label = draw.rcItem;
    label.left += Pixels(38, dpi);
    label.right -= Pixels(30, dpi);
    DrawTextW(context, entry.label.c_str(), static_cast<int>(entry.label.size()),
        &label, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    Icon(context, entry.action, draw.rcItem.left + Pixels(12, dpi),
         draw.rcItem.top + (draw.rcItem.bottom - draw.rcItem.top - Pixels(16, dpi)) / 2,
         dpi, selected ? text : style.secondary);
    if (entry.checked) {
      HPEN pen = CreatePen(PS_SOLID, std::max(1, Pixels(2, dpi)),
                           selected ? text : style.accent);
      SelectObject(context, pen);
      const int left = draw.rcItem.right - Pixels(23, dpi);
      const int top = (draw.rcItem.top + draw.rcItem.bottom) / 2;
      Line(context, left, top, left + Pixels(3, dpi), top + Pixels(3, dpi));
      Line(context, left + Pixels(3, dpi), top + Pixels(3, dpi),
           left + Pixels(9, dpi), top - Pixels(4, dpi));
      SelectObject(context, GetStockObject(NULL_PEN));
      DeleteObject(pen);
    }
    RestoreDC(context, saved);
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
  session->Add(L"隐藏到托盘", "hide", L'h');
  session->Add(L"立即刷新", "refresh", L'r');
  session->Add(L"", "", 0);
  session->Add(L"窗口置顶", "topmost", L't', always_on_top);
  session->Add(L"设置", "settings", L's');
  session->Add(L"", "", 0);
  session->Add(L"退出", "exit", L'q');
  Queue(std::move(session));
}

void ContextMenu::ShowTray(POINT screen_point, Action action) {
  auto session = std::make_shared<Session>();
  session->point = screen_point;
  session->style = last_style_;
  session->action = std::move(action);
  session->Add(L"显示悬浮窗", "show", L'h');
  session->Add(L"立即刷新", "refresh", L'r');
  session->Add(L"设置", "settings", L's');
  session->Add(L"", "", 0);
  session->Add(L"退出", "exit", L'q');
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
  if (message == WM_MEASUREITEM && lparam) {
    auto measure = reinterpret_cast<MEASUREITEMSTRUCT*>(lparam);
    if (measure->CtlType != ODT_MENU) return false;
    const auto entry = session->Find(measure->itemData);
    if (!entry) return false;
    measure->itemWidth = session->width;
    measure->itemHeight = static_cast<UINT>(Pixels(entry->separator ? 9 : 32,
                                                  session->dpi));
    *result = TRUE;
    return true;
  }
  if (message == WM_DRAWITEM && lparam) {
    const auto draw = reinterpret_cast<DRAWITEMSTRUCT*>(lparam);
    if (draw->CtlType != ODT_MENU) return false;
    const auto entry = session->Find(draw->itemData);
    if (!entry) return false;
    session->Draw(*draw, *entry);
    *result = TRUE;
    return true;
  }
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
