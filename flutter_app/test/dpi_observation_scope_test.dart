import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cryptofloat/platform/dpi_observation_scope.dart';

// FrameData has no public constructor or test-value setter. Override only this
// engine observation; all window, timing callback and widget behavior remains real.
class _ObservedFrameData implements ui.FrameData {
  const _ObservedFrameData(this.frameNumber);
  @override
  final int frameNumber;
}

class _FrameDispatcher extends TestPlatformDispatcher {
  _FrameDispatcher()
    : super(platformDispatcher: ui.PlatformDispatcher.instance);
  int observedFrameNumber = -1;
  VoidCallback? _metricsCallback;
  // The binding also constructs its default dispatcher. Preserve the callback
  // registered on this replacement when test-view setters deliver metrics.
  @override
  VoidCallback? get onMetricsChanged => _metricsCallback;
  @override
  set onMetricsChanged(VoidCallback? value) {
    _metricsCallback = value;
    super.onMetricsChanged = value;
  }

  @override
  ui.FrameData get frameData => _ObservedFrameData(observedFrameNumber);
}

class _FrameBinding extends AutomatedTestWidgetsFlutterBinding {
  final _FrameDispatcher _frameDispatcher = _FrameDispatcher();
  @override
  _FrameDispatcher get platformDispatcher => _frameDispatcher;
}

ui.FrameTiming _timing(int number) => ui.FrameTiming(
  vsyncStart: 1000000 + number * 1000,
  buildStart: 1000001 + number * 1000,
  buildFinish: 1000002 + number * 1000,
  rasterStart: 1000003 + number * 1000,
  rasterFinish: 1000004 + number * 1000,
  rasterFinishWallTime: 2000000 + number * 1000,
  frameNumber: number,
);

void main() {
  final binding = _FrameBinding();
  setUp(() => binding.platformDispatcher.observedFrameNumber = -1);
  Future<void> mount(
    WidgetTester tester,
    List<Map<String, Object>> events, {
    bool enabled = true,
    DpiSnapshotSink? sink,
    Widget? child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DpiObservationScope(
          enabled: enabled,
          fontSize: 13,
          onSnapshot: sink ?? (value) async => events.add(value),
          child: child ?? const Text('sample'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('disabled diagnostics emit no metrics or frame data', (
    tester,
  ) async {
    final events = <Map<String, Object>>[];
    await mount(tester, events, enabled: false);
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(events, isEmpty);
  });

  testWidgets('observes new DPR and keeps logical font size unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final events = <Map<String, Object>>[];
    await mount(tester, events);
    events.clear();
    tester.view.devicePixelRatio = 1.75;
    await tester.pump();
    final metrics = events.lastWhere((event) => event['event'] == 'metrics');
    expect(metrics['dpr'], 1.75);
    expect(metrics['physicalWidth'], 800);
    expect(metrics['logicalWidth'], closeTo(800 / 1.75, 0.001));
    expect(metrics['fontSize'], 13);
    expect(metrics['textScale'], 1);
    expect(events.any((event) => event['event'] == 'postFrame'), isTrue);
  });

  testWidgets('observation never schedules the frame it is measuring', (
    tester,
  ) async {
    final events = <Map<String, Object>>[];
    await mount(tester, events);
    events.clear();
    expect(tester.binding.hasScheduledFrame, isFalse);
    final observer = tester.state(
      find.byType(DpiObservationScope),
    ) as WidgetsBindingObserver;
    observer.didChangeMetrics();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(events.map((event) => event['event']), ['metrics']);
    await tester.pump();
    expect(events.last['event'], 'metrics');
    // Simulate an independently requested application frame.
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(events.last['event'], 'postFrame');
  });

  testWidgets('pending observations stop after disposal', (tester) async {
    final events = <Map<String, Object>>[];
    await mount(tester, events);
    final observer = tester.state(
      find.byType(DpiObservationScope),
    ) as WidgetsBindingObserver;
    observer.didChangeMetrics();
    events.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pointer observation preserves the existing tap action', (
    tester,
  ) async {
    final events = <Map<String, Object>>[];
    var taps = 0;
    await mount(
      tester,
      events,
      child: GestureDetector(
        onTap: () => taps++,
        child: const SizedBox(width: 100, height: 100, child: Text('tap')),
      ),
    );
    events.clear();
    await tester.tap(find.text('tap'));
    expect(taps, 1);
    expect(events.any((event) => event['event'] == 'pointerDown'), isTrue);
    for (final event in events) {
      expect(event.keys, isNot(contains('text')));
      expect(event.keys, isNot(contains('path')));
    }
  });

  testWidgets('a slow sink cannot create an unbounded pending queue', (
    tester,
  ) async {
    final events = <Map<String, Object>>[];
    final completions = <Completer<void>>[];
    await mount(
      tester,
      events,
      sink: (event) {
        events.add(event);
        final pending = Completer<void>();
        completions.add(pending);
        return pending.future;
      },
    );
    final observer = tester.state(
      find.byType(DpiObservationScope),
    ) as WidgetsBindingObserver;
    for (var i = 0; i < 40; i++) {
      observer.didChangeMetrics();
    }
    expect(events.length, lessThanOrEqualTo(8));
    for (final completion in completions) {
      completion.complete();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('an old timing batch cannot consume the new transition budget', (
    tester,
  ) async {
    final events = <Map<String, Object>>[];
    await mount(tester, events);
    binding.platformDispatcher.observedFrameNumber = 100;
    final observer = tester.state(
      find.byType(DpiObservationScope),
    ) as WidgetsBindingObserver;
    observer.didChangeMetrics();
    events.clear();
    tester.platformDispatcher.onReportTimings!([
      for (var number = 90; number <= 100; number++) _timing(number),
    ]);
    expect(events.where((event) => event['event'] == 'frameTiming'), isEmpty);
    await tester.pump();
    tester.platformDispatcher.onReportTimings!([
      for (var number = 101; number <= 107; number++) _timing(number),
    ]);
    expect(
      events
          .where((event) => event['event'] == 'frameTiming')
          .map((event) => event['frameBuildStartMicros']),
      [1101001, 1102001, 1103001, 1104001, 1105001, 1106001],
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('unknown frame identities are skipped without spending budget', (
    tester,
  ) async {
    final events = <Map<String, Object>>[];
    await mount(tester, events);
    final observer = tester.state(
      find.byType(DpiObservationScope),
    ) as WidgetsBindingObserver;
    observer.didChangeMetrics(); // No trustworthy transition boundary yet.
    events.clear();
    tester.platformDispatcher.onReportTimings!([_timing(100), _timing(-1)]);
    expect(events.where((event) => event['event'] == 'frameTiming'), isEmpty);
    await tester.pump();
    binding.platformDispatcher.observedFrameNumber = 100;
    observer.didChangeMetrics();
    tester.platformDispatcher.onReportTimings!([
      for (var i = 0; i < 12; i++) _timing(-1),
    ]);
    await tester.pump();
    tester.platformDispatcher.onReportTimings!([
      for (var number = 101; number <= 106; number++) _timing(number),
    ]);
    expect(events.where((event) => event['event'] == 'frameTiming').length, 6);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
