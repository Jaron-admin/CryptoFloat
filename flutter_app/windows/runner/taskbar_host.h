#ifndef RUNNER_TASKBAR_HOST_H_
#define RUNNER_TASKBAR_HOST_H_
#include <windows.h>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

struct TaskbarCell {
  std::wstring text;
  uint32_t color = 0;  // Zero inherits the frame foreground; opaque black is 0xFF000000.
  std::wstring tooltip;
};
struct TaskbarFrame {
  bool enabled = true, chinese = true;
  int width = 360, line_count = 2;
  double font_size = 11;
  std::wstring font_family = L"Segoe UI";
  uint32_t background = 0xFF202020, foreground = 0xFFF3F3F3;
  std::vector<TaskbarCell> cells;
  std::wstring number_font_family = L"Segoe UI";
  bool transparent_background = true;
  int item_gap = 6;  // Logical pixels, applied between content-sized columns.
};
class TaskbarHost {
 public:
  explicit TaskbarHost(HWND owner);
  ~TaskbarHost();
  std::string Update(const TaskbarFrame& frame);
  std::string TakeAction();
  TaskbarHost(const TaskbarHost&) = delete;
  TaskbarHost& operator=(const TaskbarHost&) = delete;
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
#endif
