#ifndef RUNNER_DPI_DIAGNOSTICS_H_
#define RUNNER_DPI_DIAGNOSTICS_H_

#include <windows.h>
#include <flutter/encodable_value.h>

#include <filesystem>
#include <mutex>
#include <string>
#include <vector>

enum class DpiNativeEvent {
  kParentDpi, kParentSize, kEnterMove, kExitMove, kWindowPosition,
  kChildBeforeParent, kChildAfterParent, kChildSize, kMouseDown,
};

// Opt-in observational trace only. It never changes window or Flutter state.
// The only persisted strings are fixed event names; all payload values are
// validated numbers. Normal launches do not create a directory or a log.
class DpiDiagnostics {
 public:
  struct Options { bool enabled = false; bool isolated = false; };
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

 private:
  void Write(const std::string& fields);
  bool enabled_ = false;
  std::filesystem::path file_;
  std::mutex mutex_;
  uint64_t sequence_ = 0;
};

#endif  // RUNNER_DPI_DIAGNOSTICS_H_
