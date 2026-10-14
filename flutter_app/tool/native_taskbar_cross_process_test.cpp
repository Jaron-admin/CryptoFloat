// Read/write only windows created by this fixture. Real shell discovery remains
// compiled out, while Tick uses the production bounds and coordinate mapping.
#define TASKBAR_ISOLATED_TEST
#define TASKBAR_TEST_NATIVE_COORDINATES
#include "../windows/runner/taskbar_main.cpp"
#include <cstdio>

int CheckRenderer(HWND parent) {
  WNDCLASSW display{}; display.hInstance = GetModuleHandleW(nullptr);
  display.lpfnWndProc = DisplayProc; display.lpszClassName = kDisplayClass;
  RegisterClassW(&display);
  Host host;
  host.incoming_frame.font_size = 12;
  host.incoming_frame.cells = {{L"CPU 25%", 0xFFFFFFFF, L"CPU"}};
  host.revision = 1;
  host.snapshot_bar = parent;
  if (!GetWindowRect(parent, &host.snapshot.bounds)) return 2;
  const auto bounds = host.snapshot.bounds;
  const LONG width = bounds.right - bounds.left;
  host.snapshot.occupied = {{bounds.left, bounds.top, bounds.left + width / 4, bounds.bottom},
      {bounds.left + width * 3 / 4, bounds.top, bounds.right, bounds.bottom}};
  host.snapshot.dpi = GetDpiForWindow(parent);
  host.snapshot.visible = true; host.snapshot.complete = true;
  host.snapshot.reason = "isolatedCrossProcessFixture";
  host.snapshot_time = GetTickCount64();
  const auto expected = taskbar::FitFreeRegion(host.snapshot, 360, 36);
  host.Tick();
  RECT actual{};
  const bool created = host.status == taskbar::Status::displaying && host.display && GetParent(host.display) == parent;
  // Unaware hosts virtualize coordinates into logical integer pixels. A mapping
  // round trip may therefore round by one logical pixel at fractional scaling.
  const bool unaware = GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(parent)) == DPI_AWARENESS_UNAWARE;
  const LONG tolerance = unaware ? static_cast<LONG>((GetDpiForSystem() + 95) / 96) : 0;
  const bool positioned = created && expected.status == taskbar::Status::displaying &&
      GetWindowRect(host.display, &actual) && std::abs(expected.rect.left - actual.left) <= tolerance &&
      std::abs(expected.rect.top - actual.top) <= tolerance && std::abs(expected.rect.right - actual.right) <= tolerance &&
      std::abs(expected.rect.bottom - actual.bottom) <= tolerance &&
      actual.left > host.snapshot.occupied.front().right && actual.right < host.snapshot.occupied.back().left &&
      actual.top >= bounds.top && actual.bottom <= bounds.bottom;
  const bool styles = created && (GetWindowLongPtrW(host.display, GWL_STYLE) & (WS_CHILD | WS_VISIBLE)) == (WS_CHILD | WS_VISIBLE) &&
      (GetWindowLongPtrW(host.display, GWL_EXSTYLE) & WS_EX_NOACTIVATE) != 0 && !IsWindowVisible(parent) &&
      GetWindow(host.display, GW_HWNDPREV) == nullptr;
  BYTE alpha = 0; DWORD layered_flags = 0;
  const bool layered = created && (GetWindowLongPtrW(host.display, GWL_EXSTYLE) & WS_EX_LAYERED) != 0 &&
      GetLayeredWindowAttributes(host.display, nullptr, &alpha, &layered_flags) && alpha == 255 && layered_flags == LWA_ALPHA;
  std::printf("%s cross-process child attaches to hidden parent dpi=%u\n", created ? "PASS" : "FAIL", host.snapshot.dpi);
  std::printf("%s physical coordinate mapping matches fitted region expected=%ld,%ld,%ld,%ld actual=%ld,%ld,%ld,%ld\n",
      positioned ? "PASS" : "FAIL", expected.rect.left, expected.rect.top, expected.rect.right, expected.rect.bottom,
      actual.left, actual.top, actual.right, actual.bottom);
  std::printf("%s visible nonactivating child sits above full-width fixture sibling while parent stays hidden\n", styles ? "PASS" : "FAIL");
  std::printf("%s GDI child has an opaque compositor surface\n", layered ? "PASS" : "FAIL");
  host.RemoveDisplay();
  if (host.text_font) DeleteObject(host.text_font);
  if (host.number_font) DeleteObject(host.number_font);
  return created && positioned && styles && layered ? 0 : 1;
}

