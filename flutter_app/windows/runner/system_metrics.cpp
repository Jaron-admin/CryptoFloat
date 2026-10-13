#include "system_metrics.h"
#include "metrics_math.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <dxgi1_2.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <wrl/client.h>
#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <set>
#include <thread>

namespace {
using metrics_math::CounterSample;
using Microsoft::WRL::ComPtr;
std::string Utf8(const wchar_t* text) {
  if (!text || !*text) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) return {};
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), size, nullptr, nullptr);
  result.pop_back();
  return result;
}
std::string GpuId(const LUID& luid) {
  char result[48];
  sprintf_s(result, "luid_0x%08lx_0x%08lx", static_cast<unsigned long>(luid.HighPart),
            static_cast<unsigned long>(luid.LowPart));
  return result;
}
std::string NetworkId(const GUID& guid) {
  char result[64];
  sprintf_s(result, "%08lx-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            guid.Data1, guid.Data2, guid.Data3, guid.Data4[0], guid.Data4[1],
            guid.Data4[2], guid.Data4[3], guid.Data4[4], guid.Data4[5],
            guid.Data4[6], guid.Data4[7]);
  return result;
}
SystemMetricValue Valid(double value, const char* unit) { return {value, "valid", unit}; }
SystemMetricValue Warming(const char* unit) { return {0, "warmingUp", unit}; }
double EpochMs() {
  return std::chrono::duration<double, std::milli>(
             std::chrono::system_clock::now().time_since_epoch()).count();
}
bool SameOptions(const SystemMetricsOptions& a, const SystemMetricsOptions& b) {
  return a.enabled == b.enabled && a.interval_ms == b.interval_ms &&
         a.network_adapter_id == b.network_adapter_id &&
         a.gpu_adapter_id == b.gpu_adapter_id && a.disk_id == b.disk_id;
}

