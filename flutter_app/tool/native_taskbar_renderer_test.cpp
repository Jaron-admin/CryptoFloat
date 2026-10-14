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
  DeleteObject(host.text_font); DeleteObject(host.number_font);
  return failures ? 1 : 0;
}
