#ifndef RUNNER_DPI_DIAGNOSTICS_H_
#define RUNNER_DPI_DIAGNOSTICS_H_

#include <windows.h>
#include <flutter/encodable_value.h>

#include <cstdint>
#include <filesystem>
#include <iosfwd>
#include <mutex>
#include <string>
#include <vector>

enum class DpiNativeEvent {
  kParentDpi, kParentSize, kEnterMove, kExitMove, kWindowPosition,
  kChildBeforeParent, kChildAfterParent, kChildSize, kMouseDown,
};

enum class DpiProbeComposition {
  kDefault, kOpaqueLayered, kOpaqueNonLayered,
};

// Opt-in observational trace. This sink never changes window or Flutter state;
// isolated A/B options are applied separately when the native host is created.
// The only persisted strings are fixed event names; all payload values are
// validated numbers. Normal launches do not create a directory or a log.
class DpiDiagnostics {
 public:
  struct Options {
    bool enabled = false;
    bool isolated = false;
    DpiProbeComposition composition = DpiProbeComposition::kDefault;
  };
  static Options ParseArguments(const std::vector<std::string>& arguments);
  static DpiDiagnostics& Process();
  void Initialize(bool enabled, const std::filesystem::path& directory);
  void InitializeForProcess(bool enabled);
  bool enabled() const { return enabled_; }
  // Returns false for malformed/unrecognized input, including unknown keys.
  // Valid input is accepted while disabled without writing anything.
  bool ReportDart(const flutter::EncodableValue& value);
  void RecordNative(DpiNativeEvent event, HWND parent, HWND child,
                    UINT host_dpi, bool applying_bounds, unsigned depth,
                    UINT message_dpi = 0, const RECT* suggested = nullptr);
  struct ChildResizeSample {
    uint64_t started_micros = 0;
    uint64_t started_transition = 0;
    LONG before_width = 0;
    LONG before_height = 0;
  };
  // Paint events only increment counters. No timers, frame requests, or writes
  // occur here. Native transition snapshots include the bounded counts.
  void CountChildPaint(UINT message);
  ChildResizeSample BeginChildResize(HWND child);
  void EndChildResize(const ChildResizeSample& sample, HWND child,
                      LONG requested_width, LONG requested_height, bool success);

 private:
  bool ObservingChildRender() const;
  void ObserveTransition(DpiNativeEvent event);
  void AppendChildRenderCounts(std::ostream& stream) const;
  void Write(const std::string& fields);
  bool enabled_ = false;
  std::filesystem::path file_;
  std::mutex mutex_;
  uint64_t sequence_ = 0;
  // Window-thread-only observation state. Each drag/DPI boundary allows at
  // most sixteen resize details and two seconds of child paint counting.
  uint64_t render_deadline_millis_ = 0;
  uint64_t render_transition_ = 0;
  unsigned resize_samples_remaining_ = 0;
  unsigned child_paint_count_ = 0;
  unsigned child_erase_count_ = 0;
};

#endif  // RUNNER_DPI_DIAGNOSTICS_H_
