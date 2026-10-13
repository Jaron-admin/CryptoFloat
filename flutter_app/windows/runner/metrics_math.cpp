#include "metrics_math.h"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <regex>
#include <set>
namespace metrics_math {
namespace {
std::string Lower(std::string text) {
  std::transform(text.begin(), text.end(), text.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return text;
}
}
SystemMetricValue CounterValue(double value, uint32_t status,
                               const std::string& unit, bool warming) {
  if (status != 0 && status != 1) return {0, "unavailable", unit};
  if (!std::isfinite(value) || value < 0) return {0, "unavailable", unit};
  if (warming) return {0, "warmingUp", unit};
  return {value, "valid", unit};
}
SystemMetricValue GpuUsage(const std::vector<CounterSample>& samples,
                          const std::string& luid, bool warming) {
  static const std::regex pattern(
      "^pid_[0-9]+_(luid_0x[0-9a-f]{8}_0x[0-9a-f]{8})_phys_([0-9]+)_eng_([0-9]+)_engtype_.+$");
  std::map<std::string, double> engines;
  for (const auto& sample : samples) {
    const auto instance = Lower(sample.instance);
    std::smatch match;
    if (!std::regex_match(instance, match, pattern) || match[1] != Lower(luid)) continue;
    if (warming) return {0, "warmingUp", "%"};
    if (CounterValue(sample.value, sample.status, "%").state != "valid")
      return {0, "unavailable", "%"};
    engines[match[2].str() + ":" + match[3].str()] += sample.value;
  }
  if (engines.empty()) return {0, "unavailable", "%"};
  double busiest = 0;
  for (const auto& engine : engines) busiest = std::max(busiest, engine.second);
  return {std::min(100.0, busiest), "valid", "%"};
}
SystemMetricValue GpuMemory(const std::vector<CounterSample>& samples,
                           const std::string& luid) {
  static const std::regex pattern(
      "^(luid_0x[0-9a-f]{8}_0x[0-9a-f]{8})_phys_([0-9]+)(#[0-9]+)?$");
  std::set<std::string> nodes;
  double total = 0;
  for (const auto& sample : samples) {
    const auto instance = Lower(sample.instance);
    std::smatch match;
    if (!std::regex_match(instance, match, pattern) || match[1] != Lower(luid)) continue;
    if (CounterValue(sample.value, sample.status, "B").state != "valid" ||
        !nodes.insert(match[2]).second) return {0, "unavailable", "B"};
    total += sample.value;
  }
  if (nodes.empty() || !std::isfinite(total)) return {0, "unavailable", "B"};
  return {total, "valid", "B"};
}
SystemMetricsSnapshot EmptySnapshot() {
  SystemMetricsSnapshot result;
  for (const auto* id : {"cpu.usage", "memory.usage", "gpu.usage"})
    result.values[id] = {0, "unavailable", "%"};
  for (const auto* id : {"memory.used", "memory.total", "gpu.memory.used",
                         "gpu.memory.total", "gpu.shared.used", "gpu.shared.total"})
    result.values[id] = {0, "unavailable", "B"};
  for (const auto* id : {"network.upload", "network.download", "disk.read", "disk.write"})
    result.values[id] = {0, "unavailable", "B/s"};
  return result;
}
bool NeedsNewBaseline(uint64_t elapsed_ms, uint64_t active_ms, int interval_ms) {
  return elapsed_ms > std::max<uint64_t>(5000, static_cast<uint64_t>(interval_ms) * 3) ||
         (elapsed_ms > active_ms && elapsed_ms - active_ms > 500);
}
SystemMetricValue DeltaRate::Update(const std::string& identity, uint64_t bytes,
                                   uint64_t now_ms, uint64_t max_gap_ms) {
  SystemMetricValue result{0, "warmingUp", "B/s"};
  if (initialized_ && identity == identity_ && bytes >= bytes_ &&
      now_ms > time_ms_ && now_ms - time_ms_ <= max_gap_ms)
    result = {static_cast<double>(bytes - bytes_) * 1000.0 /
                  static_cast<double>(now_ms - time_ms_), "valid", "B/s"};
  identity_ = identity;
  bytes_ = bytes;
  time_ms_ = now_ms;
  initialized_ = true;
  return result;
}
void DeltaRate::Reset() { initialized_ = false; }
SystemMetricValue CpuTimesRate::Update(uint64_t idle, uint64_t kernel, uint64_t user,
                                     uint64_t now_ms, uint64_t max_gap_ms,
                                     uint32_t processor_groups, uint32_t processors) {
  if (processor_groups != 1 || processors == 0 || processors > 64 || idle > kernel) {
    Reset();
    return {0, "unavailable", "%"};
  }
  SystemMetricValue result{0, "warmingUp", "%"};
  if (initialized_ && idle >= idle_ && kernel >= kernel_ && user >= user_ &&
      now_ms > time_ms_ && now_ms - time_ms_ <= max_gap_ms) {
    const auto idle_delta = idle - idle_;
    const auto kernel_delta = kernel - kernel_;
    const auto user_delta = user - user_;
    const double total = static_cast<double>(kernel_delta) + static_cast<double>(user_delta);
    if (idle_delta > kernel_delta) {
      Reset();
      return {0, "unavailable", "%"};
    }
    if (total > 0)
      result = {(total - static_cast<double>(idle_delta)) * 100.0 / total, "valid", "%"};
  }
  idle_ = idle;
  kernel_ = kernel;
  user_ = user;
  time_ms_ = now_ms;
  initialized_ = true;
  return result;
}
void CpuTimesRate::Reset() { initialized_ = false; }
}
