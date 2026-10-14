import 'dart:async';

import 'package:cryptofloat/platform/tray_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native outside click is dispatched independently of tray commands',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final host = TrayHost();
      var clicks = 0;
      final actions = <String>[];
      final clickSub = host.settingsOutsideClicks.listen((_) => clicks++);
      final actionSub = host.actions.listen(actions.add);
      Future<void> send(String method, [Object? args]) async {
        final replied = Completer<void>();
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'cryptofloat/platform',
              const StandardMethodCodec().encodeMethodCall(
                MethodCall(method, args),
              ),
              (_) => replied.complete(),
            );
        await replied.future;
        await Future<void>.delayed(Duration.zero);
      }

      await send('window.settingsOutsideClick');
      await send('window.focusLost');
      await send('tray.action', 'settings');
      await send('tray.action', 'unexpected');
      expect(clicks, 1);
      expect(actions, ['settings']);
      await clickSub.cancel();
      await actionSub.cancel();
      host.dispose();
    },
  );
}
