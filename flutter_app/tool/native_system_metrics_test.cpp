#include "metrics_math.h"
#include <cmath>
#include <iostream>
#include <limits>
#include <string>
#ifdef NATIVE_METRICS_LIFECYCLE_TEST
#include <windows.h>
#include <pdh.h>
#include <atomic>
#include <chrono>
#include <thread>
#endif

namespace {
int failures = 0;
void Check(bool condition, const char* name) {
  if (!condition) { ++failures; std::cerr << "FAIL: " << name << '\n'; }
}
void Value(const SystemMetricValue& actual, const char* state, double value,
           const char* name) {
  Check(actual.state == state && std::abs(actual.value - value) < .001, name);
}
}
int main() {
  using namespace metrics_math;
  DeltaRate rate;
  Value(rate.Update("nic-a", 1000, 1000, 5000), "warmingUp", 0, "rate requires a baseline");
  Value(rate.Update("nic-a", 1600, 3000, 5000), "valid", 300, "rate uses monotonic elapsed seconds");
  Value(rate.Update("nic-a", 1600, 4000, 5000), "valid", 0, "zero traffic is a valid zero");
  Value(rate.Update("nic-a", 10, 5000, 5000), "warmingUp", 0, "counter rollback rebaselines");
  Value(rate.Update("nic-a", 110, 6000, 5000), "valid", 100, "rollback recovery uses the new baseline");
  Value(rate.Update("nic-b", 900000, 7000, 5000), "warmingUp", 0, "adapter replacement rebaselines");
  Value(rate.Update("nic-b", 900200, 17000, 5000), "warmingUp", 0, "long gap rebaselines");
  Value(rate.Update("nic-b", 900250, 17000, 5000), "warmingUp", 0, "non advancing clock rebaselines");
  rate.Reset();
  Value(rate.Update("nic-b", 900300, 18000, 5000), "warmingUp", 0, "explicit reset removes baseline");
  CpuTimesRate cpu;
  Value(cpu.Update(80, 100, 50, 1000, 5000, 1, 16), "warmingUp", 0, "CPU fallback requires two time samples");
  Value(cpu.Update(200, 300, 150, 2000, 5000, 1, 16), "valid", 60, "CPU fallback counts kernel including idle exactly once");
  Value(cpu.Update(300, 400, 150, 3000, 5000, 1, 16), "valid", 0, "fully idle fallback is valid zero");
  Value(cpu.Update(0, 20, 10, 4000, 5000, 1, 16), "warmingUp", 0, "CPU time rollback rebaselines");
  Value(cpu.Update(10, 50, 30, 5000, 5000, 1, 16), "valid", 80, "CPU rollback recovers from fresh times");
  Value(cpu.Update(20, 100, 80, 15000, 5000, 1, 16), "warmingUp", 0, "CPU delayed interval rebaselines");
  Value(cpu.Update(30, 150, 100, 16000, 5000, 2, 128), "unavailable", 0, "fallback rejects multiple processor groups");
  Value(cpu.Update(30, 150, 100, 16000, 5000, 1, 128), "unavailable", 0, "fallback rejects more than 64 processors");
  Value(cpu.Update(30, 150, 100, 16000, 5000, 1, 16), "warmingUp", 0, "unsupported CPU fallback cannot retain a baseline");
  Value(cpu.Update(900, 200, 150, 17000, 5000, 1, 16), "unavailable", 0, "idle exceeding kernel is unavailable");
  cpu.Reset();
  Value(cpu.Update(20, 100, 100, 18000, 5000, 1, 16), "warmingUp", 0, "CPU reset after wake requires baseline");
  Value(CounterValue(0, 0, "%"), "valid", 0, "valid PDH zero is preserved");
  Value(CounterValue(40, 1, "%"), "valid", 40, "PDH new data is valid");
  Value(CounterValue(40, 0xc0000bc6, "%"), "unavailable", 0, "invalid CStatus does not leak numeric value");
  Value(CounterValue(std::numeric_limits<double>::quiet_NaN(), 0, "%"), "unavailable", 0, "NaN is unavailable");
  Value(CounterValue(-1, 0, "B"), "unavailable", 0, "negative bytes are unavailable");
  Value(CounterValue(40, 0, "%", true), "warmingUp", 0, "first PDH rate is warming");
  const std::string gpu = "luid_0x00000000_0x00001234";
  std::vector<CounterSample> engines = {
    {"pid_1_" + gpu + "_phys_0_eng_0_engtype_3D", 35, 0},
    {"pid_2_" + gpu + "_phys_0_eng_0_engtype_3D", 25, 1},
    {"pid_1_" + gpu + "_phys_0_eng_1_engtype_Copy", 50, 0},
    {"pid_3_" + gpu + "_phys_1_eng_0_engtype_3D", 55, 0},
    {"pid_4_luid_0x00000000_0x00009999_phys_0_eng_0_engtype_3D", 100, 0}};
  Value(GpuUsage(engines, gpu), "valid", 60, "GPU sums processes per node/engine then chooses maximum");
  Value(GpuUsage(engines, gpu, true), "warmingUp", 0, "GPU first rate is warming");
  engines[0].status = 0xc0000bc6;
  Value(GpuUsage(engines, gpu), "unavailable", 0, "invalid selected GPU engine prevents partial total");
  Value(GpuUsage(engines, gpu, true), "warmingUp", 0, "first GPU engine rate establishes baseline despite invalid initial formatted status");
  Value(GpuUsage({}, gpu), "unavailable", 0, "absent GPU engine is unavailable");
  Value(GpuUsage({{"bad_" + gpu, 100, 0}}, gpu), "unavailable", 0, "malformed GPU engine is ignored");
  Value(GpuUsage({{"pid_1_" + gpu + "_phys_0_eng_0_engtype_3D", 110, 0}}, gpu), "valid", 100, "GPU utilization is bounded");
  Value(GpuMemory({{gpu + "_phys_0", 2048, 0}, {gpu + "_phys_1", 1024, 0}}, gpu), "valid", 3072, "GPU adapter memory adds physical nodes once");
  Value(GpuMemory({{gpu + "_phys_0", 2048, 0xc0000bc6}}, gpu), "unavailable", 0, "invalid GPU memory is unavailable");
  Value(GpuMemory({{"pid_1_" + gpu + "_phys_0", 2048, 0}}, gpu), "unavailable", 0, "process memory cannot masquerade as adapter memory");
  auto empty = EmptySnapshot();
  Check(empty.values.size() == 13, "all 13 metrics exist even when unavailable");
  for (const auto& item : empty.values) Check(item.second.state == "unavailable", "empty metrics explicitly unavailable");
  Check(NeedsNewBaseline(2000, 1000, 1000), "sleep elapsed time rebaselines");
  Check(NeedsNewBaseline(10000, 10000, 1000), "delayed worker rebaselines");
  Check(!NeedsNewBaseline(60000, 60000, 60000), "normal 60 second interval does not rebaseline");
#ifdef NATIVE_METRICS_LIFECYCLE_TEST
  {
    SystemMetrics sampler;
    SystemMetricsOptions options;
    options.enabled = false;
    sampler.Configure(options);
    auto disabled = sampler.Snapshot();
    Check(disabled.values.size() == 13, "disabled sampler keeps complete unavailable metric catalog");
    for (const auto& item : disabled.values)
      Check(item.second.state == "unavailable", "disable invalidates prior readings immediately");
    options.enabled = true;
    options.network_adapter_id = "not-a-real-network-adapter";
    options.gpu_adapter_id = "not-a-real-gpu-adapter";
    options.disk_id = "not-a-real-physical-disk";
    sampler.Configure(options);
    SystemMetricsSnapshot sampled;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(8);
    while (std::chrono::steady_clock::now() < deadline) {
      sampled = sampler.Snapshot();
      if (sampled.sampled_at_ms > 0) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    Check(sampled.sampled_at_ms > 0, "background collector publishes epoch sample timestamp");
    Check(sampled.values["memory.total"].state == "valid" &&
          sampled.values["memory.total"].value > 0, "real Win32 memory sample is available");
    Check(sampled.values["network.download"].state == "unavailable", "missing selected NIC never becomes zero");
    Check(sampled.values["gpu.usage"].state == "unavailable", "missing selected GPU never becomes zero");
    Check(sampled.values["disk.read"].state == "unavailable", "missing selected disk never becomes zero");
    FILETIME idle{}, kernel{}, user{};
    const bool supports_cpu_fallback = GetActiveProcessorGroupCount() == 1 &&
        GetActiveProcessorCount(ALL_PROCESSOR_GROUPS) <= 64 && GetSystemTimes(&idle, &kernel, &user);
    if (supports_cpu_fallback)
      Check(sampled.values["cpu.usage"].state == "warmingUp", "first native CPU sample is warming");
    options.network_adapter_id = "auto";
    options.gpu_adapter_id = "auto";
    options.disk_id = "all";
    sampler.Configure(options);
    const auto live_deadline = std::chrono::steady_clock::now() + std::chrono::seconds(8);
    double first_timestamp = 0;
    while (std::chrono::steady_clock::now() < live_deadline) {
      sampled = sampler.Snapshot();
      if (sampled.sampled_at_ms > 0 && first_timestamp == 0) first_timestamp = sampled.sampled_at_ms;
      if (first_timestamp > 0 && sampled.sampled_at_ms > first_timestamp) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    Check(first_timestamp > 0 && sampled.sampled_at_ms > first_timestamp,
          "background sampler publishes a second automatic-device sample");
    if (supports_cpu_fallback)
      Check(sampled.values["cpu.usage"].state == "valid", "CPU remains available on supported machine when PDH is unavailable");
    for (const auto& item : sampled.values) {
      Check(item.second.state == "valid" || item.second.state == "warmingUp" ||
            item.second.state == "unavailable", "sample state stays inside the interface contract");
      Check(std::isfinite(item.second.value) && item.second.value >= 0,
            "background sampling never publishes NaN or negative metrics");
      std::cout << "SAMPLE " << item.first << ": " << item.second.state << '\n';
    }
    if (sampled.values["cpu.usage"].state == "unavailable") {
      PDH_HQUERY query = nullptr;
      PDH_HCOUNTER counter = nullptr;
      const auto opened = PdhOpenQueryW(nullptr, 0, &query);
      const auto added = query ? PdhAddEnglishCounterW(query,
          L"\\Processor Information(_Total)\\% Processor Time", 0, &counter) : opened;
      const auto first = query ? PdhCollectQueryData(query) : opened;
      std::this_thread::sleep_for(std::chrono::milliseconds(1100));
      const auto second = query ? PdhCollectQueryData(query) : opened;
      PDH_FMT_COUNTERVALUE formatted{};
      const auto read = counter ? PdhGetFormattedCounterValue(counter, PDH_FMT_DOUBLE,
          nullptr, &formatted) : added;
      std::cout << "PDH CPU availability probe (hex): open=" << std::hex << opened
                << " add=" << added << " first=" << first << " second=" << second
                << " format=" << read << " CStatus=" << formatted.CStatus << std::dec << '\n';
      if (query) PdhCloseQuery(query);
    }
    std::atomic<bool> stop{false};
    std::thread reader([&] {
      while (!stop.load()) {
        const auto view = sampler.Snapshot();
        if (view.values.size() != 13) ++failures;
      }
    });
    const auto configure_start = std::chrono::steady_clock::now();
    for (int i = 0; i < 50; ++i) {
      options.enabled = (i % 2 == 0);
      sampler.Configure(options);
    }
    stop = true;
    reader.join();
    Check(std::chrono::steady_clock::now() - configure_start < std::chrono::seconds(2),
          "configure and snapshot never wait for PDH collection");
    options.enabled = false;
    sampler.Configure(options);
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    const auto final = sampler.Snapshot();
    for (const auto& item : final.values)
      Check(item.second.state == "unavailable", "obsolete collection cannot overwrite disabled cache");
  }
  if (!failures) std::cout << "PASS: isolated native sampler lifecycle and Win32 API checks\n";
#endif
  if (failures) return 1;
  std::cout << "PASS: deterministic system metrics behavior checks\n";
  return 0;
}
