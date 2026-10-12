import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';

export '../domain/models.dart' show WindowBounds;

/// Desktop window operations. Other desktop adapters can implement this contract.
///
/// Bounds use physical screen pixels. [WindowBounds.scale] records the DPI factor
/// so the Windows adapter can preserve the logical size when restoring a window.
abstract class FloatingWindowHost {
  factory FloatingWindowHost() = _ChannelFloatingWindowHost;

  bool get supported;
  Future<void> initialize({
    WindowBounds? bounds,
    bool alwaysOnTop = true,
    double opacity = 0.96,
  });
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setOpacity(double value);
  Future<WindowBounds?> getBounds();
  Future<void> setBounds(WindowBounds bounds);
  Future<void> beginDrag();
  Future<void> beginResize(String edge);
  Future<void> setSettingsMode(bool enabled);
  Future<void> close();
  Future<List<String>> getSystemFonts();
}

class _ChannelFloatingWindowHost implements FloatingWindowHost {
  static const _channel = MethodChannel('cryptofloat/platform');
  static const _fallbackFonts = <String>[
    'Segoe UI',
    'Microsoft YaHei',
    'Arial',
    'Helvetica',
    'Noto Sans',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  bool _available = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  bool get supported => _available;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_available) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      _available = false;
      return null;
    }
  }

  @override
  Future<void> initialize({
    WindowBounds? bounds,
    bool alwaysOnTop = true,
    double opacity = 0.96,
  }) async {
    await _invoke<void>('window.initialize', {
      if (bounds != null) 'bounds': bounds.toJson(),
      'alwaysOnTop': alwaysOnTop,
      'opacity': opacity.clamp(0.4, 1.0),
    });
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    await _invoke<void>('window.setAlwaysOnTop', value);
  }

  @override
  Future<void> setOpacity(double value) async {
    await _invoke<void>('window.setOpacity', value.clamp(0.4, 1.0));
  }

  @override
  Future<WindowBounds?> getBounds() async {
    final result = await _invoke<Map<Object?, Object?>>('window.getBounds');
    if (result == null) return null;
    return WindowBounds.fromJson(
      result.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<void> setBounds(WindowBounds bounds) async {
    await _invoke<void>('window.setBounds', bounds.toJson());
  }

  @override
  Future<void> beginDrag() async {
    await _invoke<void>('window.beginDrag');
  }

  /// Valid edges: left, right, top, bottom, topLeft, topRight, bottomLeft,
  /// bottomRight. Native hit testing also supports dragging any window edge.
  @override
  Future<void> beginResize(String edge) async {
    await _invoke<void>('window.beginResize', edge);
  }

  /// Enlarges the host for settings and restores the panel bounds on dismissal.
  @override
  Future<void> setSettingsMode(bool enabled) async {
    await _invoke<void>('window.setSettingsMode', enabled);
  }

  @override
  Future<void> close() async {
    await _invoke<void>('window.close');
  }

  @override
  Future<List<String>> getSystemFonts() async {
    final fonts = await _invoke<List<Object?>>('window.getSystemFonts');
    if (fonts == null) return List.of(_fallbackFonts);
    final families = fonts.whereType<String>().toSet().toList()..sort();
    return families.isEmpty ? List.of(_fallbackFonts) : families;
  }
}
