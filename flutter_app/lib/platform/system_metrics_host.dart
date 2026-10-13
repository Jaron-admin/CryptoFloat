import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class SystemMetricsHost {
  factory SystemMetricsHost() = ChannelSystemMetricsHost;
  bool get supported;
  Future<void> configure(Map<String, Object?> options);
  Future<Map<Object?, Object?>> read();
}

class ChannelSystemMetricsHost implements SystemMetricsHost {
  static const _channel = MethodChannel('cryptofloat/platform');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  @override
  Future<void> configure(Map<String, Object?> options) async {
    if (supported) {
      await _channel.invokeMethod<void>('metrics.configure', options);
    }
  }

  @override
  Future<Map<Object?, Object?>> read() async => supported
      ? await _channel.invokeMapMethod<Object?, Object?>('metrics.read') ??
            const {}
      : const {};
}