int wmain(int argc, wchar_t** argv) {
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  if (argc == 2) return CheckRenderer(reinterpret_cast<HWND>(_wcstoui64(argv[1], nullptr, 10)));
  if (argc != 1) return 2;
  int failures = 0;
  const DPI_AWARENESS_CONTEXT contexts[] = {DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
      DPI_AWARENESS_CONTEXT_SYSTEM_AWARE, DPI_AWARENESS_CONTEXT_UNAWARE};
  for (const auto context : contexts) {
    const auto previous = SetThreadDpiAwarenessContext(context);
    HWND parent = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, L"STATIC", L"Hidden taskbar fixture",
        WS_POPUP, 100, 100, 2200, 96, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (parent) {
      // Same sibling shape as the observed composition bridge, without creating
      // an actual compositor or drawing to the desktop.
      HWND bridge = CreateWindowExW(WS_EX_NOREDIRECTIONBITMAP, L"STATIC", nullptr,
          WS_CHILD | WS_VISIBLE, 0, 0, 2200, 96, parent, nullptr, GetModuleHandleW(nullptr), nullptr);
      if (!bridge) { DestroyWindow(parent); return 2; }
    }
    if (previous) SetThreadDpiAwarenessContext(previous);
    if (!parent) return 2;
    RECT before{}; GetWindowRect(parent, &before);
    wchar_t module[32768]{}; GetModuleFileNameW(nullptr, module, 32768);
    std::wstring command = L"\"" + std::wstring(module) + L"\" " + std::to_wstring(reinterpret_cast<uintptr_t>(parent));
    STARTUPINFOW startup{sizeof(startup)}; PROCESS_INFORMATION child{};
    HANDLE output = nullptr;
    if (!DuplicateHandle(GetCurrentProcess(), GetStdHandle(STD_OUTPUT_HANDLE), GetCurrentProcess(),
        &output, 0, TRUE, DUPLICATE_SAME_ACCESS)) { DestroyWindow(parent); return 2; }
    startup.dwFlags = STARTF_USESTDHANDLES; startup.hStdOutput = output; startup.hStdError = output;
    const bool launched = CreateProcessW(module, command.data(), nullptr, nullptr, TRUE, CREATE_NO_WINDOW,
        nullptr, nullptr, &startup, &child) != FALSE;
    CloseHandle(output);
    if (!launched) { DestroyWindow(parent); return 2; }
    CloseHandle(child.hThread);
    const auto deadline = GetTickCount64() + 5000;
    while (WaitForSingleObject(child.hProcess, 0) == WAIT_TIMEOUT && GetTickCount64() < deadline) {
      // Cross-process creation/parenting can send messages to the hidden host.
      MsgWaitForMultipleObjects(1, &child.hProcess, FALSE, 20, QS_ALLINPUT);
      MSG message{};
      while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&message); DispatchMessageW(&message); }
    }
    DWORD exit_code = STILL_ACTIVE; GetExitCodeProcess(child.hProcess, &exit_code);
    if (exit_code == STILL_ACTIVE) TerminateProcess(child.hProcess, 7);
    RECT after{}; GetWindowRect(parent, &after);
    const bool passed = exit_code == 0 && EqualRect(&before, &after) && !IsWindowVisible(parent);
    std::printf("%s hidden cross-process fixture leaves parent geometry unchanged awareness=%d\n", passed ? "PASS" : "FAIL",
        static_cast<int>(GetAwarenessFromDpiAwarenessContext(context)));
    if (!passed) ++failures;
    CloseHandle(child.hProcess); DestroyWindow(parent);
  }
  return failures == 0 ? 0 : 1;
}
