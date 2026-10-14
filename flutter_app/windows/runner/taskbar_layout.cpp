#include "taskbar_layout.h"
#include <UIAutomation.h>
#include <wrl/client.h>
#include <algorithm>
#include <cmath>
#include <string>
namespace taskbar {
namespace {
struct AlignmentSetting {
  TaskbarAlignment value = TaskbarAlignment::unknown;
  const char* reason = "alignmentUnreadable";
  DWORD error = 0;
};
AlignmentSetting ReadTaskbarAlignment() {
  DWORD value = 0, bytes = sizeof(value);
  // This DWORD is Explorer's observed local setting. Microsoft's backup-data
  // reference uses a different representation; this is a read-only adapter.
  const LSTATUS status = RegGetValueW(HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
      L"TaskbarAl", RRF_RT_REG_DWORD, nullptr, &value, &bytes);
  if (status == ERROR_SUCCESS) {
    if (value == 0) return {TaskbarAlignment::left, "alignmentSettingLeft", 0};
    if (value == 1) return {TaskbarAlignment::centered, "alignmentSettingCentered", 0};
    return {TaskbarAlignment::unknown, "invalidAlignmentSetting", ERROR_INVALID_DATA};
  }
  if (status != ERROR_FILE_NOT_FOUND && status != ERROR_PATH_NOT_FOUND)
    return {TaskbarAlignment::unknown, "alignmentUnreadable", static_cast<DWORD>(status)};
  // Windows 11's documented default is centered. The Win10/11 manifest is
  // required for this version query; failed queries never imply a default.
  OSVERSIONINFOEXW version{}; version.dwOSVersionInfoSize = sizeof(version);
  version.dwBuildNumber = 22000;
  SetLastError(ERROR_SUCCESS);
  if (VerifyVersionInfoW(&version, VER_BUILDNUMBER,
      VerSetConditionMask(0, VER_BUILDNUMBER, VER_GREATER_EQUAL)))
    return {TaskbarAlignment::centered, "alignmentDefaultCentered", 0};
  const DWORD error = GetLastError();
  if (error == ERROR_OLD_WIN_VERSION) return {TaskbarAlignment::left, "alignmentDefaultLeft", 0};
  return {TaskbarAlignment::unknown, "alignmentUnknownWindows", error};
}
bool ValidRect(const RECT& r) {
  return r.left >= -100000 && r.right <= 100000 && r.top >= -100000 && r.bottom <= 100000 &&
         r.right > r.left && r.bottom > r.top;
}
bool Overlap(const RECT& a, const RECT& b) {
  return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
}
using Microsoft::WRL::ComPtr;
struct AutomationWalk {
  ComPtr<IUIAutomationTreeWalker> walker;
  HWND own = nullptr; RECT bounds{};
  std::vector<RECT> occupied;
  int nodes = 0, controls = 0, ignored_own = 0;
  HRESULT error = S_OK;
  const char* reason = "ready";
  bool RecordBounds(BOOL offscreen, BOOL control, const RECT& r,
                    CONTROLTYPEID type, bool has_child, int depth) {
    const bool container = type == UIA_PaneControlTypeId || type == UIA_ToolBarControlTypeId ||
        type == UIA_GroupControlTypeId || type == UIA_ListControlTypeId || type == UIA_WindowControlTypeId;
    // A non-container control is occupied even when it has text/icon descendants.
    // Unknown visible leaf fragments are occupied too. Never infer a gap inside them.
    if (!offscreen && depth > 0 && ((!container && control) || !has_child)) {
      // UIA's documented empty rectangle means no displayed UI. Raw view can
      // contain these placeholders even when IsOffscreen is false. They neither
      // occupy space nor provide the control evidence required below.
      if (r.left == 0 && r.top == 0 && r.right == 0 && r.bottom == 0) return true;
      if (!ValidRect(r)) { reason = "invalidElementBounds"; return false; }
      if (Overlap(r, bounds)) { occupied.push_back(r); if (control) ++controls; }
    }
    return true;
  }
  bool Visit(IUIAutomationElement* element, int depth) {
    if (depth > 20 || ++nodes > 512) { reason = "automationLimit"; return false; }
    UIA_HWND native = nullptr;
    reason = "automationProperties";
    int process = 0;
    if (FAILED(error = element->get_CurrentProcessId(&process))) return false;
    if (process > 0 && IsOwnProcess(static_cast<DWORD>(process))) { ++ignored_own; return true; }
    if (FAILED(error = element->get_CurrentNativeWindowHandle(&native))) return false;
    if (native == own && own) return true;
    DWORD native_process = 0;
    if (native) GetWindowThreadProcessId(static_cast<HWND>(native), &native_process);
    if (IsOwnProcess(native_process)) { ++ignored_own; return true; }
    BOOL offscreen = FALSE, control = FALSE; RECT r{}; CONTROLTYPEID type = 0;
    if (FAILED(error = element->get_CurrentIsOffscreen(&offscreen)) ||
        FAILED(error = element->get_CurrentBoundingRectangle(&r)) ||
        FAILED(error = element->get_CurrentIsControlElement(&control)) ||
        FAILED(error = element->get_CurrentControlType(&type))) return false;
    ComPtr<IUIAutomationElement> child;
    reason = "automationNavigation";
    if (FAILED(error = walker->GetFirstChildElement(element, &child))) return false;
    if (!RecordBounds(offscreen, control, r, type, child != nullptr, depth)) return false;
    while (child) {
      if (!Visit(child.Get(), depth + 1)) return false;
      ComPtr<IUIAutomationElement> next;
      reason = "automationNavigation";
      if (FAILED(error = walker->GetNextSiblingElement(child.Get(), &next))) return false;
      child = std::move(next);
    }
    reason = "ready"; return true;
  }
};
struct NativeWalk { HWND own; RECT bounds; std::vector<RECT>* occupied; bool complete = true; int ignored_own = 0; };
BOOL CALLBACK CollectNative(HWND child, LPARAM context) {
  auto& state = *reinterpret_cast<NativeWalk*>(context);
  DWORD process = 0; GetWindowThreadProcessId(child, &process);
  if (IsOwnProcess(process)) { ++state.ignored_own; return TRUE; }
  if (child == state.own || !IsWindowVisible(child)) return TRUE;
  wchar_t name[128]{}; RECT r{};
  if (!GetClassNameW(child, name, 128) || !GetWindowRect(child, &r)) { state.complete = false; return FALSE; }
  // These are layout/render containers; their actual occupied children come from UIA.
  const std::wstring cls(name);
  if (cls == L"ReBarWindow32" || cls == L"MSTaskSwWClass" || cls == L"MSTaskListWClass" ||
      cls == L"Windows.UI.Composition.DesktopWindowContentBridge" || cls == L"WorkerW") return TRUE;
  if (cls == L"Windows.UI.Input.InputSite.WindowClass") return TRUE;
  if (ValidRect(r) && Overlap(r, state.bounds)) state.occupied->push_back(r);
  return TRUE;
}
}
bool IsOwnProcess(DWORD process) { return process != 0 && process == GetCurrentProcessId(); }
std::vector<int> CompactColumns(const std::vector<int>& desired, int available, int gap, int minimum) {
  if (desired.empty() || available <= 0 || gap < 0 || minimum <= 0) return {};
  size_t count = desired.size();
  while (count > 1 && static_cast<int>(count) * minimum + static_cast<int>(count - 1) * gap > available) --count;
  const int room = (std::max)(0, available - static_cast<int>(count - 1) * gap);
  std::vector<int> widths(desired.begin(), desired.begin() + count);
  int total = 0, high = 0;
  for (auto& width : widths) { width = (std::max)(1, width); total += width; high = (std::max)(high, width); }
  if (total <= room) return widths;
  int low = 0;
  while (low < high) {
    const int cap = low + (high - low + 1) / 2;
    int used = 0; for (int width : widths) used += (std::min)(width, cap);
    if (used <= room) low = cap; else high = cap - 1;
  }
  total = 0;
  for (auto& width : widths) { width = (std::min)(width, low); total += width; }
  for (size_t i = 0; i < count && total < room; ++i) {
    if (widths[i] < desired[i]) { ++widths[i]; ++total; }
  }
  return widths;
}
std::vector<ColumnPage> PaginateColumns(const std::vector<int>& desired, int available, int gap) {
  std::vector<ColumnPage> pages;
  if (available <= 0 || gap < 0) return pages;
  ColumnPage page;
  int used = 0;
  for (size_t i = 0; i < desired.size(); ++i) {
    const int width = (std::clamp)(desired[i], 1, available);
    if (!page.widths.empty() && width > available - used - gap) {
      pages.push_back(std::move(page)); page = {}; page.first = i; used = 0;
    }
    if (!page.widths.empty()) used += gap;
    page.widths.push_back(width); used += width;
  }
  if (!page.widths.empty()) pages.push_back(std::move(page));
  return pages;
}
LayoutResult FitFreeRegion(const LayoutSnapshot& s, int width, int height, int minimum_width) {
  LayoutResult result;
  if (!ValidRect(s.bounds) || s.bounds.bottom - s.bounds.top > s.bounds.right - s.bounds.left) {
    result.status = Status::unsupported; return result;
  }
  if (!s.complete || !s.visible || s.occupied.empty() || s.dpi < 48 || s.dpi > 768 ||
      s.alignment == TaskbarAlignment::unknown) return result;
  if (width < 64 || height < 8 || height > 128) { result.status = Status::error; return result; }
  const int w = static_cast<int>((std::min)(static_cast<int64_t>(s.bounds.right - s.bounds.left),
      (static_cast<int64_t>(width) * s.dpi + 48) / 96));
  const int minimum = minimum_width == 0 ? w : MulDiv((std::clamp)(minimum_width, 1, width), static_cast<int>(s.dpi), 96);
  const int h = MulDiv(height, static_cast<int>(s.dpi), 96);
  const int padding = MulDiv(8, static_cast<int>(s.dpi), 96);
  const bool far_left = s.alignment == TaskbarAlignment::centered;
  const LONG limit = s.bounds.right - padding;
  if (h > s.bounds.bottom - s.bounds.top - 2) { result.status = Status::noSpace; return result; }
  std::vector<std::pair<LONG, LONG>> blocks;
  for (const auto& r : s.occupied) {
    if (!ValidRect(r)) return result;
    if (Overlap(r, s.bounds)) blocks.emplace_back((std::min)(limit, (std::max)(s.bounds.left, r.left - padding)),
                                                (std::min)(limit, r.right + padding));
  }
  std::sort(blocks.begin(), blocks.end());
  LONG start = s.bounds.left + padding, selected = 0, selected_width = 0; bool found = false;
  blocks.emplace_back(limit, s.bounds.right);
  for (const auto& block : blocks) {
    if (block.first - start >= minimum) {
      const LONG candidate = (std::min)(static_cast<LONG>(w), block.first - start);
      // Prefer the leftmost complete fit for centered icons. When no complete
      // fit exists choose the widest verified gap; ties stay left-stable.
      if (!found || candidate > selected_width) {
        selected_width = candidate; selected = far_left ? start : block.first - selected_width; found = true;
      }
      if (far_left && candidate == w) break;
    }
    start = (std::max)(start, block.second);
  }
  if (!found) { result.status = Status::noSpace; return result; }
  const LONG top = s.bounds.top + (s.bounds.bottom - s.bounds.top - h) / 2;
  result.rect = {selected, top, selected + selected_width, top + h}; result.status = Status::displaying;
  return result;
}
LayoutSnapshot DiscoverTaskbar(HWND bar, HWND own) {
  LayoutSnapshot result;
  result.reason = "taskbarUnavailable";
  if (!bar || !IsWindow(bar)) return result;
  if (!GetWindowRect(bar, &result.bounds)) { result.error = GetLastError(); return result; }
  DWORD taskbar_process = 0, shell_process = 0;
  GetWindowThreadProcessId(bar, &taskbar_process);
  GetWindowThreadProcessId(GetShellWindow(), &shell_process);
  result.reason = "shellProcessMismatch";
  if (shell_process == 0 || taskbar_process != shell_process) return result;
  MONITORINFO monitor{sizeof(MONITORINFO)};
  result.reason = "primaryMonitorUnavailable";
  if (!GetMonitorInfoW(MonitorFromWindow(bar, MONITOR_DEFAULTTONULL), &monitor) ||
      (monitor.dwFlags & MONITORINFOF_PRIMARY) == 0) return result;
  result.dpi = GetDpiForWindow(bar);
  RECT visible{};
  result.visible = IsWindowVisible(bar) && IntersectRect(&visible, &result.bounds, &monitor.rcMonitor) &&
      visible.bottom - visible.top >= 20 && visible.right - visible.left >= 64;
  result.reason = "taskbarHidden";
  if (!result.visible) return result;
  result.reason = "invalidTaskbarBounds";
  if (!ValidRect(result.bounds)) return result;
  const auto alignment = ReadTaskbarAlignment();
  result.alignment = alignment.value; result.alignment_reason = alignment.reason;
  if (alignment.value == TaskbarAlignment::unknown) {
    result.reason = alignment.reason; result.error = alignment.error; return result;
  }
  ComPtr<IUIAutomation> automation; ComPtr<IUIAutomationElement> root;
  result.reason = "automationUnavailable";
  HRESULT error = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&automation));
  if (FAILED(error)) { result.error = static_cast<uint32_t>(error); return result; }
  error = automation->ElementFromHandle(bar, &root);
  if (FAILED(error)) { result.error = static_cast<uint32_t>(error); return result; }
  AutomationWalk walk; walk.own = own; walk.bounds = result.bounds;
  error = automation->get_RawViewWalker(&walk.walker);
  if (FAILED(error)) { result.error = static_cast<uint32_t>(error); return result; }
  const bool traversed = walk.Visit(root.Get(), 0);
  result.nodes = walk.nodes; result.controls = walk.controls; result.ignored_own = walk.ignored_own;
  if (!traversed) { result.reason = walk.reason; result.error = static_cast<uint32_t>(walk.error); return result; }
  result.reason = "insufficientControls";
  if (walk.controls < 2) return result;
  result.occupied = std::move(walk.occupied);
  NativeWalk native{own, result.bounds, &result.occupied};
  EnumChildWindows(bar, CollectNative, reinterpret_cast<LPARAM>(&native));
  result.ignored_own += native.ignored_own;
  // Require recognizable occupied evidence on both sides. An empty provider tree
  // or a partial task list cannot turn the whole taskbar into an alleged free slot.
  bool left = false, right = false;
  LONG split = result.bounds.left + (result.bounds.right - result.bounds.left) * 3 / 4;
  for (const auto& r : result.occupied) { left |= r.left < split; right |= r.right > split; }
  RECT after{};
  result.complete = native.complete && left && right && GetWindowRect(bar, &after) && EqualRect(&after, &result.bounds);
  result.reason = !native.complete ? "nativeTraversalFailed" : !(left && right) ? "incompleteOccupiedEvidence" :
      result.complete ? "ready" : "taskbarBoundsChanged";
  return result;
}
}
