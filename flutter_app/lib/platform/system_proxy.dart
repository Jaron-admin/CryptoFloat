import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/proxy_resolver.dart';

class PlatformSystemProxyResolver implements SystemProxyResolver {
  static const _channel = MethodChannel('cryptofloat/platform');

  @override
  Future<String> resolve(Uri uri) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return 'DIRECT';
    }
    try {
      final result = await _channel.invokeMethod<String>(
        'network.resolveSystemProxy',
        {'url': uri.toString()},
      );
      if (result == null || result.trim().isEmpty) {
        throw const ProxyResolutionException('无法读取系统代理，请检查 Windows 网络设置。');
      }
      return result;
    } on MissingPluginException {
      throw const ProxyResolutionException('当前程序未提供系统代理功能，请使用完整的新版本程序。');
    } on PlatformException catch (error) {
      // Native error details may include URLs; only known codes select messages.
      final message = switch (error.code) {
        'system_proxy_unsupported' => '暂不支持当前网络连接类型，请检查系统网络设置。',
        'system_proxy_timeout' => '网络连接超时，请稍后重试。',
        'system_proxy_invalid' => '系统网络设置无效，请检查后重试。',
        'system_proxy_autoconfig_failed' => '无法应用系统网络设置，请检查后重试。',
        _ => '无法建立网络连接，请检查网络设置。',
      };
      throw ProxyResolutionException(message);
    }
  }
}
