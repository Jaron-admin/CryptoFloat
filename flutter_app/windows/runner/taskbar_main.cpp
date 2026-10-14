#include "taskbar_layout.h"
#include <commctrl.h>
#include <shellapi.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <deque>
#include <mutex>
#include <thread>

namespace {
constexpr wchar_t kControllerClass[] = L"MetricPerchTaskbarController";
constexpr wchar_t kDisplayClass[] = L"MetricPerchTaskbarDisplay";
bool SurfaceDiagnosticsEnabled() {
  wchar_t value[2]{};
  return GetEnvironmentVariableW(L"METRICPERCH_TASKBAR_RENDER_DIAGNOSTICS", value, 2) == 1 &&
      value[0] == L'1';
}
class WindowDpiScope {
 public:
  explicit WindowDpiScope(HWND window)
      : previous_(SetThreadDpiAwarenessContext(GetWindowDpiAwarenessContext(window))) {}
  ~WindowDpiScope() {
    if (previous_) {
      const DWORD error = preserve_error_ ? exit_error_ : GetLastError();
      SetThreadDpiAwarenessContext(previous_);
      SetLastError(error);
    }
  }
  bool valid() const { return previous_ != nullptr; }
  void PreserveError(DWORD error) { exit_error_ = error; preserve_error_ = true; }
  WindowDpiScope(const WindowDpiScope&) = delete;
  WindowDpiScope& operator=(const WindowDpiScope&) = delete;
 private:
  DPI_AWARENESS_CONTEXT previous_;
  DWORD exit_error_ = ERROR_SUCCESS;
  bool preserve_error_ = false;
};
struct PixelSurface {
  HDC dc = nullptr;
  HBITMAP bitmap = nullptr;
  HGDIOBJ previous = nullptr;
  uint32_t* pixels = nullptr;
  PixelSurface(int width, int height) {
    if (width <= 0 || height <= 0 || width > 12800 || height > 1024) return;
    dc = CreateCompatibleDC(nullptr);
    if (!dc) return;
    BITMAPINFO info{}; info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width; info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1; info.bmiHeader.biBitCount = 32; info.bmiHeader.biCompression = BI_RGB;
    bitmap = CreateDIBSection(dc, &info, DIB_RGB_COLORS, reinterpret_cast<void**>(&pixels), nullptr, 0);
    if (bitmap) previous = SelectObject(dc, bitmap);
  }
  ~PixelSurface() {
    if (previous) SelectObject(dc, previous);
    if (bitmap) DeleteObject(bitmap);
    if (dc) DeleteDC(dc);
  }
  PixelSurface(const PixelSurface&) = delete;
  PixelSurface& operator=(const PixelSurface&) = delete;
};
struct Host {
  HANDLE input = nullptr, output = nullptr, parent = nullptr, stop = nullptr;
  HWND controller = nullptr, display = nullptr, tooltip = nullptr;
  std::atomic<HWND> own_window{nullptr};
  std::mutex mutex;
  TaskbarFrame frame;
  TaskbarFrame incoming_frame;
  uint64_t revision = 0, painted_revision = 0;
  taskbar::Status status = taskbar::Status::waiting;
  bool status_dirty = true;
  std::deque<taskbar::Action> actions;
  taskbar::LayoutSnapshot snapshot;
  HWND snapshot_bar = nullptr;
  ULONGLONG snapshot_time = 0;
  std::thread ipc, discovery;
  HFONT text_font = nullptr, number_font = nullptr;
  UINT font_dpi = 0;
  SIZE painted_size{};
  bool surface_diagnostics = SurfaceDiagnosticsEnabled();
  unsigned surface_diagnostic_count = 0;
  std::wstring tooltip_text;
  std::string last_diagnostic;
#ifdef TASKBAR_ISOLATED_TEST
  HWND fake_bar = nullptr;
#endif
  void SetStatus(taskbar::Status next, const char* reason = "stateChanged", uint32_t error = 0,
                 const taskbar::LayoutSnapshot* layout = nullptr, ULONGLONG age = 0) {
    const std::string key = std::string("state=") + taskbar::StatusName(next) + " reason=" + reason +
        " code=" + std::to_string(error);
    {
      std::lock_guard<std::mutex> lock(mutex);
      if (status != next) { status = next; status_dirty = true; }
      if (last_diagnostic == key) return;
      last_diagnostic = key;
    }
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, key +
        " discovery=" + (layout ? layout->reason : "none") +
        " nodes=" + std::to_string(layout ? layout->nodes : 0) +
        " controls=" + std::to_string(layout ? layout->controls : 0) +
        " occupied=" + std::to_string(layout ? layout->occupied.size() : 0) +
        " ignored_own=" + std::to_string(layout ? layout->ignored_own : 0) +
        " age_ms=" + std::to_string(age));
  }
  void Shutdown() {
    SetEvent(stop); PostMessageW(controller, WM_CLOSE, 0, 0);
  }
  void PipeLoop() {
    std::vector<uint8_t> buffer;
    const char* ending = "shutdownRequested";
    while (WaitForSingleObject(stop, 10) == WAIT_TIMEOUT) {
      if (WaitForSingleObject(parent, 0) != WAIT_TIMEOUT) { ending = "parentExited"; break; }
      std::vector<taskbar::Packet> packets;
      if (!taskbar::ReadPipeAvailable(input, &buffer, &packets)) { ending = "inputClosedOrMalformed"; break; }
      bool valid = true;
      for (const auto& packet : packets) {
        TaskbarFrame next;
        if (packet.type != taskbar::PacketType::frame || !taskbar::DecodeFrame(packet.payload, &next)) { valid = false; break; }
        std::lock_guard<std::mutex> lock(mutex); incoming_frame = std::move(next); ++revision;
      }
      if (!valid) { ending = "invalidFramePacket"; break; }
      std::deque<taskbar::Action> pending;
      bool send_status; taskbar::Status current;
      {
        std::lock_guard<std::mutex> lock(mutex);
        send_status = status_dirty; status_dirty = false; current = status; pending.swap(actions);
      }
      if (send_status && !taskbar::WritePacket(output, taskbar::PacketType::status,
          taskbar::EncodeCode(static_cast<uint32_t>(current)))) { ending = "statusWriteFailed"; break; }
      for (auto action : pending) {
        if (!taskbar::WritePacket(output, taskbar::PacketType::action,
            taskbar::EncodeCode(static_cast<uint32_t>(action)))) { valid = false; break; }
      }
      if (!valid) { ending = "actionWriteFailed"; break; }
    }
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, std::string("ipc=") + ending);
    Shutdown();
  }
  void DiscoveryLoop() {
    const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    while (WaitForSingleObject(stop, 200) == WAIT_TIMEOUT) {
      const ULONGLONG observed_at = GetTickCount64();
      HWND bar = nullptr; taskbar::LayoutSnapshot next;
#ifdef TASKBAR_ISOLATED_TEST
      bar = fake_bar;
      next = {{0, 0, 1200, 48}, {{0, 0, 400, 48}, {1000, 0, 1200, 48}}, true, true, 96};
#ifdef TASKBAR_TEST_DISCOVERY_DELAY_MS
      // Compiled only into the hidden fixture, never the production helper.
      Sleep(TASKBAR_TEST_DISCOVERY_DELAY_MS);
#endif
#else
      bar = FindWindowW(L"Shell_TrayWnd", nullptr);
      if (SUCCEEDED(com)) next = taskbar::DiscoverTaskbar(bar, own_window.load());
      else { next.reason = "comInitializationFailed"; next.error = static_cast<uint32_t>(com); }
#endif
      std::lock_guard<std::mutex> lock(mutex);
      snapshot = std::move(next); snapshot_bar = bar; snapshot_time = observed_at;
    }
    if (SUCCEEDED(com)) CoUninitialize();
  }
  void RemoveDisplay() {
    if (tooltip && IsWindow(tooltip)) {
      SendMessageW(tooltip, TTM_POP, 0, 0);
      DestroyWindow(tooltip);
    }
    tooltip = nullptr;
    if (display && IsWindow(display)) DestroyWindow(display);
    display = nullptr; tooltip = nullptr; own_window.store(nullptr);
    painted_size = {};
  }
  void Fonts(UINT dpi) {
    if (text_font) DeleteObject(text_font);
    if (number_font) DeleteObject(number_font);
    const int height = -MulDiv(static_cast<int>(std::lround(frame.font_size)), static_cast<int>(dpi), 96);
    text_font = CreateFontW(height, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, DEFAULT_PITCH, frame.font_family.c_str());
    number_font = CreateFontW(height, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, DEFAULT_PITCH, frame.number_font_family.c_str());
    font_dpi = dpi;
  }
  void Tooltip() {
    tooltip_text.clear();
    for (const auto& cell : frame.cells) {
      if (!tooltip_text.empty()) tooltip_text += L"\n";
      tooltip_text += cell.tooltip.empty() ? cell.text : cell.tooltip;
      // The validated IPC frame bounds the aggregate string; retain every cell.
    }
    TOOLINFOW info{sizeof(TOOLINFOW)};
    info.uFlags = TTF_IDISHWND | TTF_SUBCLASS; info.hwnd = display;
    info.uId = reinterpret_cast<UINT_PTR>(display); info.lpszText = tooltip_text.data();
    SendMessageW(tooltip, TTM_UPDATETIPTEXTW, 0, reinterpret_cast<LPARAM>(&info));
  }
  bool TooltipNotification(const NMHDR* notification) {
    if (!notification || notification->hwndFrom != tooltip ||
        (notification->code != TTN_SHOW && notification->code != TTN_POP)) return false;
    RECT tip{}, panel{}, intersection{};
    GetWindowRect(tooltip, &tip); GetWindowRect(display, &panel);
    const bool overlap = IntersectRect(&intersection, &tip, &panel) != FALSE;
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper,
        std::string("tooltip=") + (notification->code == TTN_SHOW ? "show" : "pop") +
        " own_owner=" + std::to_string(GetWindow(tooltip, GW_OWNER) == controller ? 1 : 0) +
        " panel_overlap=" + std::to_string(overlap ? 1 : 0));
    return true;
  }
  void Tick() {
    taskbar::LayoutSnapshot layout; HWND bar; ULONGLONG time; uint64_t next_revision;
    TaskbarFrame next;
    {
      std::lock_guard<std::mutex> lock(mutex);
      next = incoming_frame; next_revision = revision; layout = snapshot; bar = snapshot_bar; time = snapshot_time;
    }
    const bool changed = next_revision != painted_revision;
    frame = std::move(next);
    if (!frame.enabled) { RemoveDisplay(); SetStatus(taskbar::Status::disabled, "disabledByConfig"); return; }
    if (next_revision == 0 || !bar || !IsWindow(bar) || GetTickCount64() - time > 1000) {
      const char* reason = next_revision == 0 ? "awaitingFrame" : time == 0 ? "awaitingDiscovery" :
          !bar || !IsWindow(bar) ? layout.reason : "staleDiscovery";
      RemoveDisplay(); SetStatus(taskbar::Status::waiting, reason, layout.error, &layout,
          time ? GetTickCount64() - time : 0); return;
    }
#if !defined(TASKBAR_ISOLATED_TEST) || defined(TASKBAR_TEST_NATIVE_COORDINATES)
    RECT actual{};
    if (!GetWindowRect(bar, &actual) || !EqualRect(&actual, &layout.bounds)) {
      RemoveDisplay(); SetStatus(taskbar::Status::waiting, "taskbarBoundsChanged"); return;
    }
#endif
    if (layout.dpi < 48 || layout.dpi > 768) {
      RemoveDisplay(); SetStatus(taskbar::Status::waiting, "invalidTaskbarDpi", 0, &layout); return;
    }
    const bool font_changed = changed || font_dpi != layout.dpi;
    if (font_changed) Fonts(layout.dpi);
    int height = static_cast<int>(std::ceil(frame.font_size + 4)) * frame.line_count + 4;
    auto result = taskbar::FitFreeRegion(layout, RequiredLogicalWidth(), height, 64);
    if (result.status != taskbar::Status::displaying) {
      const char* reason = result.status == taskbar::Status::noSpace ? "insufficientFreeRegion" :
          result.status == taskbar::Status::unsupported ? "unsupportedOrientation" : layout.reason;
      RemoveDisplay(); SetStatus(result.status, reason, layout.error, &layout, GetTickCount64() - time); return;
    }
    if (display && GetParent(display) != bar) RemoveDisplay();
    bool created = false;
    if (!display) {
      // Matching Explorer's DPI context affects only this isolated process/thread.
      auto previous = SetThreadDpiAwarenessContext(GetWindowDpiAwarenessContext(bar));
      // Give the glyph surface its own compositor layer. An ordinary child can paint
      // correctly yet remain hidden behind the Windows 11 taskbar compositor.
      display = CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_LAYERED, kDisplayClass, L"MetricPerch · 数栖", WS_CHILD,
          0, 0, 1, 1, bar, nullptr, GetModuleHandleW(nullptr), this);
      const DWORD create_error = display ? ERROR_SUCCESS : GetLastError();
      if (previous) SetThreadDpiAwarenessContext(previous);
      if (!display) { SetStatus(taskbar::Status::error, "createDisplayFailed", create_error); return; }
      created = true;
      own_window.store(display);
      tooltip = CreateWindowExW(WS_EX_TOPMOST | WS_EX_NOACTIVATE, TOOLTIPS_CLASSW, nullptr,
          WS_POPUP | TTS_ALWAYSTIP | TTS_NOPREFIX, 0, 0, 0, 0, controller, nullptr, GetModuleHandleW(nullptr), nullptr);
      if (tooltip) {
        TOOLINFOW info{sizeof(TOOLINFOW)}; info.uFlags = TTF_IDISHWND | TTF_SUBCLASS;
        info.hwnd = display; info.uId = reinterpret_cast<UINT_PTR>(display); info.lpszText = const_cast<wchar_t*>(L"");
        SendMessageW(tooltip, TTM_ADDTOOLW, 0, reinterpret_cast<LPARAM>(&info));
        SendMessageW(tooltip, TTM_SETMAXTIPWIDTH, 0, 600);
      }
    }
    if (changed || font_changed || created) Tooltip();
    RECT position = result.rect;
