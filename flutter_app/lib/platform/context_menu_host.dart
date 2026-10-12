import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Windows popup owns its surface, so a small panel cannot clip its menu.
class ContextMenuHost {
  static const _channel = MethodChannel('cryptofloat/platform');
  String? _lastStyle;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Map<String, Object> _style(ThemeData theme) => {
    'fontFamily': 'Segoe UI',
    'colors': {
      'background': theme.colorScheme.surfaceContainer.toARGB32(),
      'foreground': theme.colorScheme.onSurface.toARGB32(),
      'secondary': theme.colorScheme.onSurfaceVariant.toARGB32(),
      'border': theme.colorScheme.outline.toARGB32(),
      'hover': theme.colorScheme.secondaryContainer.toARGB32(),
      'accent': theme.colorScheme.primary.toARGB32(),
    },
  };

  Future<void> updateAppearance(ThemeData theme) async {
    if (!supported) return;
    final style = _style(theme);
    final signature = jsonEncode(style);
    if (_lastStyle == signature) return;
    try {
      await _channel.invokeMethod<void>('window.setMenuAppearance', style);
      _lastStyle = signature;
    } on MissingPluginException {
      // Other desktop adapters retain the portable Flutter menu.
    } on PlatformException {
      // The next theme notification can retry the optional native appearance.
    }
  }

  Future<({bool handled, String? action})> show(
    Offset point, {
    required bool alwaysOnTop,
    required ThemeData theme,
  }) async {
    if (!supported) return (handled: false, action: null);
    try {
      final action = await _channel.invokeMethod<String>(
        'window.showContextMenu',
        {
          ..._style(theme),
          'x': point.dx,
          'y': point.dy,
          'alwaysOnTop': alwaysOnTop,
        },
      );
      return (handled: true, action: action);
    } on MissingPluginException {
      return (handled: false, action: null);
    } on PlatformException {
      return (handled: false, action: null);
    }
  }
}
