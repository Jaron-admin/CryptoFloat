import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../domain/models.dart';
import 'proxy_resolver.dart';
import 'source_security.dart';

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Each new request resolves the current system proxy settings.
/// No redirects are followed, including redirects on authenticated custom GETs.
class HttpTransport {
  HttpTransport({this.systemProxyResolver});

  final SystemProxyResolver? systemProxyResolver;
  final Set<HttpClient> _clients = {};
  final List<Completer<void>> _waiters = [];
  int _activeRequests = 0;
  bool _disposed = false;
  static const timeout = Duration(seconds: 12);

  /// The config argument is retained for callers with a settings snapshot.
  /// Legacy manual proxy fields no longer affect routing. Standalone Dart
  /// clients without a platform resolver use an explicit direct connection.
  Future<String> resolveProxy(Uri uri, AppConfig config) async {
    if (_disposed) throw const SourceException('数据连接已关闭。');
    _validateUri(uri);
    final resolver = systemProxyResolver;
    if (resolver == null) return 'DIRECT';
    try {
      final directive = await resolver.resolve(uri).timeout(timeout);
      return validateProxyDirective(directive);
    } on ProxyResolutionException catch (error) {
      throw SourceException(error.message);
    } on TimeoutException {
      throw const SourceException('网络连接超时，请稍后重试。');
    } on Object {
      // Platform exceptions can carry URLs or credentials in their details.
      throw const SourceException('无法建立网络连接，请检查网络设置。');
    }
  }

  static void _validateUri(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const SourceException('数据连接需要完整的 HTTPS 地址，且不能包含账号密码或片段。');
    }
  }

  Future<Object?> getJson(
    Uri uri,
    AppConfig config, {
    Map<String, String> headers = const {},
  }) async {
    return _getBoundedJson(uri, config, headers, maxResponseBytes);
  }

  /// Only public exchange catalogs may use the larger, still bounded response.
  /// Custom data sources retain their independent 2 MiB limit.
  Future<Object?> getCatalogJson(Uri uri, AppConfig config) async {
    const catalogEndpoints = {
      'www.okx.com': '/api/v5/public/instruments',
      'data-api.binance.vision': '/api/v3/exchangeInfo',
      'api.kucoin.com': '/api/v2/symbols',
    };
    _validateUri(uri);
    if (uri.port != 443 || catalogEndpoints[uri.host] != uri.path) {
      throw const SourceException('币种目录地址不受支持。');
    }
    return _getBoundedJson(uri, config, const {}, 16 * 1024 * 1024);
  }

  Future<Object?> _getBoundedJson(
    Uri uri,
    AppConfig config,
    Map<String, String> headers,
    int responseLimit,
  ) async {
    await _acquire();
    try {
      return await _getJson(
        uri,
        config,
        headers: headers,
        responseLimit: responseLimit,
      );
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_disposed) throw const SourceException('数据连接已关闭。');
    if (_activeRequests < 6) {
      _activeRequests++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _activeRequests--;
    }
  }

  Future<Object?> _getJson(
    Uri uri,
    AppConfig config, {
    Map<String, String> headers = const {},
    required int responseLimit,
  }) async {
    final proxy = await resolveProxy(uri, config);
    if (_disposed) throw const SourceException('数据连接已关闭。');
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 5)
      ..userAgent = 'DuoMonitor/1.6.0'
      ..findProxy = (_) => proxy;
    _clients.add(client);
    try {
      final bytes = await _request(
        client,
        uri,
        headers,
        responseLimit,
      ).timeout(timeout);
      // Decode bounded JSON away from Flutter's UI isolate.
      return await Isolate.run(() => jsonDecode(utf8.decode(bytes)));
    } on TimeoutException {
      throw const SourceException('请求超时，请稍后重试。');
    } on SocketException {
      throw const SourceException('暂时无法连接数据源，请检查网络连接。');
    } on HandshakeException {
      throw const SourceException('HTTPS 证书验证失败。');
    } on HttpException {
      throw const SourceException('数据连接失败，请检查地址或网络设置。');
    } on FormatException {
      throw const SourceException('响应不是有效的 UTF-8 JSON。');
    } finally {
      _clients.remove(client);
      client.close(force: true);
    }
  }

  Future<List<int>> _request(
    HttpClient client,
    Uri uri,
    Map<String, String> headers,
    int responseLimit,
  ) async {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    for (final entry in headers.entries) {
      validateHeader(entry.key, entry.value);
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close();
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const SourceException('数据源发生跳转。请填写最终的 HTTPS 地址。');
    }
    if (response.statusCode == 429) {
      throw const SourceException('数据源限制请求频率，请稍后重试或增大刷新间隔。');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SourceException('数据源返回 HTTP ${response.statusCode}。');
    }
    if (response.contentLength > responseLimit) {
      throw SourceException('数据源响应超过 ${responseLimit ~/ (1024 * 1024)} MB 上限。');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > responseLimit) {
        throw SourceException(
          '数据源响应超过 ${responseLimit ~/ (1024 * 1024)} MB 上限。',
        );
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  void dispose() {
    _disposed = true;
    for (final waiter in _waiters) {
      waiter.completeError(const SourceException('数据连接已关闭。'));
    }
    _waiters.clear();
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    _clients.clear();
  }
}
