import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Installed font faces are registered under application-local aliases.
///
/// Windows GDI face names can differ from the family names used by Flutter's
/// DirectWrite matcher. Configuration keeps the user's original face name;
/// only TextStyle uses [family] after [ensureLoaded] has completed.
class SystemFonts {
  static const _channel = MethodChannel('cryptofloat/platform');
  static final _aliases = <String, String>{};
  static final _pending = <String, Future<void>>{};
  static int _nextAlias = 0;

  /// Loads the exact installed face once, including concurrent startup requests.
  /// Missing native adapters leave the original family available for fallback.
  /// A missing or unreadable Windows face reports a PlatformException to callers.
  static Future<void> ensureLoaded(String original) async {
    final name = original.trim();
    if (name.isEmpty ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows ||
        _aliases.containsKey(name)) {
      return;
    }
    final current = _pending[name];
    if (current != null) return current;
    final request = _load(name);
    _pending[name] = request;
    try {
      await request;
    } finally {
      _pending.remove(name);
    }
  }

  static Future<void> _load(String name) async {
    Uint8List? bytes;
    try {
      bytes = await _channel.invokeMethod<Uint8List>(
        'window.getFontData',
        name,
      );
    } on MissingPluginException {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      throw PlatformException(
        code: 'font_unavailable',
        message: 'The installed font could not be read.',
      );
    }
    final alias = 'CryptoFloatInstalled_${++_nextAlias}';
    final loader = FontLoader(alias)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _aliases[name] = alias;
  }

  static String family(String original) =>
      _aliases[original.trim()] ?? original;

  static bool hasLoaded(String original) =>
      _aliases.containsKey(original.trim());
}

/// True when an installed family name is commonly monospace.
/// This never invents a font that is not already in the picker list.
bool isMonospaceFontFamily(String family) {
  final name = family.trim().toLowerCase();
  if (name.isEmpty) return false;
  if (RegExp(r'(^|[\s_-])mono(space)?([\s_-]|$)').hasMatch(name)) return true;
  const markers = [
    'consolas',
    'courier',
    'cascadia code',
    'inconsolata',
    'fira code',
    'firacode',
    'source code',
    'lucida console',
    'menlo',
    'monaco',
  ];
  return markers.any(name.contains);
}
