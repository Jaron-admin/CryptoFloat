import 'dart:async';

import 'package:cryptofloat/data/system_metrics_service.dart';
import 'package:cryptofloat/platform/system_metrics_host.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMetricsHost implements SystemMetricsHost {
  @override
  bool get supported => true;
  bool failConfigure = false;
  int configurations = 0;
  Completer<Map<Object?, Object?>>? pending;
  @override
  Future<void> configure(Map<String, Object?> options) async {
    configurations++;
    if (failConfigure) throw StateError('offline');
  }

  @override
  Future<Map<Object?, Object?>> read() async =>
      pending?.future ??
      {
        'sampledAtMs': DateTime.now().millisecondsSinceEpoch,
        'values': {
          'cpu.usage': {'value': 5, 'unit': '%', 'state': 'valid'},
        },
      };
}

void main() {
  test('failed configure can retry identical options', () async {
    final host = FakeMetricsHost()..failConfigure = true;
    final service = SystemMetricsService(host: host);
    addTearDown(service.dispose);
    await service.configure();
    host.failConfigure = false;
    await service.configure();
    expect(host.configurations, 2);
    expect(service.snapshot.values['cpu.usage']?.value, 5);
  });
  test(
    'disabled sampler clears and notifies without accepting an old read',
    () async {
      final host = FakeMetricsHost();
      final service = SystemMetricsService(host: host);
      addTearDown(service.dispose);
      var changes = 0;
      service.addListener(() => changes++);
      await service.configure();
      host.pending = Completer();
      final pendingRead = service.refresh();
      final before = changes;
      await service.configure(enabled: false);
      expect(changes, greaterThan(before));
      host.pending!.complete({
        'sampledAtMs': 100,
        'values': {
          'cpu.usage': {'value': 99, 'unit': '%', 'state': 'valid'},
        },
      });
      await pendingRead;
      expect(service.snapshot.values, isEmpty);
    },
  );
}
