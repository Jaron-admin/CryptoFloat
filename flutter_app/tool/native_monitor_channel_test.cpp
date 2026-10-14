#include "monitor_channel.h"
#include <cstdio>
#include <limits>
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
using L = flutter::EncodableList;
int failures = 0;
void Check(bool ok, const char* name) {
  std::printf("%s %s\n", ok ? "PASS" : "FAIL", name); if (!ok) ++failures;
}
M MetricsOptions() {
  return {{V("enabled"), V(true)}, {V("intervalMs"), V(1000)},
          {V("networkAdapterId"), V("auto")}, {V("gpuAdapterId"), V("auto")}, {V("diskId"), V("all")}};
}
M Frame() {
  return {{V("enabled"), V(true)}, {V("chinese"), V(true)}, {V("width"), V(360)},
          {V("lineCount"), V(2)}, {V("fontSize"), V(11.0)}, {V("fontFamily"), V("Segoe UI")},
          {V("numberFontFamily"), V("Consolas")}, {V("background"), V(int64_t{0xFF202020})},
          {V("foreground"), V(int64_t{0xFFF3F3F3})}, {V("cells"), V(L{
              V(M{{V("text"), V("内存 — 25%")}, {V("tooltip"), V("Full text")}, {V("color"), V(int64_t{0xFFFFFFFF})}})})}};
}
int main() {
  M disabled{{V("enabled"), V(false)}};
  SystemMetricsOptions options;
  Check(DecodeMetricsOptions(&disabled, &options) && !options.enabled, "metrics disable requires only enabled=false");
  TaskbarFrame frame;
  Check(DecodeTaskbarFrame(&disabled, &frame) && !frame.enabled, "taskbar disable requires only enabled=false");
  auto settings = MetricsOptions();
  Check(DecodeMetricsOptions(&settings, &options) && options.enabled && options.interval_ms == 1000 &&
        options.network_adapter_id == "auto" && options.disk_id == "all", "metric options decode defaults and integer interval");
  settings[V("intervalMs")] = V(int64_t{60000});
  Check(DecodeMetricsOptions(&settings, &options) && options.interval_ms == 60000, "metrics upper interval boundary accepted");
  settings[V("intervalMs")] = V(1000.5);
  Check(!DecodeMetricsOptions(&settings, &options), "fractional interval rejected rather than truncated");
  settings[V("intervalMs")] = V(std::numeric_limits<double>::infinity());
  Check(!DecodeMetricsOptions(&settings, &options), "infinite interval rejected");
  settings[V("intervalMs")] = V(999);
  Check(!DecodeMetricsOptions(&settings, &options), "interval below minimum rejected");
  settings = MetricsOptions(); settings[V("networkAdapterId")] = V(std::string(513, 'x'));
  Check(!DecodeMetricsOptions(&settings, &options), "oversized device ID rejected");
  settings = MetricsOptions(); settings[V("diskId")] = V(std::string("a\0b", 3));
  Check(!DecodeMetricsOptions(&settings, &options), "embedded NUL device ID rejected");
  options.enabled = false; options.interval_ms = 5000; options.network_adapter_id = "sentinel";
  Check(!DecodeMetricsOptions(&settings, &options) && !options.enabled && options.interval_ms == 5000 &&
        options.network_adapter_id == "sentinel", "invalid options leave caller state unchanged");
  auto data = Frame();
  Check(DecodeTaskbarFrame(&data, &frame) && frame.enabled && frame.width == 360 && frame.cells.size() == 1 &&
        frame.cells[0].text == L"内存 — 25%" && frame.number_font_family == L"Consolas" &&
        frame.cells[0].color == 0xFFFFFFFF, "taskbar UTF8 text fonts and unsigned color decode");
  Check(DecodeTaskbarFrame(&data, &frame) && frame.cells.size() == 1, "reused frame replaces cells rather than accumulating them");
  data[V("transparentBackground")] = V(1);
  Check(!DecodeTaskbarFrame(&data, &frame), "integer transparency flag rejected");
  data = Frame(); data[V("itemGap")] = V(25);
  Check(!DecodeTaskbarFrame(&data, &frame), "gap above maximum rejected");
  data[V("itemGap")] = V(2.5);
  Check(!DecodeTaskbarFrame(&data, &frame), "fractional gap rejected");
  data = Frame();
  data[V("transparentBackground")] = V(false); data[V("itemGap")] = V(24);
  Check(DecodeTaskbarFrame(&data, &frame) && !frame.transparent_background && frame.item_gap == 24,
        "transparent flag and gap decode within bounds");
  data = Frame();
  Check(DecodeTaskbarFrame(&data, &frame) && frame.transparent_background && frame.item_gap == 6,
        "missing surface options use portable defaults");
  data[V("labelValueGap")] = V(24); data[V("overflowMode")] = V("manual");
  data[V("carouselIntervalSeconds")] = V(60);
  auto& segmented = std::get<M>(std::get<L>(data.at(V("cells")))[0]);
  segmented[V("label")] = V("BTC"); segmented[V("value")] = V("123");
  segmented[V("suffix")] = V("-5%"); segmented[V("suffixColor")] = V(int64_t{0xFFFF0000});
  Check(DecodeTaskbarFrame(&data, &frame) && frame.label_value_gap == 24 && !frame.auto_carousel &&
        frame.carousel_interval_seconds == 60 && frame.cells[0].segmented && frame.cells[0].label == L"BTC" &&
        frame.cells[0].suffix_color == 0xFFFF0000,
        "structured text separate suffix color and carousel preferences decode");
  segmented.erase(V("value"));
  Check(!DecodeTaskbarFrame(&data, &frame), "partial structured text is rejected");
  data = Frame(); data[V("labelValueGap")] = V(24.5);
  Check(!DecodeTaskbarFrame(&data, &frame), "fractional label value gap is rejected");
  data = Frame(); data[V("overflowMode")] = V("unknown");
  Check(!DecodeTaskbarFrame(&data, &frame), "unknown carousel mode is rejected");
  data = Frame(); data[V("carouselIntervalSeconds")] = V(1);
  Check(!DecodeTaskbarFrame(&data, &frame), "carousel interval below minimum is rejected");
  data[V("carouselIntervalSeconds")] = V(61);
  Check(!DecodeTaskbarFrame(&data, &frame), "carousel interval above maximum is rejected");
  data[V("carouselIntervalSeconds")] = V(5.5);
  Check(!DecodeTaskbarFrame(&data, &frame), "fractional carousel interval is rejected");
  data = Frame();
  data[V("width")] = V(360.5);
  Check(!DecodeTaskbarFrame(&data, &frame), "fractional width rejected rather than truncated");
  data = Frame(); data[V("fontSize")] = V(std::numeric_limits<double>::quiet_NaN());
  Check(!DecodeTaskbarFrame(&data, &frame), "NaN font rejected");
  data = Frame(); data[V("lineCount")] = V(1.5);
  Check(!DecodeTaskbarFrame(&data, &frame), "fractional row count rejected");
  data = Frame(); data[V("foreground")] = V(int64_t{-1});
  Check(!DecodeTaskbarFrame(&data, &frame), "negative color rejected");
  data[V("foreground")] = V(int64_t{4294967296});
  Check(!DecodeTaskbarFrame(&data, &frame), "color beyond uint32 rejected");
  data = Frame(); data[V("fontFamily")] = V(std::string(129, 'x'));
  Check(!DecodeTaskbarFrame(&data, &frame), "oversized font rejected");
  data = Frame(); data[V("fontFamily")] = V(std::string("\xC0\xAF", 2));
  Check(!DecodeTaskbarFrame(&data, &frame), "invalid UTF8 rejected");
  data = Frame();
  auto& cells = std::get<L>(data.at(V("cells")));
  std::get<M>(cells[0])[V("text")] = V(std::string(2049, 'x'));
  Check(!DecodeTaskbarFrame(&data, &frame), "oversized cell text rejected");
  data = Frame(); auto entry = std::get<L>(data.at(V("cells")))[0];
  data[V("cells")] = V(L(256, entry));
  Check(DecodeTaskbarFrame(&data, &frame) && frame.cells.size() == 256, "bounded 256 cell frames reach native carousel");
  data[V("cells")] = V(L(257, entry));
  Check(!DecodeTaskbarFrame(&data, &frame), "excessive cells rejected");
  frame.enabled = false; frame.width = 600; frame.cells.clear();
  data = Frame(); data[V("foreground")] = V(-1);
  Check(!DecodeTaskbarFrame(&data, &frame) && !frame.enabled && frame.width == 600 && frame.cells.empty(),
        "invalid frame leaves caller state unchanged");
  Check(!DecodeMetricsOptions(nullptr, &options) && !DecodeTaskbarFrame(nullptr, &frame), "null maps rejected");
  Check(!DecodeMetricsOptions(&disabled, nullptr) && !DecodeTaskbarFrame(&disabled, nullptr), "null outputs rejected safely");
  data = Frame(); data[V("enabled")] = V(0);
  Check(!DecodeTaskbarFrame(&data, &frame), "integer enabled flag cannot masquerade as boolean");
  data = Frame();
  auto& large_cells = std::get<L>(data.at(V("cells")));
  auto& large_cell = std::get<M>(large_cells[0]);
  large_cell[V("text")] = V(std::string(2048, 'x')); large_cell[V("tooltip")] = V(std::string(4096, 'y'));
  data[V("cells")] = V(L(32, V(large_cell)));
  Check(!DecodeTaskbarFrame(&data, &frame), "aggregate native IPC limit applies to decoded frame");
  SystemMetricsSnapshot snapshot;
  snapshot.sampled_at_ms = 12345.0; snapshot.network_name = "Ethernet"; snapshot.gpu_name = "GPU"; snapshot.disk_name = "All disks";
  snapshot.values["cpu"] = {25.5, "valid", "%"};
  snapshot.values["missing"] = {std::numeric_limits<double>::quiet_NaN(), "unavailable", "B/s"};
  snapshot.values["zero"] = {0, "valid", "B/s"};
  snapshot.network_adapters = {{"n1", "Ethernet"}}; snapshot.gpu_adapters = {{"g1", "GPU"}}; snapshot.disks = {{"d1", "Disk 1"}};
  auto encoded = EncodeMetrics(snapshot); const auto& map = std::get<M>(encoded);
  const auto& values = std::get<M>(map.at(V("values")));
  const auto& cpu = std::get<M>(values.at(V("cpu"))); const auto& missing = std::get<M>(values.at(V("missing")));
  const auto& zero = std::get<M>(values.at(V("zero")));
  Check(std::get<double>(cpu.at(V("value"))) == 25.5 && std::get<std::string>(cpu.at(V("state"))) == "valid" &&
        std::get<std::string>(cpu.at(V("unit"))) == "%", "metrics encode preserves valid value state and unit");
  Check(std::holds_alternative<std::monostate>(missing.at(V("value"))) &&
        std::get<std::string>(missing.at(V("state"))) == "unavailable", "nonfinite metric encodes null with unavailable state");
  Check(std::get<double>(zero.at(V("value"))) == 0 && std::get<std::string>(zero.at(V("state"))) == "valid",
        "valid zero metric remains zero");
  Check(std::get<double>(map.at(V("sampledAtMs"))) == 12345.0 &&
        std::get<std::string>(map.at(V("networkName"))) == "Ethernet", "snapshot timestamp and selected names encode");
  const auto& adapters = std::get<L>(map.at(V("networkAdapters")));
  Check(adapters.size() == 1 && std::get<std::string>(std::get<M>(adapters[0]).at(V("id"))) == "n1" &&
        std::get<L>(map.at(V("gpuAdapters"))).size() == 1 && std::get<L>(map.at(V("disks"))).size() == 1,
        "all device catalogs encode IDs and names");
  return failures == 0 ? 0 : 1;
}
