// Exercise the production UIA bounds policy using synthetic provider properties.
// This fixture never queries desktop windows or creates an automation client.
#include "../windows/runner/taskbar_layout.cpp"
#include <cstdio>

int main() {
  int failures = 0;
  auto check = [&failures](bool result, const char* label) {
    std::printf("%s %s\n", result ? "PASS" : "FAIL", label);
    if (!result) ++failures;
  };
  taskbar::AutomationWalk walk;
  walk.bounds = {0, 0, 1200, 48};
  bool complete = walk.RecordBounds(FALSE, TRUE, {0, 0, 400, 48}, UIA_ButtonControlTypeId, true, 1);
  complete &= walk.RecordBounds(FALSE, TRUE, {1000, 0, 1200, 48}, UIA_ButtonControlTypeId, false, 1);
  complete &= walk.RecordBounds(FALSE, FALSE, {0, 0, 0, 0}, UIA_CustomControlTypeId, false, 2);
  complete &= walk.RecordBounds(FALSE, TRUE, {0, 0, 0, 0}, UIA_ButtonControlTypeId, false, 2);
  taskbar::LayoutSnapshot layout{walk.bounds, walk.occupied, complete, true, 96};
  check(complete && taskbar::FitFreeRegion(layout, 360, 34).status == taskbar::Status::displaying,
        "empty raw UIA placeholder preserves valid free taskbar region");
  check(walk.controls == 2 && walk.occupied.size() == 2,
        "empty UIA placeholder provides no occupied or completeness evidence");
  check(!walk.RecordBounds(FALSE, TRUE, {100, 0, 50, 48}, UIA_ButtonControlTypeId, false, 1),
        "inverted occupied bounds still invalidate discovery");
  check(!walk.RecordBounds(FALSE, TRUE, {0, 0, 100001, 48}, UIA_ButtonControlTypeId, false, 1),
        "out of range occupied bounds still invalidate discovery");
  check(walk.RecordBounds(FALSE, FALSE, {400, 0, 1000, 48}, UIA_CustomControlTypeId, false, 1),
        "unknown visible raw leaf remains occupied");
  layout.occupied = walk.occupied; layout.complete = true;
  check(taskbar::FitFreeRegion(layout, 360, 34).status == taskbar::Status::noSpace,
        "unknown occupied fragment cannot become an alleged free gap");
  HWND own_popup = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", nullptr, WS_POPUP,
      400, 0, 600, 48, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  std::vector<RECT> occupied;
  taskbar::NativeWalk native{nullptr, {0, 0, 1200, 48}, &occupied};
  taskbar::CollectNative(own_popup, reinterpret_cast<LPARAM>(&native));
  check(own_popup && native.ignored_own == 1 && occupied.empty(),
        "self-process popup is excluded before visibility or occupancy queries");
  if (own_popup) DestroyWindow(own_popup);
  return failures == 0 ? 0 : 1;
}