// Wildcard handles are read with PdhGetFormattedCounterArrayW, which supports
// wildcard instances directly. English object/counter names are localized by PDH.
class PdhQuery {
 public:
  PdhQuery() { Open(); }
  ~PdhQuery() { if (query_) PdhCloseQuery(query_); }
  PdhQuery(const PdhQuery&) = delete;
  PdhQuery& operator=(const PdhQuery&) = delete;
  void Reset() {
    if (query_) PdhCloseQuery(query_);
    query_ = nullptr;
    cpu_ = engines_ = dedicated_ = shared_ = read_ = write_ = nullptr;
    primed_ = false;
    Open();
  }
  bool Collect() {
    if (!query_) Open();
    AddMissing();
    warming_ = !primed_;
    if (!query_ || PdhCollectQueryData(query_) != ERROR_SUCCESS) {
      primed_ = false;
      return false;
    }
    primed_ = true;
    return true;
  }
  bool warming() const { return warming_; }
  SystemMetricValue Cpu() const {
    if (!cpu_) return {0, "unavailable", "%"};
    if (warming_) return Warming("%");
    PDH_FMT_COUNTERVALUE value{};
    if (PdhGetFormattedCounterValue(cpu_, PDH_FMT_DOUBLE, nullptr, &value) != ERROR_SUCCESS)
      return {0, "unavailable", "%"};
    auto result = metrics_math::CounterValue(value.doubleValue, value.CStatus, "%");
    if (result.state == "valid") result.value = std::min(100.0, result.value);
    return result;
  }
  std::vector<CounterSample> Engines() const { return RateArray(engines_); }
  std::vector<CounterSample> Dedicated() const { return Array(dedicated_); }
  std::vector<CounterSample> Shared() const { return Array(shared_); }
  std::vector<CounterSample> Reads() const { return RateArray(read_); }
  std::vector<CounterSample> Writes() const { return RateArray(write_); }
 private:
  void Open() {
    if (PdhOpenQueryW(nullptr, 0, &query_) != ERROR_SUCCESS) query_ = nullptr;
    AddMissing();
  }
  void Add(const wchar_t* path, PDH_HCOUNTER* counter) {
    if (!*counter && query_ && PdhAddEnglishCounterW(query_, path, 0, counter) != ERROR_SUCCESS)
      *counter = nullptr;
  }
  void AddMissing() {
    Add(L"\\Processor Information(_Total)\\% Processor Time", &cpu_);
    Add(L"\\GPU Engine(*)\\Utilization Percentage", &engines_);
    Add(L"\\GPU Adapter Memory(*)\\Dedicated Usage", &dedicated_);
    Add(L"\\GPU Adapter Memory(*)\\Shared Usage", &shared_);
    Add(L"\\PhysicalDisk(*)\\Disk Read Bytes/sec", &read_);
    Add(L"\\PhysicalDisk(*)\\Disk Write Bytes/sec", &write_);
  }
  static std::vector<CounterSample> Array(PDH_HCOUNTER counter) {
    if (!counter) return {};
    // Instances may appear between size/read; restart sizing rather than reuse
    // the returned size from an undersized buffer (the PDH API forbids that).
    for (int attempt = 0; attempt < 3; ++attempt) {
      DWORD size = 0, count = 0;
      auto status = PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE | PDH_FMT_NOCAP100,
                                                &size, &count, nullptr);
      if (status != PDH_MORE_DATA || !size) return {};
      std::vector<unsigned char> buffer(size);
      auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buffer.data());
      status = PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE | PDH_FMT_NOCAP100,
                                            &size, &count, items);
      if (status == PDH_MORE_DATA) continue;
      if (status != ERROR_SUCCESS) return {};
      std::vector<CounterSample> result;
      result.reserve(count);
      for (DWORD i = 0; i < count; ++i)
        result.push_back({Utf8(items[i].szName), items[i].FmtValue.doubleValue,
                          items[i].FmtValue.CStatus});
      return result;
    }
    return {};
  }
  std::vector<CounterSample> RateArray(PDH_HCOUNTER counter) const {
    auto formatted = Array(counter);
    if (!formatted.empty() || !warming_ || !counter) return formatted;
    // First rate samples may not format yet. Raw instance names establish which
    // actual devices are warming; their unformatted numbers are never exposed.
    for (int attempt = 0; attempt < 3; ++attempt) {
      DWORD size = 0, count = 0;
      auto status = PdhGetRawCounterArrayW(counter, &size, &count, nullptr);
      if (status != PDH_MORE_DATA || !size) return {};
      std::vector<unsigned char> buffer(size);
      auto* items = reinterpret_cast<PDH_RAW_COUNTER_ITEM_W*>(buffer.data());
      status = PdhGetRawCounterArrayW(counter, &size, &count, items);
      if (status == PDH_MORE_DATA) continue;
      if (status != ERROR_SUCCESS) return {};
      std::vector<CounterSample> result;
      for (DWORD i = 0; i < count; ++i)
        result.push_back({Utf8(items[i].szName), 0, PDH_CSTATUS_INVALID_DATA});
      return result;
    }
    return {};
  }
  PDH_HQUERY query_ = nullptr;
  PDH_HCOUNTER cpu_ = nullptr, engines_ = nullptr, dedicated_ = nullptr,
               shared_ = nullptr, read_ = nullptr, write_ = nullptr;
  bool primed_ = false, warming_ = true;
};

