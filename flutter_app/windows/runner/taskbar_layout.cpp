#include "taskbar_layout.h"
#include <UIAutomation.h>
#include <wrl/client.h>
#include <algorithm>
#include <cmath>
#include <string>
namespace taskbar {
namespace {
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
  int nodes = 0, controls = 0;
  bool Visit(IUIAutomationElement* element, int depth) {
    if (depth > 20 || ++nodes > 512) return false;
    UIA_HWND native = nullptr;
    if (FAILED(element->get_CurrentNativeWindowHandle(&native))) return false;
    if (native == own && own) return true;
    BOOL offscreen = FALSE, control = FALSE; RECT r{}; CONTROLTYPEID type = 0;
    if (FAILED(element->get_CurrentIsOffscreen(&offscreen)) ||
        FAILED(element->get_CurrentBoundingRectangle(&r)) ||
        FAILED(element->get_CurrentIsControlElement(&control)) ||
        FAILED(element->get_CurrentControlType(&type))) return false;
    ComPtr<IUIAutomationElement> child;
    if (FAILED(walker->GetFirstChildElement(element, &child))) return false;
    const bool container = type == UIA_PaneControlTypeId || type == UIA_ToolBarControlTypeId ||
        type == UIA_GroupControlTypeId || type == UIA_ListControlTypeId || type == UIA_WindowControlTypeId;
    // A non-container control is occupied even when it has text/icon descendants.
    // Unknown visible leaf fragments are occupied too. Never infer a gap inside them.
    if (!offscreen && depth > 0 && ((!container && control) || !child)) {
      if (!ValidRect(r)) return false;
      if (Overlap(r, bounds)) { occupied.push_back(r); if (control) ++controls; }
    }
    while (child) {
      if (!Visit(child.Get(), depth + 1)) return false;
      ComPtr<IUIAutomationElement> next;
      if (FAILED(walker->GetNextSiblingElement(child.Get(), &next))) return false;
      child = std::move(next);
    }
    return true;
  }
};
struct NativeWalk { HWND own; RECT bounds; std::vector<RECT>* occupied; bool complete = true; };
BOOL CALLBACK CollectNative(HWND child, LPARAM context) {
  auto& state = *reinterpret_cast<NativeWalk*>(context);
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
LayoutResult FitFreeRegion(const LayoutSnapshot& s, int width, int height) {
  LayoutResult result;
  if (!ValidRect(s.bounds) || s.bounds.bottom - s.bounds.top > s.bounds.right - s.bounds.left) {
    result.status = Status::unsupported; return result;
  }
  if (!s.complete || !s.visible || s.occupied.empty() || s.dpi < 48 || s.dpi > 768) return result;
  if (width < 64 || width > 1600 || height < 8 || height > 128) { result.status = Status::error; return result; }
  const int w = MulDiv(width, static_cast<int>(s.dpi), 96);
  const int h = MulDiv(height, static_cast<int>(s.dpi), 96);
  const int padding = MulDiv(8, static_cast<int>(s.dpi), 96);
  if (h > s.bounds.bottom - s.bounds.top - 2) { result.status = Status::noSpace; return result; }
  std::vector<std::pair<LONG, LONG>> blocks;
  for (const auto& r : s.occupied) {
    if (!ValidRect(r)) return result;
    if (Overlap(r, s.bounds)) blocks.emplace_back((std::max)(s.bounds.left, r.left - padding),
                                                (std::min)(s.bounds.right, r.right + padding));
  }
  std::sort(blocks.begin(), blocks.end());
  LONG start = s.bounds.left + padding, selected = 0; bool found = false;
  blocks.emplace_back(s.bounds.right - padding, s.bounds.right);
  for (const auto& block : blocks) {
    if (block.first - start >= w) { selected = block.first - w; found = true; }
    start = (std::max)(start, block.second);
  }
  if (!found) { result.status = Status::noSpace; return result; }
  const LONG top = s.bounds.top + (s.bounds.bottom - s.bounds.top - h) / 2;
  result.rect = {selected, top, selected + w, top + h}; result.status = Status::displaying;
  return result;
}
LayoutSnapshot DiscoverTaskbar(HWND bar, HWND own) {
  LayoutSnapshot result;
  if (!bar || !IsWindow(bar) || !GetWindowRect(bar, &result.bounds)) return result;
  DWORD taskbar_process = 0, shell_process = 0;
  GetWindowThreadProcessId(bar, &taskbar_process);
  GetWindowThreadProcessId(GetShellWindow(), &shell_process);
  if (shell_process == 0 || taskbar_process != shell_process) return result;
  MONITORINFO monitor{sizeof(MONITORINFO)};
  if (!GetMonitorInfoW(MonitorFromWindow(bar, MONITOR_DEFAULTTONULL), &monitor) ||
      (monitor.dwFlags & MONITORINFOF_PRIMARY) == 0) return result;
  result.dpi = GetDpiForWindow(bar);
  RECT visible{};
  result.visible = IsWindowVisible(bar) && IntersectRect(&visible, &result.bounds, &monitor.rcMonitor) &&
      visible.bottom - visible.top >= 20 && visible.right - visible.left >= 64;
  if (!result.visible || !ValidRect(result.bounds)) return result;
  ComPtr<IUIAutomation> automation; ComPtr<IUIAutomationElement> root;
  if (FAILED(CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                             IID_PPV_ARGS(&automation))) ||
      FAILED(automation->ElementFromHandle(bar, &root))) return result;
  AutomationWalk walk; walk.own = own; walk.bounds = result.bounds;
  if (FAILED(automation->get_RawViewWalker(&walk.walker)) || !walk.Visit(root.Get(), 0) || walk.controls < 2) return result;
  result.occupied = std::move(walk.occupied);
  NativeWalk native{own, result.bounds, &result.occupied};
  EnumChildWindows(bar, CollectNative, reinterpret_cast<LPARAM>(&native));
  // Require recognizable occupied evidence on both sides. An empty provider tree
  // or a partial task list cannot turn the whole taskbar into an alleged free slot.
  bool left = false, right = false;
  LONG split = result.bounds.left + (result.bounds.right - result.bounds.left) * 3 / 4;
  for (const auto& r : result.occupied) { left |= r.left < split; right |= r.right > split; }
  RECT after{};
  result.complete = native.complete && left && right && GetWindowRect(bar, &after) && EqualRect(&after, &result.bounds);
  return result;
}
}
