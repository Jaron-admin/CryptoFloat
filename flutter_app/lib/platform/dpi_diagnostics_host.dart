import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'dpi_observation_scope.dart';

class DpiDiagnosticsHost extends StatefulWidget {
  const DpiDiagnosticsHost({
    super.key,
    required this.fontSize,
    required this.child,
  });

  final double fontSize;
  final Widget child;

  @override
  State<DpiDiagnosticsHost> createState() => _DpiDiagnosticsHostState();
}

class _DpiDiagnosticsHostState extends State<DpiDiagnosticsHost> {
  static const _channel = MethodChannel('cryptofloat/platform');
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadEnabled();
  }

  Future<void> _loadEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'window.dpiDiagnosticsEnabled',
      );
      if (mounted && enabled == true) setState(() => _enabled = true);
    } catch (_) {
      // Other platforms and ordinary launches do not collect this trace.
    }
  }

  @override
  Widget build(BuildContext context) => DpiObservationScope(
    enabled: _enabled,
    fontSize: widget.fontSize,
    onSnapshot: (snapshot) =>
        _channel.invokeMethod<void>('window.reportDpiSnapshot', snapshot),
    child: widget.child,
  );
}
