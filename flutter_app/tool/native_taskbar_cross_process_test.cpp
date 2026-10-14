// Read/write only windows created by this fixture. Real shell discovery remains
// compiled out, while Tick uses the production bounds and coordinate mapping.
#include "../windows/runner/taskbar_layout.h"
#include <regex>

namespace fixture {
bool upload_size_matches = true, upload_position_unchanged = true;
bool upload_context_matches = true, upload_preserves_rect = true;
bool fail_upload = false;
BOOL DeleteDiagnosticDC(HDC dc) {
  const BOOL result = DeleteDC(dc);
  // Successful Win32 cleanup is allowed to overwrite the thread's last error.
  if (fail_upload) SetLastError(ERROR_BUSY);
  return result;
}
unsigned upload_count = 0;
std::vector<std::string> diagnostics;
BOOL Upload(HWND window, HDC destination, POINT* position, SIZE* size, HDC source,
            POINT* source_position, COLORREF key, BLENDFUNCTION* blend, DWORD flags) {
  RECT client{};
  RECT before{}, after{};
  BITMAP bitmap{};
  const bool sampled = GetWindowRect(window, &before) && GetClientRect(window, &client) &&
      GetObjectW(GetCurrentObject(source, OBJ_BITMAP), sizeof(bitmap), &bitmap) != 0;
  ++upload_count;
  upload_position_unchanged &= position == nullptr;
  upload_size_matches &= size && sampled && size->cx == client.right &&
      size->cy == client.bottom && size->cx == bitmap.bmWidth && size->cy == bitmap.bmHeight;
  upload_context_matches &= AreDpiAwarenessContextsEqual(GetThreadDpiAwarenessContext(),
      GetWindowDpiAwarenessContext(window)) != FALSE;
  if (fail_upload) { SetLastError(ERROR_INVALID_PARAMETER); return FALSE; }
  // Forward the real upload: the later physical geometry assertions must also
  // catch any DPI virtualization caused by supplying this size.
  const BOOL uploaded = UpdateLayeredWindow(window, destination, position, size, source,
      source_position, key, blend, flags);
  const DWORD error = GetLastError();
  upload_preserves_rect &= GetWindowRect(window, &after) && EqualRect(&before, &after);
  if (!uploaded) SetLastError(error);
  return uploaded;
}
}
namespace taskbar {
void CaptureDiagnostic(DiagnosticSource, const std::string& message) {
  fixture::diagnostics.push_back(message);
}
}
#define UpdateLayeredWindow fixture::Upload
#define DeleteDC fixture::DeleteDiagnosticDC
#define WriteDiagnostic CaptureDiagnostic
#define TASKBAR_ISOLATED_TEST
#define TASKBAR_TEST_NATIVE_COORDINATES
#include "../windows/runner/taskbar_main.cpp"
#undef UpdateLayeredWindow
#undef DeleteDC
#undef WriteDiagnostic
#include <cstdio>

bool SurfaceDiagnosticsTest(HWND parent) {
  bool failure_paths_valid = true;
  auto capture = [parent, &failure_paths_valid](const wchar_t* value) {
    SetEnvironmentVariableW(L"METRICPERCH_TASKBAR_RENDER_DIAGNOSTICS", value);
    fixture::diagnostics.clear();
    Host host;
    host.frame.cells = {{L"PRIVATE_FIXTURE_TEXT 25%", 0xFFFFFFFF, L"PRIVATE_TOOLTIP"}};
    host.Fonts(96);
    host.display = CreateWindowExW(WS_EX_LAYERED | WS_EX_NOACTIVATE, kDisplayClass,
        nullptr, WS_CHILD, 0, 0, 300, 48, parent, nullptr, GetModuleHandleW(nullptr), &host);
    bool uploaded = host.display != nullptr;
    for (int i = 0; i < 8 && uploaded; ++i) uploaded &= host.Present();
    const auto caller_context = GetThreadDpiAwarenessContext();
    fixture::fail_upload = true;
    const bool failed = !host.Present();
    const DWORD upload_error = GetLastError();
    fixture::fail_upload = false;
    failure_paths_valid &= failed && upload_error == ERROR_INVALID_PARAMETER &&
        AreDpiAwarenessContextsEqual(caller_context, GetThreadDpiAwarenessContext());
    host.RemoveDisplay(); DeleteObject(host.text_font); DeleteObject(host.number_font);
    return uploaded;
  };
  bool good = capture(nullptr) && fixture::diagnostics.empty();
  std::printf("%s surface upload diagnostics are disabled by default\n", good ? "PASS" : "FAIL");
  const bool invalid_disabled = capture(L"yes") && fixture::diagnostics.empty();
  std::printf("%s surface diagnostics require exact explicit opt-in\n", invalid_disabled ? "PASS" : "FAIL");
  good &= invalid_disabled;
  const bool enabled = capture(L"1");
  const std::regex numeric_record(
      "surface_upload=[0-9]+ width=[0-9]+ height=[0-9]+ ink_pixels=[1-9][0-9]* "
      "opaque_pixels=[0-9]+ max_alpha=255 success=1 code=0 geometry_ok=1 "
      "parent_x=-?[0-9]+ parent_y=-?[0-9]+ parent_width=[0-9]+ parent_height=[0-9]+ "
      "child_x=-?[0-9]+ child_y=-?[0-9]+ child_width=[0-9]+ child_height=[0-9]+ "
      "parent_dpi=[0-9]+ child_dpi=[0-9]+ thread_awareness=-?[0-9]+ "
      "parent_awareness=-?[0-9]+ child_awareness=-?[0-9]+");
  const bool bounded = enabled && fixture::diagnostics.size() == 3 &&
      std::all_of(fixture::diagnostics.begin(), fixture::diagnostics.end(),
          [&numeric_record](const auto& record) { return std::regex_match(record, numeric_record); });
  std::printf("%s explicit surface diagnostics contain only numeric upload evidence and stop at three\n",
      bounded ? "PASS" : "FAIL");
  std::printf("%s failed upload restores caller DPI context and preserves Win32 error\n",
      failure_paths_valid ? "PASS" : "FAIL");
  SetEnvironmentVariableW(L"METRICPERCH_TASKBAR_RENDER_DIAGNOSTICS", nullptr);
  return good && bounded && failure_paths_valid;
}