struct NetworkBaseline {
  metrics_math::DeltaRate upload, download;
  uint64_t sent = 0, received = 0;
  bool initialized = false;
};
class Collector {
 public:
  explicit Collector(SystemMetricsOptions options) : options_(std::move(options)) {}
  SystemMetricsSnapshot Sample() {
    auto result = metrics_math::EmptySnapshot();
    const uint64_t tick = GetTickCount64();
    ULONGLONG active = 0;
    const bool has_active = QueryUnbiasedInterruptTime(&active) != FALSE;
    const uint64_t active_ms = active / 10000;
    if (last_tick_ && metrics_math::NeedsNewBaseline(
        tick - last_tick_, has_active && last_active_ ? active_ms - last_active_ : tick - last_tick_,
        options_.interval_ms)) {
      query_.Reset();
      cpu_fallback_.Reset();
      network_baselines_.clear();
      network_signature_.clear();
      disk_signature_.clear();
    }
    last_tick_ = tick;
    last_active_ = has_active ? active_ms : 0;
    Memory(result);
    Network(result);
    const bool collected = query_.Collect();
    if (collected) result.values["cpu.usage"] = query_.Cpu();
    const auto fallback = FallbackCpu();
    if (result.values["cpu.usage"].state != "valid" &&
        (fallback.state != "unavailable" || result.values["cpu.usage"].state != "warmingUp"))
      result.values["cpu.usage"] = fallback;
    Gpu(result, collected);
    Disk(result, collected);
    result.sampled_at_ms = EpochMs();
    return result;
  }
 private:
  SystemMetricValue FallbackCpu() {
    FILETIME idle{}, kernel{}, user{};
    if (!GetSystemTimes(&idle, &kernel, &user)) {
      cpu_fallback_.Reset();
      return {0, "unavailable", "%"};
    }
    const auto ticks = [](const FILETIME& value) {
      return (static_cast<uint64_t>(value.dwHighDateTime) << 32) | value.dwLowDateTime;
    };
    // GetSystemTimes is group scoped above 64 logical processors. A partial
    // group must never be reported as the whole machine's CPU utilization.
    return cpu_fallback_.Update(ticks(idle), ticks(kernel), ticks(user), GetTickCount64(),
        std::max<uint64_t>(5000, static_cast<uint64_t>(options_.interval_ms) * 3),
        GetActiveProcessorGroupCount(), GetActiveProcessorCount(ALL_PROCESSOR_GROUPS));
  }
  static void Memory(SystemMetricsSnapshot& result) {
    MEMORYSTATUSEX memory{};
    memory.dwLength = sizeof(memory);
    if (!GlobalMemoryStatusEx(&memory) || !memory.ullTotalPhys ||
        memory.ullAvailPhys > memory.ullTotalPhys) return;
    const double total = static_cast<double>(memory.ullTotalPhys);
    const double used = static_cast<double>(memory.ullTotalPhys - memory.ullAvailPhys);
    result.values["memory.total"] = Valid(total, "B");
    result.values["memory.used"] = Valid(used, "B");
    result.values["memory.usage"] = Valid(used * 100.0 / total, "%");
  }
  void Network(SystemMetricsSnapshot& result) {
    MIB_IF_TABLE2* table = nullptr;
    if (GetIfTable2(&table) != NO_ERROR || !table) {
      network_baselines_.clear();
      network_signature_.clear();
      return;
    }
    std::vector<MIB_IF_ROW2> selected;
    for (ULONG i = 0; i < table->NumEntries; ++i) {
      const auto& row = table->Table[i];
      const auto id = NetworkId(row.InterfaceGuid);
      const auto name = Utf8(*row.Alias ? row.Alias : row.Description);
      if (row.Type != IF_TYPE_SOFTWARE_LOOPBACK)
        result.network_adapters.push_back({id, name});
      const bool manual = options_.network_adapter_id == id;
      const bool automatic = options_.network_adapter_id == "auto" &&
          row.InterfaceAndOperStatusFlags.HardwareInterface &&
          !row.InterfaceAndOperStatusFlags.FilterInterface &&
          (row.Type == IF_TYPE_ETHERNET_CSMACD || row.Type == IF_TYPE_IEEE80211 ||
           row.Type == IF_TYPE_WWANPP || row.Type == IF_TYPE_WWANPP2);
      if ((manual || automatic) && row.OperStatus == IfOperStatusUp &&
          row.MediaConnectState != MediaConnectStateDisconnected) selected.push_back(row);
    }
    FreeMibTable(table);
    std::sort(selected.begin(), selected.end(), [](const MIB_IF_ROW2& a, const MIB_IF_ROW2& b) {
      return NetworkId(a.InterfaceGuid) < NetworkId(b.InterfaceGuid);
    });
    std::string signature;
    for (const auto& row : selected) signature += NetworkId(row.InterfaceGuid) + ";";
    if (signature != network_signature_) network_baselines_.clear();
    network_signature_ = signature;
    if (selected.empty()) return;
    const auto now = GetTickCount64();
    const auto max_gap = std::max<uint64_t>(5000, static_cast<uint64_t>(options_.interval_ms) * 3);
    double upload = 0, download = 0;
    bool warming = false;
    for (const auto& row : selected) {
      const auto id = NetworkId(row.InterfaceGuid);
      auto& baseline = network_baselines_[id];
      if (baseline.initialized && (row.OutOctets < baseline.sent || row.InOctets < baseline.received)) {
        baseline.upload.Reset();
        baseline.download.Reset();
      }
      const auto up = baseline.upload.Update(id, row.OutOctets, now, max_gap);
      const auto down = baseline.download.Update(id, row.InOctets, now, max_gap);
      baseline.sent = row.OutOctets;
      baseline.received = row.InOctets;
      baseline.initialized = true;
      warming = warming || up.state != "valid" || down.state != "valid";
      upload += up.value;
      download += down.value;
      if (!result.network_name.empty()) result.network_name += " + ";
      result.network_name += Utf8(*row.Alias ? row.Alias : row.Description);
    }
    result.values["network.upload"] = warming ? Warming("B/s") : Valid(upload, "B/s");
    result.values["network.download"] = warming ? Warming("B/s") : Valid(download, "B/s");
  }
  void Gpu(SystemMetricsSnapshot& result, bool collected) {
    ComPtr<IDXGIFactory1> factory;
    if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) { last_gpu_.clear(); return; }
    struct Adapter { std::string id; DXGI_ADAPTER_DESC1 desc; };
    std::vector<Adapter> adapters;
    for (UINT index = 0;; ++index) {
      ComPtr<IDXGIAdapter1> adapter;
      const auto status = factory->EnumAdapters1(index, &adapter);
      if (status == DXGI_ERROR_NOT_FOUND) break;
      if (FAILED(status)) { last_gpu_.clear(); return; }
      DXGI_ADAPTER_DESC1 description{};
      if (FAILED(adapter->GetDesc1(&description)) || (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)) continue;
      const auto id = GpuId(description.AdapterLuid);
      result.gpu_adapters.push_back({id, Utf8(description.Description)});
      adapters.push_back({id, description});
    }
    if (adapters.empty()) { auto_gpu_.clear(); last_gpu_.clear(); return; }
    std::string chosen = options_.gpu_adapter_id;
    if (chosen == "auto") {
      const bool found = std::any_of(adapters.begin(), adapters.end(), [&](const Adapter& a) { return a.id == auto_gpu_; });
      if (!found) auto_gpu_ = adapters.front().id;
      chosen = auto_gpu_;
    }
    const auto adapter = std::find_if(adapters.begin(), adapters.end(), [&](const Adapter& a) { return a.id == chosen; });
    if (adapter == adapters.end()) { last_gpu_.clear(); return; }
    result.gpu_name = Utf8(adapter->desc.Description);
    const auto dedicated = adapter->desc.DedicatedVideoMemory + adapter->desc.DedicatedSystemMemory;
    if (dedicated) result.values["gpu.memory.total"] = Valid(static_cast<double>(dedicated), "B");
    if (adapter->desc.SharedSystemMemory)
      result.values["gpu.shared.total"] = Valid(static_cast<double>(adapter->desc.SharedSystemMemory), "B");
    if (!collected) return;
    result.values["gpu.usage"] = metrics_math::GpuUsage(
        query_.Engines(), chosen, query_.warming() || last_gpu_ != chosen);
    result.values["gpu.memory.used"] = metrics_math::GpuMemory(query_.Dedicated(), chosen);
    result.values["gpu.shared.used"] = metrics_math::GpuMemory(query_.Shared(), chosen);
    last_gpu_ = chosen;
  }
  void Disk(SystemMetricsSnapshot& result, bool collected) {
    if (!collected) return;
    const auto reads = query_.Reads(), writes = query_.Writes();
    std::set<std::string> instances;
    for (const auto& item : reads) instances.insert(item.instance);
    for (const auto& item : writes) instances.insert(item.instance);
    std::string chosen, signature;
    for (const auto& instance : instances) {
      if (instance == "_Total") {
        if (options_.disk_id == "all") chosen = instance;
        continue;
      }
      const auto id = instance.substr(0, instance.find(' '));
      result.disks.push_back({id, instance});
      signature += instance + ";";
      if (options_.disk_id == id) chosen = instance;
    }
    if (chosen.empty()) return;
    result.disk_name = chosen == "_Total" ? "All physical disks" : chosen;
    const bool warming = query_.warming() || signature != disk_signature_;
    disk_signature_ = signature;
    const auto set = [&](const std::vector<CounterSample>& samples, const char* id) {
      const auto selected = std::find_if(samples.begin(), samples.end(), [&](const CounterSample& value) {
        return value.instance == chosen;
      });
      if (selected == samples.end()) return;
      result.values[id] = warming ? Warming("B/s") :
          metrics_math::CounterValue(selected->value, selected->status, "B/s");
    };
    set(reads, "disk.read");
    set(writes, "disk.write");
  }
  SystemMetricsOptions options_;
  PdhQuery query_;
  metrics_math::CpuTimesRate cpu_fallback_;
  std::map<std::string, NetworkBaseline> network_baselines_;
  std::string network_signature_, disk_signature_, auto_gpu_, last_gpu_;
  uint64_t last_tick_ = 0, last_active_ = 0;
};
}  // namespace

