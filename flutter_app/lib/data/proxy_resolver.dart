import 'dart:io';

/// Resolves a target URL against the current operating system proxy settings.
/// Implementations return Dart HttpClient directives, without credentials.
abstract class SystemProxyResolver {
  Future<String> resolve(Uri uri);
}

/// Safe messages created by our resolver, without external exception details.
class ProxyResolutionException implements Exception {
  const ProxyResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _httpProxyDirective(String host, int port) {
  if (port < 1 || port > 65535) {
    throw const ProxyResolutionException('代理端口需要在 1 到 65535 之间。');
  }
  return 'PROXY ${_proxyHost(host.trim())}:$port';
}

/// Validate every candidate before passing it to HttpClient. Unknown schemes
/// must fail rather than be ignored and accidentally turn a request into DIRECT.
String validateProxyDirective(String value) {
  if (value.isEmpty ||
      value.length > 4096 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const ProxyResolutionException('系统代理返回了无效的连接设置。');
  }
  final candidates = value.split(';');
  if (candidates.length > 32) {
    throw const ProxyResolutionException('系统代理返回的候选地址过多。');
  }
  final normalized = <String>[];
  for (final candidate in candidates) {
    final directive = candidate.trim();
    if (directive.toUpperCase() == 'DIRECT') {
      normalized.add('DIRECT');
      continue;
    }
    if (RegExp(r'^SOCKS', caseSensitive: false).hasMatch(directive)) {
      throw const ProxyResolutionException('暂不支持当前网络连接类型，请使用 HTTP 或混合代理端口。');
    }
    final match = RegExp(
      r'^PROXY +(\[[^\]]+\]|[^:\s]+):([0-9]{1,5})$',
      caseSensitive: false,
    ).firstMatch(directive);
    if (match == null) {
      throw const ProxyResolutionException('系统代理格式暂不支持，请使用 HTTP 代理或混合代理端口。');
    }
    normalized.add(_httpProxyDirective(match[1]!, int.parse(match[2]!)));
  }
  return normalized.join('; ');
}

String _proxyHost(String host) {
  if (host.isEmpty || host.length > 253) {
    throw const ProxyResolutionException('代理地址无效，请填写主机名或 IP 地址。');
  }
  final bracketed = host.startsWith('[') && host.endsWith(']');
  final address = bracketed ? host.substring(1, host.length - 1) : host;
  if (address.contains(':')) {
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null || parsed.type != InternetAddressType.IPv6) {
      throw const ProxyResolutionException('代理 IPv6 地址无效。');
    }
    return '[$address]';
  }
  if (bracketed ||
      !RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?\.?$')
          .hasMatch(address)) {
    throw const ProxyResolutionException('代理地址无效，请只填写主机名或 IP，不要填写协议、路径或账号密码。');
  }
  return address;
}