#if !defined(TASKBAR_ISOLATED_TEST) || defined(TASKBAR_TEST_NATIVE_COORDINATES)
    SetLastError(0);
    if (MapWindowPoints(HWND_DESKTOP, bar, reinterpret_cast<POINT*>(&position), 2) == 0 && GetLastError() != 0) {
      const DWORD error = GetLastError();
      RemoveDisplay(); SetStatus(taskbar::Status::error, "mapCoordinatesFailed", error); return;
    }
#endif
    if (!SetWindowPos(display, HWND_TOP, position.left, position.top, position.right - position.left,
        position.bottom - position.top, SWP_NOACTIVATE | SWP_SHOWWINDOW)) {
      const DWORD error = GetLastError();
      RemoveDisplay(); SetStatus(taskbar::Status::error, "positionDisplayFailed", error); return;
    }
    RECT client{}; GetClientRect(display, &client);
    if (changed || font_changed || created || painted_size.cx != client.right || painted_size.cy != client.bottom) {
      if (!Present()) {
        const DWORD error = GetLastError();
        RemoveDisplay(); SetStatus(taskbar::Status::error, "presentSurfaceFailed", error); return;
      }
      painted_size = {client.right, client.bottom};
    }
    painted_revision = next_revision;
    SetStatus(taskbar::Status::displaying, "ready", 0, &layout, GetTickCount64() - time);
  }
  static COLORREF Color(uint32_t argb) { return RGB((argb >> 16) & 255, (argb >> 8) & 255, argb & 255); }
  void Paint() {
    // UpdateLayeredWindow owns the surface. WM_PAINT only validates the region.
    PAINTSTRUCT paint; BeginPaint(display, &paint); EndPaint(display, &paint);
  }
  static bool Numeric(wchar_t c) {
    return (c >= L'0' && c <= L'9') || c == L'.' || c == L',' || c == L'%' || c == L'−';
  }
  int TextWidth(HDC dc, const std::wstring& text, const RECT* draw = nullptr) {
    int width = 0;
    for (size_t start = 0; start < text.size();) {
      const bool number = Numeric(text[start]); size_t end = start + 1;
      while (end < text.size() && Numeric(text[end]) == number) ++end;
      SelectObject(dc, number ? number_font : text_font);
      SIZE size{}; GetTextExtentPoint32W(dc, text.data() + start, static_cast<int>(end - start), &size);
      if (draw) ExtTextOutW(dc, draw->left + width, draw->top + (draw->bottom - draw->top - size.cy) / 2,
          ETO_CLIPPED, draw, text.data() + start, static_cast<UINT>(end - start), nullptr);
      width += size.cx; start = end;
    }
    return width;
  }
  std::vector<int> DesiredColumns(HDC dc) {
    std::vector<int> widths((frame.cells.size() + frame.line_count - 1) / frame.line_count, 1);
    for (size_t i = 0; i < frame.cells.size(); ++i) {
      auto& width = widths[i / frame.line_count]; width = (std::max)(width, TextWidth(dc, frame.cells[i].text));
    }
    return widths;
  }
  int RequiredLogicalWidth() {
    if (font_dpi < 48 || font_dpi > 768) return frame.width;
    HDC dc = CreateCompatibleDC(nullptr);
    if (!dc) return frame.width;
    const auto previous = GetCurrentObject(dc, OBJ_FONT);
    const auto widths = DesiredColumns(dc);
    int pixels = MulDiv(8, static_cast<int>(font_dpi), 96);
    for (int width : widths) pixels += width;
    if (!widths.empty()) pixels += static_cast<int>(widths.size() - 1) * MulDiv(frame.item_gap, static_cast<int>(font_dpi), 96);
    SelectObject(dc, previous); DeleteDC(dc);
    return (std::clamp)((pixels * 96 + static_cast<int>(font_dpi) - 1) / static_cast<int>(font_dpi), 64, frame.width);
  }
  std::vector<uint32_t> RenderPixels(int width, int height) {
    PixelSurface mask(width, height);
    if (!mask.pixels) return {};
    const size_t count = static_cast<size_t>(width) * height;
    std::fill(mask.pixels, mask.pixels + count, 0);
    // Alpha one is visually transparent but keeps the full rectangle hit-testable.
    // A zero-alpha background would pass mouse input through to Explorer.
    const uint32_t background = frame.transparent_background ? 0x01000000 : (frame.background | 0xFF000000);
    std::vector<uint32_t> pixels(count, background);
    SetBkMode(mask.dc, TRANSPARENT); SetTextColor(mask.dc, RGB(255, 255, 255));
    const int padding = MulDiv(4, static_cast<int>(font_dpi), 96);
    const int gap = MulDiv(frame.item_gap, static_cast<int>(font_dpi), 96);
    const auto desired = DesiredColumns(mask.dc);
    SelectObject(mask.dc, text_font); SIZE ellipsis_size{}; GetTextExtentPoint32W(mask.dc, L"…", 1, &ellipsis_size);
    const auto widths = taskbar::CompactColumns(desired, (std::max)(0, width - 2 * padding), gap, (std::max)(1L, ellipsis_size.cx));
    int left = padding;
    for (size_t col = 0; col < widths.size(); ++col) {
      for (int row = 0; row < frame.line_count; ++row) {
        const size_t i = col * frame.line_count + row;
        if (i >= frame.cells.size() || widths[col] <= 0) continue;
        const auto& cell = frame.cells[i];
        const RECT r{left, row * height / frame.line_count, left + widths[col], (row + 1) * height / frame.line_count};
        std::wstring text = cell.text;
        if (col + 1 == widths.size() && widths.size() < desired.size()) text += L" …";
        const bool clipped = TextWidth(mask.dc, text, &r) > widths[col];
        if (clipped) {
          SelectObject(mask.dc, text_font);
          RECT tail{(std::max)(r.left, r.right - ellipsis_size.cx), r.top, r.right, r.bottom};
          FillRect(mask.dc, &tail, static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));
          DrawTextW(mask.dc, L"…", 1, &tail, DT_SINGLELINE | DT_VCENTER | DT_RIGHT);
        }
        GdiFlush();
        const uint32_t color = cell.color == 0 ? frame.foreground : cell.color;
        for (int y = r.top; y < r.bottom; ++y) for (int x = r.left; x < r.right; ++x) {
          const auto index = static_cast<size_t>(y) * width + x;
          const uint32_t coverage = mask.pixels[index] & 255; // Grayscale glyph mask; no ClearType fringe.
          const uint32_t inverse = 255 - coverage;
          const uint32_t alpha = coverage + (((background >> 24) * inverse + 127) / 255);
          uint32_t result = alpha << 24;
          for (int shift = 0; shift <= 16; shift += 8) {
            const uint32_t channel = ((((color >> shift) & 255) * coverage + ((background >> shift) & 255) * inverse + 127) / 255);
            result |= channel << shift;
          }
          pixels[index] = result;
        }
      }
      left += widths[col] + gap;
    }
    return pixels;
  }
  bool Present() {
    // Client dimensions and ULW's explicit SIZE must share the child's units.
    // A PMv2 caller sizing an unaware child would otherwise scale twice.
    WindowDpiScope dpi_context(display);
    if (!dpi_context.valid()) return false;
    RECT client{};
    if (!GetClientRect(display, &client)) { dpi_context.PreserveError(GetLastError()); return false; }
    auto pixels = RenderPixels(client.right, client.bottom);
    PixelSurface surface(client.right, client.bottom);
    if (pixels.empty() || !surface.pixels) { dpi_context.PreserveError(GetLastError()); return false; }
    std::copy(pixels.begin(), pixels.end(), surface.pixels);
    POINT source{};
    SIZE size{client.right, client.bottom};
    BLENDFUNCTION blend{AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
    // Tick has already positioned/sized this cross-process child in parent
    // coordinates. Preserve that position; explicitly submit the bitmap size.
    const BOOL uploaded = UpdateLayeredWindow(display, nullptr, nullptr, &size,
        surface.dc, &source, 0, &blend, ULW_ALPHA);
    const DWORD error = uploaded ? ERROR_SUCCESS : GetLastError();
    if (surface_diagnostics && surface_diagnostic_count < 3) {
      ++surface_diagnostic_count;
      size_t ink = 0, opaque = 0;
      uint32_t maximum_alpha = 0;
      for (const auto pixel : pixels) {
        const uint32_t alpha = pixel >> 24;
        maximum_alpha = (std::max)(maximum_alpha, alpha);
        if (alpha == 255) ++opaque;
        if (frame.transparent_background ? alpha > 1 :
            (pixel & 0xFFFFFF) != (frame.background & 0xFFFFFF)) ++ink;
      }
      const HWND parent_window = GetParent(display);
      RECT parent_rect{}, child_rect{};
      const bool parent_measured = GetWindowRect(parent_window, &parent_rect) != FALSE;
      const bool child_measured = GetWindowRect(display, &child_rect) != FALSE;
      std::string record = "surface_upload=" + std::to_string(surface_diagnostic_count) +
          " width=" + std::to_string(size.cx) + " height=" + std::to_string(size.cy) +
          " ink_pixels=" + std::to_string(ink) + " opaque_pixels=" + std::to_string(opaque) +
          " max_alpha=" + std::to_string(maximum_alpha) + " success=" + std::to_string(uploaded ? 1 : 0) +
          " code=" + std::to_string(error) + " geometry_ok=" + std::to_string(parent_measured && child_measured ? 1 : 0);
      const auto rectangle = [&record](const char* prefix, const RECT& rect) {
        record += std::string(" ") + prefix + "_x=" + std::to_string(rect.left) +
            " " + prefix + "_y=" + std::to_string(rect.top) +
            " " + prefix + "_width=" + std::to_string(rect.right - rect.left) +
            " " + prefix + "_height=" + std::to_string(rect.bottom - rect.top);
      };
      rectangle("parent", parent_rect); rectangle("child", child_rect);
      record += " parent_dpi=" + std::to_string(GetDpiForWindow(parent_window)) +
          " child_dpi=" + std::to_string(GetDpiForWindow(display)) +
          " thread_awareness=" + std::to_string(static_cast<int>(GetAwarenessFromDpiAwarenessContext(GetThreadDpiAwarenessContext()))) +
          " parent_awareness=" + std::to_string(static_cast<int>(GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(parent_window)))) +
          " child_awareness=" + std::to_string(static_cast<int>(GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(display))));
      taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, record);
    }
    // The scope outlives the surfaces and restores this failure after GDI cleanup.
    if (!uploaded) dpi_context.PreserveError(error);
    return uploaded != FALSE;
  }
  void Render(HDC dc) {
    RECT client{}; GetClientRect(display, &client);
    auto pixels = RenderPixels(client.right, client.bottom);
    if (pixels.empty()) return;
    BITMAPINFO info{}; info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = client.right; info.bmiHeader.biHeight = -client.bottom;
    info.bmiHeader.biPlanes = 1; info.bmiHeader.biBitCount = 32; info.bmiHeader.biCompression = BI_RGB;
    SetDIBitsToDevice(dc, 0, 0, client.right, client.bottom, 0, 0, 0, client.bottom, pixels.data(), &info, DIB_RGB_COLORS);
  }
  void Menu(LPARAM location) {
    POINT point{static_cast<short>(LOWORD(location)), static_cast<short>(HIWORD(location))};
    if (point.x == -1 && point.y == -1) { RECT r{}; GetWindowRect(display, &r); point = {r.left, r.top}; }
    HMENU menu = CreatePopupMenu();
    const wchar_t* english[] = {L"Show floating panel", L"Settings", L"Refresh", L"Disable taskbar", L"Exit"};
    const wchar_t* chinese[] = {L"显示悬浮窗", L"设置", L"刷新", L"关闭任务栏显示", L"退出"};
    for (UINT i = 0; i < 5; ++i) AppendMenuW(menu, MF_STRING, i + 1, frame.chinese ? chinese[i] : english[i]);
    const auto command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                                       point.x, point.y, 0, display, nullptr);
    DestroyMenu(menu);
    if (command >= 1 && command <= 5) {
      std::lock_guard<std::mutex> lock(mutex);
      if (actions.size() < 32) actions.push_back(static_cast<taskbar::Action>(command));
    }
  }
};
LRESULT CALLBACK DisplayProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto* host = reinterpret_cast<Host*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    host = static_cast<Host*>(reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(host));
  }
  if (host) {
    switch (message) {
      case WM_PAINT: host->Paint(); return 0;
      case WM_PRINTCLIENT: host->Render(reinterpret_cast<HDC>(wparam)); return 0;
      case WM_ERASEBKGND: return 1;
      case WM_NOTIFY: if (host->TooltipNotification(reinterpret_cast<NMHDR*>(lparam))) return 0; break;
      case WM_CONTEXTMENU: host->Menu(lparam); return 0;
      case WM_MOUSEACTIVATE: return MA_NOACTIVATE;
      case WM_LBUTTONDBLCLK: {
        std::lock_guard<std::mutex> lock(host->mutex);
        if (host->actions.size() < 32) host->actions.push_back(taskbar::Action::settings);
        return 0;
      }
    }
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}
LRESULT CALLBACK ControllerProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto* host = reinterpret_cast<Host*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    host = static_cast<Host*>(reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(host));
  }
  if (host) {
    if (message == WM_NOTIFY && host->TooltipNotification(reinterpret_cast<NMHDR*>(lparam))) return 0;
    if (message == WM_TIMER) { host->Tick(); return 0; }
    if (message == WM_THEMECHANGED || message == WM_DISPLAYCHANGE || message == WM_SETTINGCHANGE || message == WM_DPICHANGED) {
      host->RemoveDisplay(); host->font_dpi = 0;
      std::lock_guard<std::mutex> lock(host->mutex); host->snapshot_time = 0;
      return 0;
    }
    if (message == WM_CLOSE) { host->RemoveDisplay(); DestroyWindow(hwnd); return 0; }
    if (message == WM_DESTROY) { SetEvent(host->stop); PostQuitMessage(0); return 0; }
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}
HANDLE ParseHandle(const wchar_t* value) {
  wchar_t* end = nullptr; const auto handle = _wcstoui64(value, &end, 10);
  return end != value && *end == 0 && handle != 0 ? reinterpret_cast<HANDLE>(handle) : nullptr;
}
}
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
  taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, "startup=begin");
  int count = 0; auto args = CommandLineToArgvW(GetCommandLineW(), &count);
  if (!args || count != 4) {
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, "startup=invalidArguments");
    if (args) LocalFree(args); return 2;
  }
  Host host; host.frame.enabled = false; host.incoming_frame.enabled = false;
  host.input = ParseHandle(args[1]); host.output = ParseHandle(args[2]); host.parent = ParseHandle(args[3]); LocalFree(args);
  if (!host.input || !host.output || !host.parent || GetFileType(host.input) != FILE_TYPE_PIPE ||
      GetFileType(host.output) != FILE_TYPE_PIPE || GetProcessId(host.parent) == 0 ||
      GetProcessId(host.parent) == GetCurrentProcessId()) {
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, "startup=invalidHandles"); return 2;
  }
  host.stop = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!host.stop) {
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, "startup=createEventFailed code=" + std::to_string(GetLastError()));
    return 2;
  }
  INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_WIN95_CLASSES}; InitCommonControlsEx(&controls);
  WNDCLASSW controller{}; controller.hInstance = instance; controller.lpfnWndProc = ControllerProc;
  controller.lpszClassName = kControllerClass;
  WNDCLASSW display{}; display.hInstance = instance; display.lpfnWndProc = DisplayProc;
  display.lpszClassName = kDisplayClass; display.style = CS_DBLCLKS; display.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  RegisterClassW(&controller); RegisterClassW(&display);
  host.controller = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kControllerClass, nullptr,
      WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, instance, &host);
  if (!host.controller) {
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::helper, "startup=createControllerFailed code=" + std::to_string(GetLastError()));
    CloseHandle(host.stop); return 2;
  }
