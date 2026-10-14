// All windows are hidden and belong to this fixture; never discover Explorer.
#define TASKBAR_ISOLATED_TEST
#include "../windows/runner/taskbar_main.cpp"
#include <cstdio>

int main() {
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
  int failures = 0;
  auto check = [&failures](bool ok, const char* label) {
    std::printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    if (!ok) ++failures;
  };
  INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_WIN95_CLASSES}; InitCommonControlsEx(&controls);
  WNDCLASSW cls{}; cls.lpfnWndProc = DisplayProc; cls.hInstance = GetModuleHandleW(nullptr);
  cls.lpszClassName = kDisplayClass; RegisterClassW(&cls);
  Host host;
  HWND bar = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", nullptr, WS_POPUP,
      0, 0, 1200, 48, nullptr, nullptr, cls.hInstance, nullptr);
  host.controller = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", nullptr, WS_POPUP,
      0, 0, 0, 0, nullptr, nullptr, cls.hInstance, nullptr);
  host.incoming_frame.cells = {{L"CPU 25%", 0xFFFFFFFF, L"Processor usage 25 percent"}};
  host.revision = 1; host.snapshot_bar = bar; host.snapshot_time = GetTickCount64();
  host.snapshot = {{0, 0, 1200, 48}, {{0, 0, 400, 48}, {1000, 0, 1200, 48}}, true, true, 96};
  host.Tick();
  HWND tip = host.tooltip;
  check(host.display && tip && GetWindow(tip, GW_OWNER) == host.controller,
        "tooltip belongs to helper controller rather than external taskbar");
  check(!IsWindowVisible(bar) && !IsWindowVisible(host.controller) && !IsWindowVisible(tip),
        "hover fixture creates no visible desktop windows");
  const HWND panel = host.display;
  NMHDR notification{}; notification.hwndFrom = tip; notification.code = TTN_SHOW;
  host.TooltipNotification(&notification); host.Tick();
  notification.code = TTN_POP; host.TooltipNotification(&notification); host.Tick();
  check(host.display == panel && IsWindow(panel) && IsWindow(tip),
        "tooltip show and pop notifications preserve the fitted display");
  host.frame.cells.assign(7, {L"X", 0xFFFFFFFF, std::wstring(4000, L'x')});
  host.frame.cells.back().tooltip += L" final-item";
  host.Tooltip();
  check(host.tooltip_text.find(L"final-item") != std::wstring::npos && host.tooltip_text.size() > 8192,
        "tooltip retains complete validated content beyond the old truncation limit");
  host.RemoveDisplay();
  check(tip && !IsWindow(tip), "removing display explicitly destroys tooltip");
  host.snapshot.dpi = 0; host.snapshot_time = GetTickCount64();
  host.Tick();
  check(host.display == nullptr && host.status == taskbar::Status::waiting,
        "transient zero taskbar DPI is rejected before font measurement");
  // Cleanup even while the old implementation fails the ownership regression.
  if (tip && IsWindow(tip)) DestroyWindow(tip);
  DestroyWindow(host.controller); DestroyWindow(bar);
  if (host.text_font) DeleteObject(host.text_font);
  if (host.number_font) DeleteObject(host.number_font);
  return failures ? 1 : 0;
}
