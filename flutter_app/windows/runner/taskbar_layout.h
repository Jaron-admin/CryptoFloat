#ifndef RUNNER_TASKBAR_LAYOUT_H_
#define RUNNER_TASKBAR_LAYOUT_H_
#include "taskbar_protocol.h"
namespace taskbar {
enum class TaskbarAlignment { left, centered, unknown };
struct LayoutSnapshot {
  RECT bounds{};  // Physical screen coordinates, primary horizontal taskbar.
  std::vector<RECT> occupied;
  bool complete = false, visible = true;
  UINT dpi = 96;
  const char* reason = "pending";
  uint32_t error = 0;
  int nodes = 0, controls = 0;
  int ignored_own = 0;
  TaskbarAlignment alignment = TaskbarAlignment::left;
  const char* alignment_reason = "alignmentNotRead";
};
struct LayoutResult { Status status = Status::waiting; RECT rect{}; };
LayoutResult FitFreeRegion(const LayoutSnapshot& snapshot, int logical_width,
                           int logical_height, int minimum_width = 0);
bool IsOwnProcess(DWORD process);
// Desired physical text widths; keeps short columns small and caps only long ones.
std::vector<int> CompactColumns(const std::vector<int>& desired, int available,
                                int gap, int minimum);
// Helper-only discovery. Never invoked by the Flutter process or isolated tests.
LayoutSnapshot DiscoverTaskbar(HWND taskbar, HWND own_window);
}
#endif
