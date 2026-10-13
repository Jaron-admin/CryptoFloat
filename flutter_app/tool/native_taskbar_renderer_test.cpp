// Keep the renderer fixture in the same process: GDI DCs are process resources.
// The included implementation's test build can attach only to its own fake bar.
#define TASKBAR_ISOLATED_TEST
#include "../windows/runner/taskbar_main.cpp"
#include <cstdio>
int main() {
  Host host;
  host.frame.foreground = 0xFF00FF00;
  host.frame.cells = {{L"CPU 25%", 0, L"Processor"}, {L"内存 —", 0xFFFFFFFF, L"Memory"}};
  HWND parent = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", nullptr, WS_POPUP,
      0, 0, 360, 48, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  host.display = CreateWindowExW(0, L"STATIC", nullptr, WS_CHILD, 0, 0, 360, 48,
      parent, nullptr, GetModuleHandleW(nullptr), nullptr);
  if (!parent || !host.display) return 2;
  host.Fonts(96);
  HDC dc = CreateCompatibleDC(nullptr); BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER); info.bmiHeader.biWidth = 360;
  info.bmiHeader.biHeight = -48; info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32; info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr; HBITMAP bitmap = CreateDIBSection(dc, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (!bitmap) return 2;
  auto old = SelectObject(dc, bitmap); host.Render(dc);
  bool background = false, first_row = false, second_row = false, inherited_color = false;
  auto pixels = static_cast<uint32_t*>(bits);
  for (int i = 0; i < 360 * 48; ++i) {
    auto rgb = pixels[i] & 0xFFFFFF;
    background |= rgb == 0x202020;
    inherited_color |= ((rgb >> 8) & 255) > ((rgb >> 16) & 255) + 20;
    if (rgb != 0x202020) { if (i < 360 * 24) first_row = true; else second_row = true; }
  }
  std::printf("%s native renderer paints opaque background and both text rows\n",
              background && first_row && second_row ? "PASS" : "FAIL");
  std::printf("%s cell with inherited color uses frame foreground\n", inherited_color ? "PASS" : "FAIL");
  SelectObject(dc, old); DeleteObject(bitmap); DeleteDC(dc);
  DestroyWindow(host.display); DestroyWindow(parent);
  DeleteObject(host.text_font); DeleteObject(host.number_font);
  return background && first_row && second_row && inherited_color ? 0 : 1;
}
