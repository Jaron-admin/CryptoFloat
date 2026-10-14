#include "monitor_channel.h"
#include "taskbar_protocol.h"
#include <cmath>

namespace {
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
using L = flutter::EncodableList;
const V* Get(const M* map, const char* key) {
  if (!map) return nullptr;
  auto it = map->find(V(key));
  return it == map->end() ? nullptr : &it->second;
}
bool Numeric(const V* value, double* out) {
  if (!value) return false;
  if (auto floating = std::get_if<double>(value)) *out = *floating;
  else if (auto integer = std::get_if<int32_t>(value)) *out = *integer;
  else if (auto wide_integer = std::get_if<int64_t>(value)) *out = static_cast<double>(*wide_integer);
  else return false;
  return std::isfinite(*out);
}
bool ReadText(const V* value, std::string* out, size_t limit = 512) {
  if (!value) return false;
  auto text = std::get_if<std::string>(value);
  if (!text || text->size() > limit || text->find('\0') != std::string::npos) return false;
  *out = *text;
  return true;
}
bool ReadWide(const V* value, std::wstring* out, size_t limit) {
  std::string text;
  if (!ReadText(value, &text, limit * 4)) return false;
  if (text.empty()) { out->clear(); return true; }
  int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (size <= 0 || static_cast<size_t>(size) > limit) return false;
  out->resize(size);
  return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), out->data(), size) == size;
}
bool ReadBool(const M* map, const char* key, bool* out) {
  const auto value = Get(map, key);
  const auto flag = value ? std::get_if<bool>(value) : nullptr;
  if (!flag) return false;
  *out = *flag;
  return true;
}
bool ReadColor(const V* value, uint32_t* out) {
  double number = 0;
  if (!Numeric(value, &number) || number < 0 || number > 4294967295.0 || std::floor(number) != number) return false;
  *out = static_cast<uint32_t>(number);
  return true;
}
L Devices(const std::vector<MetricDevice>& devices) {
  L result;
  for (const auto& device : devices) result.emplace_back(M{{V("id"), V(device.id)}, {V("name"), V(device.name)}});
  return result;
}
}

flutter::EncodableValue EncodeMetrics(const SystemMetricsSnapshot& snapshot) {
  M values;
  for (const auto& item : snapshot.values) values[V(item.first)] = V(M{
      {V("value"), std::isfinite(item.second.value) ? V(item.second.value) : V()},
      {V("unit"), V(item.second.unit)}, {V("state"), V(item.second.state)}});
  return V(M{{V("values"), V(values)}, {V("sampledAtMs"), V(snapshot.sampled_at_ms)},
    {V("networkAdapters"), V(Devices(snapshot.network_adapters))}, {V("gpuAdapters"), V(Devices(snapshot.gpu_adapters))}, {V("disks"), V(Devices(snapshot.disks))},
    {V("networkName"), V(snapshot.network_name)}, {V("gpuName"), V(snapshot.gpu_name)}, {V("diskName"), V(snapshot.disk_name)}});
}

bool DecodeMetricsOptions(const M* map, SystemMetricsOptions* output) {
  if (!output) return false;
  SystemMetricsOptions options;
  if (!ReadBool(map, "enabled", &options.enabled)) return false;
  if (!options.enabled) { *output = std::move(options); return true; }
  double interval = 0;
  if (!Numeric(Get(map, "intervalMs"), &interval) || interval < 1000 || interval > 60000 || std::floor(interval) != interval) return false;
  options.interval_ms = static_cast<int>(interval);
  if (!ReadText(Get(map, "networkAdapterId"), &options.network_adapter_id) ||
      !ReadText(Get(map, "gpuAdapterId"), &options.gpu_adapter_id) || !ReadText(Get(map, "diskId"), &options.disk_id)) return false;
  *output = std::move(options); return true;
}

bool DecodeTaskbarFrame(const M* map, TaskbarFrame* output) {
  if (!output) return false;
  TaskbarFrame frame;
  if (!ReadBool(map, "enabled", &frame.enabled)) return false;
  if (!frame.enabled) { *output = std::move(frame); return true; }
  double width = 0, lines = 0;
  if (!ReadBool(map, "chinese", &frame.chinese) || !Numeric(Get(map, "width"), &width) || width < 120 || width > 1200 || std::floor(width) != width ||
      !Numeric(Get(map, "lineCount"), &lines) || (lines != 1 && lines != 2) || !Numeric(Get(map, "fontSize"), &frame.font_size) ||
      !ReadWide(Get(map, "fontFamily"), &frame.font_family, 128) || !ReadWide(Get(map, "numberFontFamily"), &frame.number_font_family, 128) ||
      !ReadColor(Get(map, "background"), &frame.background) || !ReadColor(Get(map, "foreground"), &frame.foreground)) return false;
  frame.width = static_cast<int>(width);
  frame.line_count = static_cast<int>(lines);
  if (Get(map, "transparentBackground") && !ReadBool(map, "transparentBackground", &frame.transparent_background)) return false;
  if (Get(map, "itemGap")) {
    double gap = 0;
    if (!Numeric(Get(map, "itemGap"), &gap) || gap < 0 || gap > 24 || std::floor(gap) != gap) return false;
    frame.item_gap = static_cast<int>(gap);
  }
  if (Get(map, "labelValueGap")) {
    double gap = 0;
    if (!Numeric(Get(map, "labelValueGap"), &gap) || gap < 0 || gap > 24 || std::floor(gap) != gap) return false;
    frame.label_value_gap = static_cast<int>(gap);
  }
  if (Get(map, "overflowMode")) {
    std::string mode;
    if (!ReadText(Get(map, "overflowMode"), &mode, 8) || (mode != "auto" && mode != "manual")) return false;
    frame.auto_carousel = mode == "auto";
  }
  if (Get(map, "carouselIntervalSeconds")) {
    double interval = 0;
    if (!Numeric(Get(map, "carouselIntervalSeconds"), &interval) || interval < 2 || interval > 60 || std::floor(interval) != interval) return false;
    frame.carousel_interval_seconds = static_cast<int>(interval);
  }
  auto list_value = Get(map, "cells");
  auto cells = list_value ? std::get_if<L>(list_value) : nullptr;
  if (!cells || cells->size() > 256) return false;
  for (const auto& entry : *cells) {
    auto cell_map = std::get_if<M>(&entry);
    TaskbarCell cell;
    if (!ReadWide(Get(cell_map, "text"), &cell.text, 2048) || !ReadWide(Get(cell_map, "tooltip"), &cell.tooltip, 4096) || !ReadColor(Get(cell_map, "color"), &cell.color)) return false;
    if (Get(cell_map, "label") || Get(cell_map, "value") || Get(cell_map, "suffix") || Get(cell_map, "suffixColor")) {
      if (!ReadWide(Get(cell_map, "label"), &cell.label, 2048) || !ReadWide(Get(cell_map, "value"), &cell.value, 2048) ||
          !ReadWide(Get(cell_map, "suffix"), &cell.suffix, 2048) || !ReadColor(Get(cell_map, "suffixColor"), &cell.suffix_color)) return false;
      cell.segmented = true;
    }
    frame.cells.push_back(std::move(cell));
  }
  if (!taskbar::ValidateFrame(frame)) return false;
  *output = std::move(frame); return true;
}
