import 'package:cryptofloat/domain/display_snapshot.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/refresh_status.dart';
import 'package:cryptofloat/domain/system_metric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group sorting preserves mixed group slots', () {
    expect(
      reorderDisplayGroup(
        ['row:A', 'metric:x', 'asset:B', 'metric:y'],
        'metric:',
        ['metric:y', 'metric:x'],
      ),
      ['row:A', 'metric:y', 'asset:B', 'metric:x'],
    );
  });
  final now = DateTime(2026, 10, 13, 12);
  final view = AppConfig.defaults.copyWith(
    selectedAssetIds: [],
    selectedMetricIds: ['cpu.usage'],
  );
  test('metrics expire with last known time instead of returning to initial waiting', () {
    final time = now.subtract(const Duration(seconds: 4));
    final snapshot = SystemMetricSnapshot(
      sampledAt: time,
      values: const {'cpu.usage': MetricReading(2, '%', 'valid')},
    );
    final status = displayRefreshStatus(view, {}, snapshot, now: now);
    expect(status.state, RefreshState.stale);
    expect(status.lastUpdatedAt, time);
    expect(buildDisplayTexts(view, {}, snapshot, now: now).single.value, '—');
  });
  test('profile freshness excludes the other display and shows valid zero', () {
    final snapshot = SystemMetricSnapshot(
      sampledAt: now,
      values: const {'cpu.usage': MetricReading(0, '%', 'valid')},
    );
    expect(displayRefreshStatus(view, {}, snapshot, now: now).isLive, true);
    expect(
      buildDisplayTexts(view, {}, snapshot, now: now).single.text,
      'CPU 0.0%',
    );
  });
  test('mixed ordering is stable and stale unknown order keys are ignored', () {
    expect(
      orderedDisplayKeys(
        ['asset:A', 'metric:cpu.usage', 'row:B'],
        ['row:B', 'absent', 'asset:A', 'row:B'],
      ),
      ['row:B', 'asset:A', 'metric:cpu.usage'],
    );
  });
  test(
    'taskbar text is bounded and valid UTF16 with no control characters',
    () {
      final value = boundedTaskbarText(
        '${List.filled(300, '😀').join()}\u0000\n',
        201,
      );
      expect(value.length, lessThanOrEqualTo(201));
      expect(value.endsWith('…'), true);
      expect(boundedTaskbarText('a\u0000b\nc\ud800', 50), 'a b c�');
    },
  );
  test(
    'taskbar overflow is explicit without losing the saved display content',
    () {
      final cells = List.generate(40, (i) => DisplayText('Item', '$i'));
      final shown = taskbarVisibleCells(cells, chinese: false);
      expect(shown.length, 32);
      expect(shown.last.text, '+9 more');
      expect(cells.length, 40);
    },
  );
}