class SystemMetrics::Impl {
 public:
  Impl() : cache_(metrics_math::EmptySnapshot()), worker_([this] { Run(); }) {}
  ~Impl() {
    { std::lock_guard<std::mutex> lock(mutex_); stopping_ = true; }
    changed_.notify_all();
    worker_.join();
  }
  void Configure(SystemMetricsOptions options) {
    options.interval_ms = std::clamp(options.interval_ms, 1000, 60000);
    if (options.network_adapter_id.empty()) options.network_adapter_id = "auto";
    if (options.gpu_adapter_id.empty()) options.gpu_adapter_id = "auto";
    if (options.disk_id.empty()) options.disk_id = "all";
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (SameOptions(options, options_)) return;
      options_ = std::move(options);
      ++generation_;
      auto fresh = metrics_math::EmptySnapshot();
      fresh.network_adapters = cache_.network_adapters;
      fresh.gpu_adapters = cache_.gpu_adapters;
      fresh.disks = cache_.disks;
      cache_ = std::move(fresh);
    }
    changed_.notify_all();
  }
  SystemMetricsSnapshot Snapshot() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return cache_;
  }
 private:
  void Run() {
    std::unique_ptr<Collector> collector;
    uint64_t active_generation = UINT64_MAX;
    std::unique_lock<std::mutex> lock(mutex_);
    while (!stopping_) {
      if (!options_.enabled) {
        lock.unlock();
        collector.reset();
        lock.lock();
        changed_.wait(lock, [&] { return stopping_ || options_.enabled; });
        continue;
      }
      const auto generation = generation_;
      const auto options = options_;
      lock.unlock();
      if (!collector || active_generation != generation) {
        collector = std::make_unique<Collector>(options);
        active_generation = generation;
      }
      auto sample = collector->Sample();
      lock.lock();
      if (generation == generation_ && options_.enabled && !stopping_) cache_ = std::move(sample);
      changed_.wait_for(lock, std::chrono::milliseconds(options.interval_ms), [&] {
        return stopping_ || generation != generation_;
      });
    }
    lock.unlock();
    collector.reset();
  }
  mutable std::mutex mutex_;
  std::condition_variable changed_;
  bool stopping_ = false;
  uint64_t generation_ = 0;
  SystemMetricsOptions options_;
  SystemMetricsSnapshot cache_;
  std::thread worker_;
};

SystemMetrics::SystemMetrics() : impl_(std::make_unique<Impl>()) {}
SystemMetrics::~SystemMetrics() = default;
void SystemMetrics::Configure(const SystemMetricsOptions& options) { impl_->Configure(options); }
SystemMetricsSnapshot SystemMetrics::Snapshot() const { return impl_->Snapshot(); }
