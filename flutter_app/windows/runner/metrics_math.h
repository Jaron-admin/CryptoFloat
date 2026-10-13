#ifndef RUNNER_METRICS_MATH_H_
#define RUNNER_METRICS_MATH_H_
#include "system_metrics.h"
#include <cstdint>

namespace metrics_math {
struct CounterSample {
  std::string instance;
  double value;
  uint32_t status;
};
SystemMetricValue CounterValue(double value, uint32_t status,
                               const std::string& unit, bool warming = false);
SystemMetricValue GpuUsage(const std::vector<CounterSample>& samples,
                          const std::string& luid, bool warming = false);
SystemMetricValue GpuMemory(const std::vector<CounterSample>& samples,
                           const std::string& luid);
SystemMetricsSnapshot EmptySnapshot();
bool NeedsNewBaseline(uint64_t elapsed_ms, uint64_t active_ms, int interval_ms);
class DeltaRate {
 public:
  SystemMetricValue Update(const std::string& identity, uint64_t bytes,
                          uint64_t now_ms, uint64_t max_gap_ms);
  void Reset();
 private:
  bool initialized_ = false;
  std::string identity_;
  uint64_t bytes_ = 0, time_ms_ = 0;
};
class CpuTimesRate {
 public:
  SystemMetricValue Update(uint64_t idle, uint64_t kernel, uint64_t user,
                          uint64_t now_ms, uint64_t max_gap_ms,
                          uint32_t processor_groups, uint32_t processors);
  void Reset();
 private:
  bool initialized_ = false;
  uint64_t idle_ = 0, kernel_ = 0, user_ = 0, time_ms_ = 0;
};
}  // namespace metrics_math
#endif
