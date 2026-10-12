import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tray integration stays outside the portable panel and data layer.
class TrayHost {
  static const _channel = MethodChannel('cryptofloat/platform');
  final _actions = StreamController<String>.broadcast();
  bool _disposed = false;

  TrayHost() {
    if (supported) _channel.setMethodCallHandler(_handle);
  }

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Stream<String> get actions => _actions.stream;

  Future<void> _handle(MethodCall call) async {
    if (_disposed || call.method != 'tray.action') return;
    final action = call.arguments;
    if (action is String &&
        const {'show', 'settings', 'refresh', 'exit'}.contains(action)) {
      _actions.add(action);
    }
  }

  /// Native code only hides after successfully establishing a recovery icon.
  Future<bool> hide() async {
    if (!supported || _disposed) return false;
    try {
      return await _channel.invokeMethod<bool>('window.hideToTray') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> show() async {
    if (!supported || _disposed) return;
    try {
      await _channel.invokeMethod<bool>('window.showFromTray');
    } on PlatformException {
      // The existing window stays available if a platform operation fails.
    } on MissingPluginException {
      // Other desktop adapters may not provide a notification area yet.
    }
  }

  void dispose() {
    _disposed = true;
    if (supported) _channel.setMethodCallHandler(null);
    unawaited(_actions.close());
  }
}
