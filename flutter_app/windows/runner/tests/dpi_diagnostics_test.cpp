// Uses temporary files and hidden test windows; never moves a visible window.
#include <windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <sstream>

#if __has_include("../dpi_diagnostics.h")
#include "../dpi_diagnostics.h"

namespace {
int failures = 0;
int checks = 0;
void Expect(bool value, const char* name) {
  ++checks;
  if (!value) { ++failures; std::cerr << "FAIL: " << name << '\n'; }
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
}

int main(int argc, char** argv) {
  using V = flutter::EncodableValue;
  const auto directory = (argc > 1 ? std::filesystem::path(argv[1]) :
      std::filesystem::temp_directory_path()) /
      (L"metricperch-dpi-test-" + std::to_wstring(GetCurrentProcessId()) + L"-" +
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
  std::cout << checks << " DPI diagnostic checks, " << failures << " failures.\n";
  return failures == 0 ? 0 : 1;
}
#else
int main() {
  std::cerr << "FAIL: opt-in bounded DPI diagnostics are not implemented.\n";
  return 1;
}
#endif
