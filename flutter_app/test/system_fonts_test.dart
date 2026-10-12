import 'dart:io';

import 'package:cryptofloat/platform/system_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double _width(String text, String family) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontSize: 32),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cryptofloat/platform');
  final fixture = File(
    Platform.environment['CRYPTOFLOAT_TEST_FONT_PATH'] ??
        '${Platform.environment['LOCALAPPDATA']}/Microsoft/Windows/Fonts/'
            'SarasaMonoK-SemiBold.ttf',
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'installed face loading changes fallback glyphs to verified Sarasa metrics',
    (tester) async {
      const original = 'Sarasa Mono K SemiBold';
      final before = _width('Wi18', original);
      await tester.runAsync(() async {
        final bytes = await fixture.readAsBytes();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'window.getFontData' &&
              call.arguments == original) {
            return bytes;
          }
          throw MissingPluginException();
        });
        await SystemFonts.ensureLoaded(original);
      });
      final resolved = SystemFonts.family(original);
      final after = _width('Wi18', resolved);
      // These advances come from the installed face's independent DirectWrite
      // probe: Latin glyphs are 0.5 em, CJK glyphs are 1 em.
      expect(after, closeTo(64, 0.02));
      expect(_width('W', resolved), closeTo(16, 0.02));
      expect(_width('i', resolved), closeTo(16, 0.02));
      expect(_width('1234567890', resolved), closeTo(160, 0.02));
      expect(_width('行', resolved), closeTo(32, 0.02));
      expect(after, isNot(closeTo(before, 0.02)));
      expect(SystemFonts.hasLoaded(original), isTrue);
      expect(resolved, isNot(original));
    },
    // This optional integration fixture is installed on the affected Windows
    // host; other machines can point CRYPTOFLOAT_TEST_FONT_PATH at the same face.
    skip: !fixture.existsSync(),
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  test(
    'an unavailable native adapter does not claim the face is loaded',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const original = 'Unavailable desktop font';
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw MissingPluginException();
      });
      await SystemFonts.ensureLoaded(original);
      expect(SystemFonts.hasLoaded(original), isFalse);
      expect(SystemFonts.family(original), original);
    },
  );
}
