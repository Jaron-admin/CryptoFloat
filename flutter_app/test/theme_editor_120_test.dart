import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/settings_theme_picker.dart';
import 'package:cryptofloat/features/settings/theme_editor.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _preset = UserThemePreset(
  id: 'user:test',
  name: 'Test theme',
  light: ThemePaletteData.lightDefaults,
  dark: ThemePaletteData.darkDefaults,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'HEX and RGB inputs stay in sync and invalid values prevent save',
    (tester) async {
      final result = await _open(tester);
      await tester.enterText(find.byKey(const ValueKey('theme-hex')), '123456');
      await tester.pumpAndSettle();
      expect(_channel(tester, 'r'), '18');
      expect(_channel(tester, 'g'), '52');
      expect(_channel(tester, 'b'), '86');
      await tester.enterText(find.byKey(const ValueKey('theme-r')), '255');
      await tester.pumpAndSettle();
      expect(_channel(tester, 'hex'), 'FF3456');
      await tester.enterText(find.byKey(const ValueKey('theme-g')), '999');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('theme-save')))
            .onPressed,
        isNull,
      );
      expect(find.text('Use a number from 0 to 255.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('theme-g')), '0');
      await tester.enterText(find.byKey(const ValueKey('theme-hex')), 'oops');
      await tester.pumpAndSettle();
      expect(find.text('Enter six hexadecimal digits.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('theme-save')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('theme-hex')),
        '#112233',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-save')));
      await tester.pumpAndSettle();
      expect(result.value?.light.background, 0xff112233);
      expect(result.value?.dark.background, _preset.dark.background);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('named theme keeps separate light dark and role colors', (
    tester,
  ) async {
    final result = await _open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('theme-name')),
      '夜航 · Night',
    );
    await tester.enterText(find.byKey(const ValueKey('theme-hex')), '112233');
    await tester.tap(find.text('Dark').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('theme-hex')), '203040');
    await tester.tap(find.byKey(const ValueKey('theme-role-background')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accent').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('theme-hex')), '336699');
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pumpAndSettle();
    expect(result.value?.name, '夜航 · Night');
    expect(result.value?.light.background, 0xff112233);
    expect(result.value?.dark.background, 0xff203040);
    expect(result.value?.dark.accent, 0xff336699);
    expect(result.value?.light.accent, _preset.light.accent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HSV sliders retain hue and saturation through black', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byKey(const ValueKey('theme-hex')), '339966');
    await tester.pumpAndSettle();
    final hue = _slider(tester, 'hue').value;
    final saturation = _slider(tester, 'saturation').value;
    final brightness = _slider(tester, 'brightness').value;
    _slider(tester, 'brightness').onChanged!(0);
    await tester.pumpAndSettle();
    expect(_channel(tester, 'hex'), '000000');
    expect(_slider(tester, 'hue').value, closeTo(hue, .001));
    expect(_slider(tester, 'saturation').value, closeTo(saturation, .001));
    _slider(tester, 'brightness').onChanged!(brightness);
    await tester.pumpAndSettle();
    expect(_channel(tester, 'hex'), '339966');
    expect(tester.takeException(), isNull);
  });

  testWidgets('color spectrum clamps drags and supports keyboard adjustment', (
    tester,
  ) async {
    await _open(tester);
    final spectrum = find.byKey(const ValueKey('theme-spectrum'));
    await tester.tapAt(tester.getCenter(spectrum));
    await tester.pumpAndSettle();
    expect(_slider(tester, 'saturation').value, closeTo(50, .5));
    expect(_slider(tester, 'brightness').value, closeTo(50, .5));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_slider(tester, 'saturation').value, closeTo(51, .5));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(_slider(tester, 'brightness').value, closeTo(60, .5));
    await tester.dragFrom(
      tester.getCenter(spectrum),
      const Offset(1000, -1000),
    );
    await tester.pumpAndSettle();
    expect(_slider(tester, 'saturation').value, 100);
    expect(_slider(tester, 'brightness').value, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel leaves the original theme unchanged', (tester) async {
    final result = await _open(tester);
    await tester.enterText(find.byKey(const ValueKey('theme-hex')), 'ABCDEF');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result.closed, isTrue);
    expect(result.value, isNull);
    expect(_preset.light.background, ThemePaletteData.lightDefaults.background);
  });

  testWidgets(
    'theme picker creates copies and deletes named presets independently',
    (tester) async {
      tester.view.physicalSize = const Size(920, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var config = AppConfig.defaults.copyWith(customThemes: [_preset]);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildAppTheme(config, brightness: Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setState) => SettingsThemePicker(
                  config: config,
                  onChanged: (value) => setState(() => config = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save current colors as a theme'));
      await tester.tap(find.text('Save current colors as a theme'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('theme-name')), 'Dawn');
      await tester.enterText(find.byKey(const ValueKey('theme-hex')), '112244');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-save')));
      await tester.pumpAndSettle();
      expect(config.customThemes.length, 2);
      final created = config.customThemes.last;
      expect(created.name, 'Dawn');
      expect(created.light.background, 0xff112244);
      expect(config.lightTheme, created.id);
      expect(config.darkTheme, created.id);
      await tester.ensureVisible(find.byTooltip('Copy Dawn'));
      await tester.tap(find.byTooltip('Copy Dawn'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-save')));
      await tester.pumpAndSettle();
      expect(config.customThemes.length, 3);
      final copy = config.customThemes.last;
      expect(copy.name, 'Dawn copy');
      expect(copy.id, isNot(created.id));
      expect(copy.light.background, created.light.background);
      await tester.ensureVisible(find.byTooltip('Delete Dawn copy'));
      await tester.tap(find.byTooltip('Delete Dawn copy'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(config.customThemes.map((theme) => theme.name), [
        'Test theme',
        'Dawn',
      ]);
      expect(config.lightTheme, 'fluent');
      expect(config.darkTheme, 'fluent');
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets('$language color editor fits narrow and short viewports', (
      tester,
    ) async {
      await _open(tester, size: const Size(320, 450), language: language);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('theme-hex')));
      await tester.enterText(find.byKey(const ValueKey('theme-hex')), 'F');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('theme-brightness-slider')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const ValueKey('theme-save'))).bottom,
        lessThanOrEqualTo(450),
      );
    });
  }

  testWidgets('render theme editor previews with synthetic colors', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
      for (final font in {
        'Segoe UI': 'segoeui.ttf',
        'Microsoft YaHei': 'msyh.ttc',
      }.entries) {
        final file = File('$windows/Fonts/${font.value}');
        if (!await file.exists()) continue;
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      final materialIcons = File(
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}'
        '/material_fonts/materialicons-regular.otf',
      );
      if (await materialIcons.exists()) {
        await (FontLoader('MaterialIcons')
              ..addFont(materialIcons.readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    });
    for (final language in ['en', 'zh']) {
      final result = await _open(
        tester,
        language: language,
        size: const Size(940, 760),
      );
      await tester.enterText(find.byKey(const ValueKey('theme-hex')), '397B65');
      await tester.pumpAndSettle();
      final boundary =
          result.captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('dist/review-1.2.0/theme-editor-$language.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _Result {
  UserThemePreset? value;
  bool closed = false;
  final captureKey = GlobalKey();
}

Future<_Result> _open(
  WidgetTester tester, {
  String language = 'en',
  Size size = const Size(920, 740),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final result = _Result();
  await tester.pumpWidget(
    RepaintBoundary(
      key: result.captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildAppTheme(AppConfig.defaults, brightness: Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result.value = await showDialog<UserThemePreset>(
                  context: context,
                  builder: (_) => const ThemeEditorDialog(theme: _preset),
                );
                result.closed = true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

String _channel(WidgetTester tester, String channel) => tester
    .widget<TextField>(find.byKey(ValueKey('theme-$channel')))
    .controller!
    .text;

Slider _slider(WidgetTester tester, String name) =>
    tester.widget<Slider>(find.byKey(ValueKey('theme-$name-slider')));
