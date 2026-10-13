import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Only rendered text and appearance cross this boundary, never source secrets.
class TaskbarHost extends ChangeNotifier {
  static const _channel = MethodChannel('cryptofloat/platform');
  final _actions = StreamController<String>.broadcast();
  Stream<String> get actions => _actions.stream;
  String _state = 'waiting';
  String get state => _state;
  bool _busy = false, _disposed = false;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> update(Map<String, Object?> frame) async {
    if (_disposed || _busy) return;
    if (!supported) {
      _setState('unsupported');
      return;
    }
    _busy = true;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'taskbar.update',
        frame,
      );
      if (_disposed) return;
      _setState(result?['state'] as String? ?? 'waiting');
      final action = result?['action'];
      if (action is String &&
          const {
            'show',
            'settings',
            'refresh',
            'disable',
            'exit',
          }.contains(action)) {
        _actions.add(action);
      }
    } on MissingPluginException {
      _setState('unsupported');
    } on Object {
      _setState('error');
    } finally {
      _busy = false;
    }
  }

  void _setState(String value) {
    if (_disposed || _state == value) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (supported) {
      unawaited(
        _channel.invokeMethod<void>('taskbar.close').catchError((Object _) {}),
      );
    }
    unawaited(_actions.close());
    super.dispose();
  }
}
