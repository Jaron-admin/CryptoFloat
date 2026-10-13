#ifndef RUNNER_SYSTEM_METRICS_H_
#define RUNNER_SYSTEM_METRICS_H_

#include <map>
#include <memory>
#include <string>
#include <vector>

struct SystemMetricsOptions {
  bool enabled = true;
  int interval_ms = 1000;
  std::string network_adapter_id = "auto";
  std::string gpu_adapter_id = "auto";
  std::string disk_id = "all";
};

struct MetricDevice { std::string id, name; };
struct SystemMetricValue {
  double value = 0;
  std::string state = "unavailable";
  std::string unit;
};
struct SystemMetricsSnapshot {
  std::map<std::string, SystemMetricValue> values;
  std::vector<MetricDevice> network_adapters, gpu_adapters, disks;
  double sampled_at_ms = 0;
  std::string network_name, gpu_name, disk_name;
};

// Construction/configuration never collects PDH data on the caller's thread.
class SystemMetrics {
 public:
  SystemMetrics();
  ~SystemMetrics();
  SystemMetrics(const SystemMetrics&) = delete;
  SystemMetrics& operator=(const SystemMetrics&) = delete;
  void Configure(const SystemMetricsOptions& options);
  SystemMetricsSnapshot Snapshot() const;
 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};
#endif