#ifdef TASKBAR_ISOLATED_TEST
  // This separately compiled test binary cannot discover or attach to Explorer.
  host.fake_bar = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", L"Isolated fake taskbar",
      WS_POPUP, 0, 0, 1200, 48, nullptr, nullptr, instance, nullptr);
#endif
  SetTimer(host.controller, 1, 50, nullptr);
  host.ipc = std::thread([&host] { host.PipeLoop(); });
  host.discovery = std::thread([&host] { host.DiscoveryLoop(); });
  MSG message;
  while (GetMessageW(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessageW(&message); }
  SetEvent(host.stop);
  CancelSynchronousIo(host.ipc.native_handle()); host.ipc.join();
  // A broken shell UIA provider may stall only this helper's discovery thread.
  // Do not hold up parent shutdown waiting for that provider to answer.
  if (WaitForSingleObject(host.discovery.native_handle(), 500) != WAIT_OBJECT_0) {
    ExitProcess(0);
  }
  host.discovery.join();
  if (host.text_font) DeleteObject(host.text_font);
  if (host.number_font) DeleteObject(host.number_font);
#ifdef TASKBAR_ISOLATED_TEST
  if (host.fake_bar) DestroyWindow(host.fake_bar);
#endif
  CloseHandle(host.input); CloseHandle(host.output); CloseHandle(host.parent); CloseHandle(host.stop);
  return 0;
}
