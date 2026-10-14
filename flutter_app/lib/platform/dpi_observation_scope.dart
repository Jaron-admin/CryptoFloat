import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

typedef DpiSnapshotSink = Future<void> Function(Map<String, Object> snapshot);

/// Observes existing viewport updates without requesting frames or changing DPI.
/// The sink receives fixed event names and numbers, never displayed user text.
class DpiObservationScope extends StatefulWidget {
  const DpiObservationScope({
    super.key,
    required this.enabled,
    required this.fontSize,
    required this.onSnapshot,
    required this.child,
  });

  final bool enabled;
  final double fontSize;
  final DpiSnapshotSink onSnapshot;
  final Widget child;

  @override
  State<DpiObservationScope> createState() => _DpiObservationScopeState();
}

class _DpiObservationScopeState extends State<DpiObservationScope>
    with WidgetsBindingObserver {
  ui.FlutterView? _view;
  Size? _mediaSize;
  double _textScale = 1;
  bool _observing = false;
  bool _postFramePending = false;
  int _generation = 0;
  int _sequence = 0;
  int _inFlight = 0;
  int _remainingTimings = 0;
  int _timingBoundaryFrame = -1;

  @override
  void initState() {
    super.initState();
    _setObserving(widget.enabled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    final media = MediaQuery.maybeOf(context);
    _mediaSize = media?.size;
    _textScale = media?.textScaler.scale(1) ?? 1;
    if (_observing) _queuePostFrame();
  }

  @override
  void didUpdateWidget(covariant DpiObservationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _setObserving(widget.enabled);
      if (_observing) _queuePostFrame();
    }
  }

  void _setObserving(bool value) {
    if (value == _observing) return;
    _observing = value;
    _generation++;
    if (value) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addTimingsCallback(_onTimings);
      _startTimingWindow();
    } else {
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.removeTimingsCallback(_onTimings);
      _postFramePending = false;
      _remainingTimings = 0;
      _timingBoundaryFrame = -1;
    }
  }

  @override
  void didChangeMetrics() {
    if (!_observing) return;
    _startTimingWindow();
    _write('metrics');
    _queuePostFrame();
  }

  void _onPointerDown(PointerDownEvent event) {
    _startTimingWindow();
    _write('pointerDown');
    _queuePostFrame();
  }

  void _queuePostFrame() {
    if (!_observing || _postFramePending) return;
    _postFramePending = true;
    final generation = _generation;
    // This does not schedule a frame. A stale-frame diagnosis must not make
    // its own observation change the renderer's scheduling behavior.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_observing || generation != _generation) return;
      _postFramePending = false;
      _write('postFrame');
    });
  }

  void _startTimingWindow() {
    _remainingTimings = 6;
    _timingBoundaryFrame =
        WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    if (!_observing || _remainingTimings == 0 || _timingBoundaryFrame < 0) {
      return;
    }
    for (final timing in timings) {
      // Release builds report old-to-new batches about once per second. Old
      // frames must not consume the six observations reserved for this change.
      // Unknown identities (-1), or an unknown boundary, are skipped: their
      // ordering is not evidence. Metrics/postFrame observations still work,
      // and the next metrics/click with a known boundary enables timings again.
      if (timing.frameNumber < 0 ||
          timing.frameNumber <= _timingBoundaryFrame) {
        continue;
      }
      if (_remainingTimings == 0) break;
      _remainingTimings--;
      _write('frameTiming', {
        'buildMicros': timing.buildDuration.inMicroseconds,
        'rasterMicros': timing.rasterDuration.inMicroseconds,
        'frameBuildStartMicros': timing.timestampInMicroseconds(
          ui.FramePhase.buildStart,
        ),
        'frameRasterFinishMicros': timing.timestampInMicroseconds(
          ui.FramePhase.rasterFinish,
        ),
      });
    }
  }

  void _write(String event, [Map<String, Object> extra = const {}]) {
    final view = _view;
    if (!mounted || !_observing || view == null || _inFlight >= 8) return;
    final ratio = view.devicePixelRatio;
    final size = view.physicalSize;
    if (!ratio.isFinite ||
        ratio <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }
    final snapshot = <String, Object>{
      'event': event,
      'seq': ++_sequence,
      'dpr': ratio,
      'physicalWidth': size.width,
      'physicalHeight': size.height,
      'logicalWidth': size.width / ratio,
      'logicalHeight': size.height / ratio,
      'textScale': _textScale,
      'fontSize': widget.fontSize,
      if (_mediaSize != null) 'mediaWidth': _mediaSize!.width,
      if (_mediaSize != null) 'mediaHeight': _mediaSize!.height,
      ...extra,
    };
    _inFlight++;
    unawaited(_send(snapshot));
  }

  Future<void> _send(Map<String, Object> snapshot) async {
    try {
      await widget.onSnapshot(snapshot);
    } catch (_) {
      // Optional diagnostics must not interrupt the application.
    } finally {
      _inFlight--;
    }
  }

  @override
  void dispose() {
    _setObserving(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _observing
      ? Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          child: widget.child,
        )
      : widget.child;
}
