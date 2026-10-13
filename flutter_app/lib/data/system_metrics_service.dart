import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/system_metric.dart';
import '../platform/system_metrics_host.dart';

class SystemMetricsService extends ChangeNotifier {
  SystemMetricsService({SystemMetricsHost? host})
    : _host = host ?? SystemMetricsHost();
  final SystemMetricsHost _host;
  SystemMetricSnapshot _snapshot = const SystemMetricSnapshot();
  SystemMetricSnapshot get snapshot => _snapshot;
  bool get supported => _host.supported;
  Timer? _timer;
  bool _disposed = false, _reading = false;
  int _generation = 0;
  Map<String, Object?>? _options;

  Future<void> configure({
    bool enabled = true,
    int intervalSeconds = 1,
    String networkAdapterId = 'auto',
    String gpuAdapterId = 'auto',
    String diskId = 'all',
  }) async {
    final options = <String, Object?>{
      'enabled': enabled,
      'intervalMs': intervalSeconds.clamp(1, 60) * 1000,
      'networkAdapterId': networkAdapterId,
      'gpuAdapterId': gpuAdapterId,
      'diskId': diskId,
    };
    if (_disposed || mapEquals(options, _options)) return;
    _options = options;
    final generation = ++_generation;
    _timer?.cancel();
    _snapshot = const SystemMetricSnapshot();
    notifyListeners();
    if (!_host.supported) return;
    try {
      await _host.configure(options);
      if (_disposed || generation != _generation || !enabled) return;
      await refresh();
      if (_disposed || generation != _generation) return;
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(refresh()),
      );
    } on Object {
      if (!_disposed && generation == _generation) {
        _options = null;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    if (_disposed || _reading || !_host.supported) return;
    _reading = true;
    final generation = _generation;
    try {
      final data = await _host.read();
      if (!_disposed && generation == _generation) {
        _snapshot = SystemMetricSnapshot.fromJson(data);
      }
    } on Object {
      // The previous timestamp makes retained samples become stale naturally.
    } finally {
      _reading = false;
      if (!_disposed && generation == _generation) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    unawaited(_host.configure({'enabled': false}).catchError((Object _) {}));
    super.dispose();
  }
}
