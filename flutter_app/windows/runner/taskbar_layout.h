#ifndef RUNNER_TASKBAR_LAYOUT_H_
#define RUNNER_TASKBAR_LAYOUT_H_
#include "taskbar_protocol.h"
namespace taskbar {
struct LayoutSnapshot {
  RECT bounds{};  // Physical screen coordinates, primary horizontal taskbar.
  std::vector<RECT> occupied;
  bool complete = false, visible = true;
  UINT dpi = 96;
};
struct LayoutResult { Status status = Status::waiting; RECT rect{}; };
LayoutResult FitFreeRegion(const LayoutSnapshot& snapshot, int logical_width,
                           int logical_height);
// Helper-only discovery. Never invoked by the Flutter process or isolated tests.
LayoutSnapshot DiscoverTaskbar(HWND taskbar, HWND own_window);
}
#endif