int CheckRenderer(HWND parent) {
  WNDCLASSW display{}; display.hInstance = GetModuleHandleW(nullptr);
  display.lpfnWndProc = DisplayProc; display.lpszClassName = kDisplayClass;
  RegisterClassW(&display);
  SetEnvironmentVariableW(L"METRICPERCH_TASKBAR_RENDER_DIAGNOSTICS", nullptr);
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
  const auto caller_context = GetThreadDpiAwarenessContext();
  host.Tick();
  const auto expected = taskbar::FitFreeRegion(host.snapshot, host.RequiredLogicalWidth(), 36, 64);
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
      !GetLayeredWindowAttributes(host.display, nullptr, &alpha, &layered_flags) &&
      (GetWindowLongPtrW(host.display, GWL_EXSTYLE) & WS_EX_TRANSPARENT) == 0;
  std::printf("%s cross-process child attaches to hidden parent dpi=%u\n", created ? "PASS" : "FAIL", host.snapshot.dpi);
  std::printf("%s physical coordinate mapping matches fitted region expected=%ld,%ld,%ld,%ld actual=%ld,%ld,%ld,%ld\n",
      positioned ? "PASS" : "FAIL", expected.rect.left, expected.rect.top, expected.rect.right, expected.rect.bottom,
      actual.left, actual.top, actual.right, actual.bottom);
  std::printf("%s visible nonactivating child sits above full-width fixture sibling while parent stays hidden\n", styles ? "PASS" : "FAIL");
  std::printf("%s child uses per-pixel compositor alpha without mouse passthrough style\n", layered ? "PASS" : "FAIL");
  const bool upload_contract = fixture::upload_count == 1 && fixture::upload_size_matches &&
      fixture::upload_position_unchanged;
  std::printf("%s upload explicitly declares full bitmap/client size without changing position\n",
      upload_contract ? "PASS" : "FAIL");
  const bool upload_context = fixture::upload_context_matches && fixture::upload_preserves_rect &&
      AreDpiAwarenessContextsEqual(caller_context, GetThreadDpiAwarenessContext());
  std::printf("%s upload uses child DPI context, preserves its rectangle, and restores caller context\n",
      upload_context ? "PASS" : "FAIL");
  bool stable_updates = created;
  for (int step = 0; step < 3 && stable_updates; ++step) {
    if (step == 1) {
      ++host.revision;
      host.incoming_frame.cells[0].color = 0xFF00FF00; // Changed frame, same measured width.
    }
    host.snapshot_time = GetTickCount64();
    host.Tick();
    RECT updated{};
    stable_updates &= host.status == taskbar::Status::displaying &&
        GetWindowRect(host.display, &updated) && EqualRect(&actual, &updated) &&
        AreDpiAwarenessContextsEqual(caller_context, GetThreadDpiAwarenessContext());
  }
  stable_updates &= fixture::upload_size_matches && fixture::upload_position_unchanged &&
      fixture::upload_context_matches && fixture::upload_preserves_rect;
  std::printf("%s same changed and same frame updates keep geometry and upload units stable\n",
      stable_updates ? "PASS" : "FAIL");
  host.RemoveDisplay();
  if (host.text_font) DeleteObject(host.text_font);
  if (host.number_font) DeleteObject(host.number_font);
  const bool diagnostics = SurfaceDiagnosticsTest(parent);
  return created && positioned && styles && layered && upload_contract && upload_context && stable_updates && diagnostics ? 0 : 1;
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
