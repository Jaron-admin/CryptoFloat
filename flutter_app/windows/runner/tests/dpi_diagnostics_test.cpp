// Uses temporary files and hidden test windows; never moves a visible window.
#include <windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <sstream>
#include <type_traits>
#include <utility>

#if __has_include("../dpi_diagnostics.h")
#include "../dpi_diagnostics.h"
#include <flutter_windows.h>

// The fixture only creates hidden windows and never needs the desktop's DPI.
UINT DiagnosticFixtureMonitorDpi(HMONITOR) { return 96; }
#define FlutterDesktopGetDpiForMonitor DiagnosticFixtureMonitorDpi
#include "../win32_window.cpp"
#undef FlutterDesktopGetDpiForMonitor

namespace {
int failures = 0;
int checks = 0;
void Expect(bool value, const char* name) {
  ++checks;
  if (!value) { ++failures; std::cerr << "FAIL: " << name << '\n'; }
}
template <typename T, typename = void>
struct HasProbeComposition : std::false_type {};
template <typename T>
struct HasProbeComposition<T, std::void_t<decltype(
    std::declval<T>().composition)>> : std::true_type {};

template <typename Options = DpiDiagnostics::Options>
void ProbeArgumentGatingTest() {
  if constexpr (!HasProbeComposition<Options>::value) {
    Expect(false, "diagnostic A/B composition is gated by explicit isolation");
  } else {
    using Mode = decltype(Options{}.composition);
    const std::vector<std::pair<const char*, Mode>> variants = {
      {"--dpi-probe-opaque-layered", Mode::kOpaqueLayered},
      {"--dpi-probe-opaque-nonlayered", Mode::kOpaqueNonLayered},
    };
    for (const auto& variant : variants) {
      for (const auto& prerequisites : std::vector<std::vector<std::string>>{
               {}, {"--dpi-diagnostics"}, {"--dpi-probe-isolated"}}) {
        auto arguments = prerequisites;
        arguments.push_back(variant.first);
        const Options options = DpiDiagnostics::ParseArguments(arguments);
        Expect(options.composition == Mode::kDefault,
               "each A/B variant requires diagnostics and isolation together");
      }
      const Options options = DpiDiagnostics::ParseArguments(
          {"--dpi-diagnostics", "--dpi-probe-isolated", variant.first});
      Expect(options.enabled && options.isolated &&
             options.composition == variant.second,
             "explicit isolated A/B variant is selected");
      const Options duplicate = DpiDiagnostics::ParseArguments(
          {variant.first, "--dpi-probe-isolated", variant.first, "--dpi-diagnostics"});
      Expect(duplicate.composition == variant.second,
             "duplicate flags and argument order do not change A/B selection");
    }
    const Options conflict = DpiDiagnostics::ParseArguments(
        {"--dpi-diagnostics", "--dpi-probe-isolated",
         "--dpi-probe-opaque-layered", "--dpi-probe-opaque-nonlayered"});
    Expect(conflict.composition == Mode::kDefault,
           "conflicting A/B variants preserve the normal composition policy");
    const Options ordinary = DpiDiagnostics::ParseArguments({});
    Expect(!ordinary.enabled && !ordinary.isolated &&
           ordinary.composition == Mode::kDefault,
           "ordinary launch keeps diagnostics and opacity overrides disabled");
    const Options isolated = DpiDiagnostics::ParseArguments(
        {"--dpi-diagnostics", "--dpi-probe-isolated"});
    Expect(isolated.composition == Mode::kDefault,
           "existing isolated diagnostic launch keeps normal composition");
  }
}
std::string Read(const std::filesystem::path& file) {
  std::ifstream input(file, std::ios::binary);
  return {std::istreambuf_iterator<char>(input), {}};
}
flutter::EncodableMap Payload() {
  using V = flutter::EncodableValue;
  return {{V("event"), V("metrics")}, {V("seq"), V(int64_t{1})},
          {V("dpr"), V(1.75)}, {V("physicalWidth"), V(980.0)},
          {V("physicalHeight"), V(551.0)}, {V("logicalWidth"), V(560.0)},
          {V("logicalHeight"), V(551.0 / 1.75)},
          {V("textScale"), V(1.0)}, {V("fontSize"), V(15.0)}};
}
size_t Occurrences(const std::string& text, const std::string& match) {
  size_t count = 0;
  for (size_t at = 0; (at = text.find(match, at)) != std::string::npos;
       at += match.size()) ++count;
  return count;
}
class DiagnosticFixtureWindow : public Win32Window {
 public:
  using Win32Window::MessageHandler;
};
LRESULT CALLBACK DiagnosticFixtureChild(HWND hwnd, UINT message,
                                        WPARAM wparam, LPARAM lparam) {
  if (message == WM_SIZE) {
    // Simulate synchronous work in the child's real resize message path.
    Sleep(5);
    SendMessageW(hwnd, WM_PAINT, 0, 0);
    SendMessageW(hwnd, WM_ERASEBKGND, 0, 0);
  }
  if (message == WM_PAINT) {
    PAINTSTRUCT paint{};
    BeginPaint(hwnd, &paint);
    EndPaint(hwnd, &paint);
    return 0;
  }
  if (message == WM_ERASEBKGND) return 1;
  return DefWindowProcW(hwnd, message, wparam, lparam);
}
void ChildResizeDiagnosticsTest(const std::filesystem::path& directory) {
  auto& sink = DpiDiagnostics::Process();
  const auto capture = directory / "child-resize";
  const auto log = capture / "dpi-diagnostics.log";
  sink.Initialize(false, capture);
  DiagnosticFixtureWindow window;
  Expect(window.Create(L"", {0, 0}, {640, 360}), "resize host created hidden");
  WNDCLASSW klass{};
  klass.lpfnWndProc = DiagnosticFixtureChild;
  klass.hInstance = GetModuleHandleW(nullptr);
  klass.lpszClassName = L"DuoMonitorDiagnosticFixtureChild";
  RegisterClassW(&klass);
  HWND child = CreateWindowExW(0, klass.lpszClassName, L"", WS_CHILD,
      0, 0, 200, 100, window.GetHandle(), nullptr, klass.hInstance, nullptr);
  Expect(child != nullptr, "resize child created");
  window.SetChildContent(child);
  window.MessageHandler(window.GetHandle(), WM_ENTERSIZEMOVE, 0, 0);
  window.MessageHandler(window.GetHandle(), WM_SIZE, 0, 0);
  SendMessageW(child, WM_PAINT, 0, 0);
  Expect(!std::filesystem::exists(capture), "disabled resize capture creates no files");

  sink.Initialize(true, capture);
  // No observation boundary yet: ordinary price repainting is not captured.
  SendMessageW(child, WM_PAINT, 0, 0);
  window.MessageHandler(window.GetHandle(), WM_SIZE, 0, 0);
  Expect(Read(log).find("\"event\":\"childResize\"") == std::string::npos,
         "resize duration is absent outside a transition");
  MoveWindow(child, 0, 0, 200, 100, FALSE);
  window.MessageHandler(window.GetHandle(), WM_ENTERSIZEMOVE, 0, 0);
  const auto before = Read(log).size();
  window.MessageHandler(window.GetHandle(), WM_SIZE, 0, 0);
  std::string observed = Read(log).substr(before);
  Expect(observed.find("\"event\":\"childResize\"") != std::string::npos,
         "transition captures synchronous child resize duration");
  Expect(observed.find("\"beforeWidth\":200") != std::string::npos &&
         observed.find("\"requestedWidth\":640") != std::string::npos &&
         observed.find("\"afterWidth\":640") != std::string::npos,
         "resize sample relates requested size to actual before and after size");
  const std::string timing_key = "\"durationMicros\":";
  const auto timing_at = observed.find(timing_key);
  Expect(timing_at != std::string::npos &&
         std::stoull(observed.substr(timing_at + timing_key.size())) >= 4000,
         "resize duration includes synchronous child work");
  Expect(observed.find("\"paintCount\":1") != std::string::npos &&
         observed.find("\"eraseCount\":1") != std::string::npos,
         "resize sample contains child paint and erase counts");
  const auto stable_log = Read(log);
  for (int i = 0; i < 100; ++i) SendMessageW(child, WM_PAINT, 0, 0);
  Expect(Read(log) == stable_log, "paint counting never writes a per-frame log");
  window.MessageHandler(window.GetHandle(), WM_SIZE, 0, 0);
  observed = Read(log).substr(stable_log.size());
  Expect(observed.find("\"beforeWidth\":640") != std::string::npos &&
         observed.find("\"requestedWidth\":640") != std::string::npos &&
         observed.find("\"paintCount\":101") != std::string::npos,
         "unchanged resize requests and intervening paints remain observable");
  for (int i = 0; i < 100; ++i) {
    window.MessageHandler(window.GetHandle(), WM_SIZE, 0, 0);
  }
  Expect(Occurrences(Read(log), "\"event\":\"childResize\"") == 16,
         "resize detail is capped at sixteen samples per transition");
  window.MessageHandler(window.GetHandle(), WM_ENTERSIZEMOVE, 0, 0);
  Sleep(2100);
  SendMessageW(child, WM_PAINT, 0, 0);
  window.MessageHandler(window.GetHandle(), WM_SIZE, 0, 0);
  Expect(Occurrences(Read(log), "\"event\":\"childResize\"") == 16,
         "resize detail stops after two seconds without scheduling anything");
  const auto click_at = Read(log).size();
  window.MessageHandler(window.GetHandle(), WM_LBUTTONDOWN, 0, 0);
  observed = Read(log).substr(click_at);
  Expect(observed.find("\"paintCount\":0") != std::string::npos &&
         observed.find("\"eraseCount\":0") != std::string::npos,
         "paint activity outside finite observation window is not counted");
  Expect(!IsWindowVisible(window.GetHandle()) && !IsWindowVisible(child),
         "all resize and painting fixtures stayed hidden");
  sink.Initialize(false, capture);
  window.Destroy();
  UnregisterClassW(klass.lpszClassName, klass.hInstance);
}
}

