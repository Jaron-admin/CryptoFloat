// Offscreen glyph and alpha checks; this fixture creates no visible windows.
#define TASKBAR_ISOLATED_TEST
#include "../windows/runner/taskbar_main.cpp"
#include <cstdio>
int main() {
  int failures = 0;
  auto check = [&failures](bool ok, const char* label) {
    std::printf("%s %s\n", ok ? "PASS" : "FAIL", label); if (!ok) ++failures;
  };
  Host host;
  host.frame.foreground = 0xFF00FF00;
  host.frame.font_size = 16;
  host.frame.cells = {{L"CPU 25%", 0, L"Processor"}, {L"内存 42%", 0xFFFFFFFF, L"Memory"},
                      {L"D 3K", 0xFFFF0000, L"Download speed 3 kilobytes per second"}};
  host.Fonts(96);
  const auto pixels = host.RenderPixels(360, 48);
  bool edge = pixels.size() == 360 * 48, first = false, second = false, full = false, inherited = false, premultiplied = edge;
  int last_ink = 0;
  for (size_t i = 0; i < pixels.size(); ++i) {
    const uint32_t pixel = pixels[i], alpha = pixel >> 24;
    const uint32_t red = (pixel >> 16) & 255, green = (pixel >> 8) & 255, blue = pixel & 255;
    premultiplied &= red <= alpha && green <= alpha && blue <= alpha;
    if (i < 360 || i >= 360 * 47 || i % 360 == 0 || i % 360 == 359) edge &= pixel == 0x01000000;
    if (alpha > 1) {
      if (i < 360 * 24) first = true; else second = true;
      full |= alpha == 255; inherited |= green > red + 20 && green > blue + 20;
      last_ink = (std::max)(last_ink, static_cast<int>(i % 360));
    }
  }
  check(edge, "transparent rectangle edges retain only alpha one without a frame");
  check(first && second && full && inherited, "both text rows retain opaque glyph interiors and inherited colors");
  check(premultiplied, "all antialiased text pixels contain valid premultiplied alpha");
  check(last_ink < 250 && host.RequiredLogicalWidth() < 260, "short content occupies measured width rather than equal-width cells");
  host.frame.transparent_background = false;
  const auto opaque = host.RenderPixels(360, 48);
  check(opaque.size() == pixels.size() && opaque.front() == host.frame.background &&
        std::all_of(opaque.begin(), opaque.end(), [](uint32_t p) { return (p >> 24) == 255; }),
        "opaque background remains available with every output pixel fully opaque");
  host.frame.transparent_background = true;
  host.frame.cells.assign(32, {L"Very long data field 123456789", 0xFFFFFFFF, L"Full unabridged tooltip"});
  const auto narrow = host.RenderPixels(64, 48);
  check(narrow.size() == 64 * 48 && std::any_of(narrow.begin(), narrow.end(), [](uint32_t p) { return (p >> 24) > 1; }),
        "narrow surface safely renders clipped text and overflow ellipsis");
  check(host.frame.cells.back().tooltip == L"Full unabridged tooltip", "clipping never changes full tooltip data");
  WNDCLASSW cls{}; cls.lpfnWndProc = DisplayProc; cls.hInstance = GetModuleHandleW(nullptr);
  cls.lpszClassName = kDisplayClass; RegisterClassW(&cls);
  HWND panel = CreateWindowExW(0, kDisplayClass, L"Hidden paging fixture", WS_POPUP,
      0, 0, 80, 48, nullptr, nullptr, cls.hInstance, &host);
  host.frame.line_count = 2;
  host.frame.cells = {{L"AAAAA", 0xFFFF0000, L"first"}, {L"BBBBB", 0xFFFF0000, L"paired"},
                      {L"CCCCC", 0xFF00FF00, L"second"}, {L"DDDDD", 0xFF00FF00, L"paired"}};
  const auto before_scroll = host.RenderPixels(80, 48);
  SendMessageW(panel, WM_MOUSEWHEEL, MAKEWPARAM(0, static_cast<WORD>(-WHEEL_DELTA)), 0);
  const auto after_scroll = host.RenderPixels(80, 48);
  check(before_scroll != after_scroll, "mouse wheel reveals a later whole-column page");
  check(host.pages.size() == 2 && host.pages[0].first == 0 && host.pages[1].first == 1 && host.page_index == 1,
        "two row pairs remain together on wheel-selected pages");
  host.page_index = 0; host.wheel_remainder = 0;
  check(!host.ScrollPages(-60, 1000) && host.page_index == 0 && host.ScrollPages(-60, 1100) && host.page_index == 1,
        "high resolution wheel accumulates partial notches without losing movement");
  host.page_index = 0; host.frame.auto_carousel = true; host.frame.carousel_interval_seconds = 5;
  host.next_page_at = 5000;
  host.frame.cells[0].text = L"AAAA"; host.UpdatePagination(80);
  check(!host.AdvancePage(4999) && host.AdvancePage(5000) && host.page_index == 1,
        "ordinary value width updates do not postpone carousel forever");
  host.SetHovered(true, 5100);
  check(!host.AdvancePage(50000) && host.page_index == 1, "hover pauses automatic carousel");
  host.SetHovered(false, 50001);
  check(!host.AdvancePage(55000) && host.AdvancePage(55001) && host.page_index == 0,
        "leaving hover grants a full readable interval before resuming");
  host.ScrollPages(-WHEEL_DELTA, 60000);
  check(!host.AdvancePage(64999) && host.AdvancePage(65000), "manual wheel grants a full interval before auto advance");
  host.frame.auto_carousel = false;
  check(!host.AdvancePage(1000000) && host.ScrollPages(-WHEEL_DELTA, 1000001),
        "manual only mode never auto advances but retains wheel navigation");
  host.frame.auto_carousel = true; host.frame.carousel_interval_seconds = 2; host.next_page_at = 0;
  check(!host.AdvancePage(2000000) && !host.AdvancePage(2001999) && host.AdvancePage(2002000),
        "custom two second interval changes automatic timing");
  host.frame.carousel_interval_seconds = 60; host.next_page_at = 0;
  check(!host.AdvancePage(3000000) && !host.AdvancePage(3059999) && host.AdvancePage(3060000),
        "custom sixty second interval changes automatic timing");
  host.frame.cells = {{L"legacy", 0xFF00FF00, L"BTC 123 -5%", L"BTC", L"123", L"-5%", 0xFFFF0000, true}};
  host.frame.foreground = 0xFFFFFFFF; host.frame.line_count = 1; host.frame.label_value_gap = 0;
  const auto tight_width = host.RequiredLogicalWidth();
  host.frame.label_value_gap = 24;
  check(host.RequiredLogicalWidth() == tight_width + 24, "custom label value gap changes measured layout exactly");
  host.frame.width = 64;
  check(host.RequiredLogicalWidth() > 64, "legacy maximum width cannot cap automatic content width");
  const auto colored = host.RenderPixels(360, 32);
  bool neutral_label = false, green_price = false, red_percent = false;
  for (uint32_t pixel : colored) {
    const uint32_t a = pixel >> 24, r = (pixel >> 16) & 255, g = (pixel >> 8) & 255, b = pixel & 255;
    if (a > 128) {
      neutral_label |= r == g && g == b && r > 128;
      green_price |= g > r + 40 && g > b + 40;
      red_percent |= r > g + 40 && r > b + 40;
    }
  }
  check(neutral_label && green_price && red_percent, "label price and 24 hour suffix render with independent colors");
  check(host.pages.size() == 1 && host.page_index == 0 && !host.ScrollPages(-WHEEL_DELTA, 4000000),
        "fitting content resets to one page with no wheel movement");
  DestroyWindow(panel);
  DeleteObject(host.text_font); DeleteObject(host.number_font);
  return failures ? 1 : 0;
}
