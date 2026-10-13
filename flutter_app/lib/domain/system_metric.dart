class MetricReading {
  const MetricReading(this.value, this.unit, this.state);
  final double? value;
  final String unit, state;
  bool get valid =>
      state == 'valid' &&
      value != null &&
      value!.isFinite &&
      value! >= 0 &&
      (unit != '%' || value! <= 100);

  factory MetricReading.fromJson(Map<Object?, Object?> data) => MetricReading(
    data['value'] is num ? (data['value'] as num).toDouble() : null,
    data['unit'] is String ? data['unit'] as String : '',
    data['state'] is String ? data['state'] as String : 'unavailable',
  );
}

class MetricText {
  const MetricText(this.value, this.unit);
  final String value, unit;
  String get text =>
      unit.isEmpty ? value : '$value${unit == '%' ? '' : ' '}$unit';
}

MetricText formatSystemMetric(String id, MetricReading? reading) {
  if (reading == null || !reading.valid) return const MetricText('—', '');
  final value = reading.value!;
  if (reading.unit == '%') return MetricText(value.toStringAsFixed(1), '%');
  if (reading.unit == 'B' || reading.unit == 'B/s') {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var scaled = value;
    var index = 0;
    while (scaled >= 1024 && index < units.length - 1) {
      scaled /= 1024;
      index++;
    }
    return MetricText(
      scaled.toStringAsFixed(index == 0 ? 0 : 1),
      '${units[index]}${reading.unit == 'B/s' ? '/s' : ''}',
    );
  }
  return MetricText(value.toStringAsFixed(1), reading.unit);
}

class MetricDefinition {
  const MetricDefinition(this.id, this.zh, this.en, this.shortLabel, this.unit);
  final String id, zh, en, shortLabel, unit;
  String name(bool chinese) => chinese ? zh : en;
}

const systemMetricCatalog = [
  MetricDefinition('cpu.usage', 'CPU 占用', 'CPU usage', 'CPU', '%'),
  MetricDefinition('memory.usage', '内存占用', 'Memory usage', 'RAM', '%'),
  MetricDefinition('memory.used', '已用内存', 'Memory used', 'RAM', 'B'),
  MetricDefinition('memory.total', '总内存', 'Total memory', 'RAM ∑', 'B'),
  MetricDefinition('network.upload', '上传速度', 'Upload speed', '↑', 'B/s'),
  MetricDefinition('network.download', '下载速度', 'Download speed', '↓', 'B/s'),
  MetricDefinition('gpu.usage', 'GPU 占用', 'GPU usage', 'GPU', '%'),
  MetricDefinition(
    'gpu.memory.used',
    '已用专用显存',
    'Dedicated GPU memory used',
    'VRAM',
    'B',
  ),
  MetricDefinition(
    'gpu.memory.total',
    '专用显存总量',
    'Dedicated GPU memory total',
    'VRAM ∑',
    'B',
  ),
  MetricDefinition(
    'gpu.shared.used',
    '已用共享显存',
    'Shared GPU memory used',
    'Shared',
    'B',
  ),
  MetricDefinition(
    'gpu.shared.total',
    '共享显存上限',
    'Shared GPU memory limit',
    'Shared ∑',
    'B',
  ),
  MetricDefinition('disk.read', '磁盘读取', 'Disk read', 'Read', 'B/s'),
  MetricDefinition('disk.write', '磁盘写入', 'Disk write', 'Write', 'B/s'),
];

class MetricDevice {
  const MetricDevice(this.id, this.name);
  final String id, name;
}

class SystemMetricSnapshot {
  const SystemMetricSnapshot({
    this.values = const {},
    this.networkAdapters = const [],
    this.gpuAdapters = const [],
    this.disks = const [],
    this.sampledAt,
    this.networkName = '',
    this.gpuName = '',
    this.diskName = '',
  });
  final Map<String, MetricReading> values;
  final List<MetricDevice> networkAdapters, gpuAdapters, disks;
  final DateTime? sampledAt;
  final String networkName, gpuName, diskName;

  factory SystemMetricSnapshot.fromJson(Map<Object?, Object?> data) {
    List<MetricDevice> devices(Object? input) => input is List
        ? [
            for (final item in input.whereType<Map>())
              if (item['id'] is String && item['name'] is String)
                MetricDevice(item['id'] as String, item['name'] as String),
          ]
        : const [];
    final timestamp = data['sampledAtMs'];
    return SystemMetricSnapshot(
      values: Map.unmodifiable({
        if (data['values'] is Map)
          for (final entry in (data['values'] as Map).entries)
            if (entry.key is String && entry.value is Map)
              entry.key as String: MetricReading.fromJson(
                Map<Object?, Object?>.from(entry.value as Map),
              ),
      }),
      networkAdapters: List.unmodifiable(devices(data['networkAdapters'])),
      gpuAdapters: List.unmodifiable(devices(data['gpuAdapters'])),
      disks: List.unmodifiable(devices(data['disks'])),
      sampledAt:
          timestamp is num &&
              timestamp.isFinite &&
              timestamp > 0 &&
              timestamp < 8640000000000000
          ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
          : null,
      networkName: data['networkName'] is String
          ? data['networkName'] as String
          : '',
      gpuName: data['gpuName'] is String ? data['gpuName'] as String : '',
      diskName: data['diskName'] is String ? data['diskName'] as String : '',
    );
  }

  MetricReading? reading(
    String id, {
    required int intervalSeconds,
    DateTime? now,
  }) {
    final result = values[id];
    if (result == null || !result.valid) return result;
    final last = sampledAt;
    if (last == null ||
        (now ?? DateTime.now()).difference(last) >
            Duration(seconds: intervalSeconds * 2 + 1)) {
      return MetricReading(result.value, result.unit, 'stale');
    }
    return result;
  }
}