int main(int argc, char** argv) {
  ProbeArgumentGatingTest();
  using V = flutter::EncodableValue;
  const auto directory = (argc > 1 ? std::filesystem::path(argv[1]) :
      std::filesystem::temp_directory_path()) /
      (L"duomonitor-dpi-test-" + std::to_wstring(GetCurrentProcessId()) + L"-" +
       std::to_wstring(GetTickCount64()));
  DpiDiagnostics sink;
  Expect(!sink.enabled(), "diagnostics default to disabled");
  sink.Initialize(false, directory);
  Expect(sink.ReportDart(V(Payload())), "valid disabled report is accepted");
  Expect(!std::filesystem::exists(directory), "disabled sink does not create files");
  Expect(!DpiDiagnostics::ParseArguments({"--dpi-probe-isolated"}).isolated,
         "isolation requires diagnostics flag");
  const auto flags = DpiDiagnostics::ParseArguments(
      {"--dpi-diagnostics", "--dpi-probe-isolated"});
  Expect(flags.enabled && flags.isolated, "explicit diagnostic isolation enabled");
  sink.Initialize(true, directory);
  Expect(sink.enabled(), "explicit diagnostics enabled");
  Expect(sink.ReportDart(V(Payload())), "valid metrics accepted");
  const auto log = directory / "dpi-diagnostics.log";
  const auto first = Read(log);
  Expect(first.find("\"event\":\"metrics\"") != std::string::npos,
         "fixed event name serialized");
  Expect(first.find("\"dpr\":1.75") != std::string::npos,
         "numeric snapshot serialized");
  auto invalid = Payload();
  invalid[V("event")] = V("private-window-title");
  Expect(!sink.ReportDart(V(invalid)), "unknown event rejected");
  invalid = Payload(); invalid[V("apiKey")] = V("private-secret");
  Expect(!sink.ReportDart(V(invalid)), "unknown fields rejected");
  invalid = Payload(); invalid[V("dpr")] = V(std::numeric_limits<double>::infinity());
  Expect(!sink.ReportDart(V(invalid)), "infinity rejected");
  invalid = Payload(); invalid[V("fontSize")] = V(std::numeric_limits<double>::quiet_NaN());
  Expect(!sink.ReportDart(V(invalid)), "NaN rejected");
  invalid = Payload(); invalid[V("physicalWidth")] = V(-1.0);
  Expect(!sink.ReportDart(V(invalid)), "negative dimensions rejected");
  invalid = Payload(); invalid[V("dpr")] = V(40.0);
  Expect(!sink.ReportDart(V(invalid)), "unbounded DPI rejected");
  invalid = Payload(); invalid.erase(V("fontSize"));
  Expect(!sink.ReportDart(V(invalid)), "missing numeric field rejected");
  invalid = Payload(); invalid[V("seq")] = V(1.5);
  Expect(!sink.ReportDart(V(invalid)), "fractional sequence rejected");
  invalid = Payload(); invalid[V("buildMicros")] = V(int64_t{-1});
  Expect(!sink.ReportDart(V(invalid)), "negative optional timing rejected");
  Expect(Read(log) == first, "rejected input never reaches log");
  for (const char* event : {"postFrame", "frameTiming", "pointerDown"}) {
    auto valid = Payload(); valid[V("event")] = V(event);
    valid[V("buildMicros")] = V(int64_t{12});
    valid[V("rasterMicros")] = V(int64_t{34});
    Expect(sink.ReportDart(V(valid)), "allowed events and optional timings accepted");
  }
  auto framework = Payload();
  framework[V("mediaWidth")] = V(560.0);
  framework[V("mediaHeight")] = V(551.0 / 1.75);
  framework[V("frameBuildStartMicros")] = V(int64_t{15000000000});
  framework[V("frameRasterFinishMicros")] = V(int64_t{15000000060});
  Expect(sink.ReportDart(V(framework)), "framework metrics and frame timestamps accepted");
  framework[V("mediaWidth")] = V(std::numeric_limits<double>::infinity());
  Expect(!sink.ReportDart(V(framework)), "invalid framework dimensions rejected");
  framework = Payload();
  framework[V("frameBuildStartMicros")] = V(int64_t{-1});
  Expect(!sink.ReportDart(V(framework)), "invalid frame timestamp rejected");
  framework = Payload();
  framework[V("frameRasterFinishMicros")] = V(1.5);
  Expect(!sink.ReportDart(V(framework)), "fractional frame timestamp rejected");
  const HWND parent = CreateWindowExW(0, L"STATIC", L"", WS_POPUP,
      0, 0, 601, 301, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  const HWND child = CreateWindowExW(0, L"STATIC", L"", WS_CHILD,
      0, 0, 601, 301, parent, nullptr, GetModuleHandleW(nullptr), nullptr);
  Expect(parent && child && !IsWindowVisible(parent), "geometry fixture stays hidden");
  RECT suggested{1, 2, 903, 454};
  sink.RecordNative(DpiNativeEvent::kParentDpi, parent, child, 144, true, 2,
                    144, &suggested);
  auto contents = Read(log);
  Expect(contents.find("\"event\":\"parentDpi\"") != std::string::npos,
         "native event captured");
  Expect(contents.find("\"parentWidth\":601") != std::string::npos &&
         contents.find("\"childWidth\":601") != std::string::npos,
         "hidden parent and child geometry sampled");
  Expect(contents.find("\"messageDpi\":144") != std::string::npos &&
         contents.find("\"depth\":2") != std::string::npos,
         "message DPI and nesting are numerical");
  DpiDiagnostics nested;
  nested.Initialize(true, directory / "nested-boundary");
  nested.RecordNative(DpiNativeEvent::kEnterMove, parent, child, 96, false, 0);
  const auto sample = nested.BeginChildResize(child);
  nested.RecordNative(DpiNativeEvent::kParentDpi, parent, child, 144, false, 1);
  nested.EndChildResize(sample, child, 601, 301, true);
  const auto nested_log = Read(directory / "nested-boundary" / "dpi-diagnostics.log");
  Expect(nested_log.find("\"startedTransition\":1") != std::string::npos &&
         nested_log.find("\"renderTransition\":2") != std::string::npos,
         "resize sample identifies a nested transition without mixing its origin");
  DestroyWindow(child); DestroyWindow(parent);
  for (int i = 0; i < 1500; ++i) sink.ReportDart(V(Payload()));
  Expect(std::filesystem::file_size(log) <= 65536, "active log bounded to 64 KiB");
  Expect(std::filesystem::exists(directory / "dpi-diagnostics.log.1"),
         "single previous log retained");
  std::error_code previous_error;
  const auto previous_size = std::filesystem::file_size(
      directory / "dpi-diagnostics.log.1", previous_error);
  Expect(!previous_error && previous_size <= 65536,
         "rotated log bounded to 64 KiB");
  size_t files = 0;
  for (const auto& entry : std::filesystem::directory_iterator(directory)) {
    if (entry.is_regular_file()) ++files;
  }
  Expect(files == 2, "no additional rollover files created");
  contents = Read(log) + Read(directory / "dpi-diagnostics.log.1");
  Expect(contents.find("private-") == std::string::npos,
         "no rejected text recorded");
  ChildResizeDiagnosticsTest(directory);
  std::cout << checks << " DPI diagnostic checks, " << failures << " failures.\n";
  return failures == 0 ? 0 : 1;
}
#else
int main() {
  std::cerr << "FAIL: opt-in bounded DPI diagnostics are not implemented.\n";
  return 1;
}
#endif
