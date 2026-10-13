#ifndef RUNNER_MONITOR_CHANNEL_H_
#define RUNNER_MONITOR_CHANNEL_H_
#include <flutter/encodable_value.h>
#include "system_metrics.h"
#include "taskbar_host.h"
flutter::EncodableValue EncodeMetrics(const SystemMetricsSnapshot& snapshot);
// Decoders reject invalid input without modifying the output. A disable map may
// contain only enabled=false. Null output pointers and fractional integers fail.
bool DecodeMetricsOptions(const flutter::EncodableMap* map, SystemMetricsOptions* options);
bool DecodeTaskbarFrame(const flutter::EncodableMap* map, TaskbarFrame* frame);
#endif
