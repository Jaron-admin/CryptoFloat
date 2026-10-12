import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Configuration stores credential references; values belong in this store.
abstract class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// Windows uses user-scoped DPAPI. Other platforms need native secure adapters.
///
/// Unsupported platforms can read ordinary settings and delete stale references.
/// Saving a new credential fails explicitly instead of falling back to plaintext.
class PlatformSecretStore implements SecretStore {
  static const _channel = MethodChannel('cryptofloat/platform');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Future<void> write(String key, String value) async {
    _validateKey(key);
    if (!supported) {
      throw UnsupportedError(
        'Protected credential storage is not available on this platform.',
      );
    }
    try {
      await _channel.invokeMethod<void>('secret.write', {
        'key': key,
        'value': value,
      });
    } on MissingPluginException {
      throw UnsupportedError('Protected credential storage is unavailable.');
    }
  }

  @override
  Future<String?> read(String key) async {
    _validateKey(key);
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('secret.read', {'key': key});
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    _validateKey(key);
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('secret.delete', {'key': key});
    } on MissingPluginException {
      return;
    }
  }

  void _validateKey(String key) {
    if (key.isEmpty || key.length > 512) {
      throw ArgumentError(
        'A credential reference must contain 1–512 characters.',
      );
    }
  }
}
