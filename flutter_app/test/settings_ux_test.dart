import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:cryptofloat/platform/system_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';
import 'support/settings_navigation.dart';

void main() {
  test('monospace suggestions match common installed families only', () {
    expect(isMonospaceFontFamily('Consolas'), isTrue);
    expect(isMonospaceFontFamily('Cascadia Mono'), isTrue);
    expect(isMonospaceFontFamily('Sarasa Mono SC'), isTrue);
    expect(isMonospaceFontFamily('Segoe UI'), isFalse);
    expect(isMonospaceFontFamily('Microsoft YaHei'), isFalse);
    expect(isMonospaceFontFamily('Sarasa UI SC'), isFalse);
    expect(isMonospaceFontFamily('Sarasa Gothic SC'), isFalse);
    expect(isMonospaceFontFamily('Monotype Corsiva'), isFalse);
  });

  for (final language in ['en', 'zh']) {
    testWidgets('$language settings label shared, panel, and taskbar scopes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = settingsController(
        SettingsStore(),
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: language,
          priceColorMode: 'greenUp',
        ),
      );
      await tester.pumpWidget(_settingsApp(controller, Locale(language), 0));
      await tester.pumpAndSettle();

      expect(find.text(_shared(language)), findsWidgets);
      expect(
        find.byKey(const ValueKey('display-target-selector')),
        findsNothing,
      );
      await tester.tap(find.text(language == 'zh' ? '外观' : 'Appearance').first);
      await tester.pumpAndSettle();
      await revealSetting(
        tester,
        find.byKey(const ValueKey('price-color-mode')),
      );
      expect(find.text(_priceHint(language)), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('price-color-mode')),
      );
      await tester.tap(find.byKey(const ValueKey('price-color-mode')));
      await tester.pumpAndSettle();
      expect(find.text(_plainPrice(language)), findsOneWidget);
      await tester.tap(find.text(_plainPrice(language)).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(language == 'zh' ? '任务栏' : 'Taskbar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(language == 'zh' ? '显示' : 'Display').first);
      await tester.pumpAndSettle();
      expect(find.text(_taskbarOnly(language)), findsWidgets);
      expect(find.text(_panelOnly(language)), findsNothing);

      await tester.tap(find.text(language == 'zh' ? '通用' : 'General').first);
      await tester.pumpAndSettle();
      expect(find.text(_shared(language)), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets(
    'number font picker suggests monospace and marks installed ones',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final host = SettingsHost()..fonts = ['Segoe UI', 'Consolas'];
      final controller = settingsController(
        SettingsStore(),
        host,
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'en',
        ),
      );
      await tester.pumpWidget(_settingsApp(controller, const Locale('en'), 1));
      await tester.pumpAndSettle();

      final choose = settingsFontPicker(numbers: true);
      await revealSetting(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();

      expect(
        find.text('Monospace fonts are easier to read for numbers.'),
        findsWidgets,
      );
      expect(find.text('Consolas'), findsOneWidget);
      expect(find.text('Monospace'), findsOneWidget);
      expect(find.text('Segoe UI'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('switching storage offers to copy the current data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = settingsController(
      SettingsStore(),
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'en'),
    );
    await tester.pumpWidget(_settingsApp(controller, const Locale('en'), 3));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Import & data location').last);
    await tester.tap(find.text('Import & data location').last);
    await tester.pumpAndSettle();
    expect(find.text('Portable (beside the app)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('data-storage-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System app data').last);
    await tester.pumpAndSettle();

    expect(find.text('Copy existing data?'), findsOneWidget);
    expect(find.text('Copy and switch'), findsOneWidget);
    expect(find.text('Switch without copying'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Copy existing data?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

Widget _settingsApp(AppController controller, Locale locale, int section) {
  return MaterialApp(
    locale: locale,
    theme: buildAppTheme(controller.config, brightness: Brightness.light),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SettingsPage(
      controller: controller,
      initialSection: section,
      onClose: () {},
    ),
  );
}

String _shared(String language) => language == 'zh'
    ? '同时作用于悬浮窗与任务栏'
    : 'Applies to the floating panel and the taskbar';

String _panelOnly(String language) =>
    language == 'zh' ? '仅影响悬浮窗' : 'Floating panel only';

String _taskbarOnly(String language) =>
    language == 'zh' ? '仅影响任务栏' : 'Taskbar only';

String _plainPrice(String language) =>
    language == 'zh' ? '默认（主题文字）' : 'Default (theme text)';

String _priceHint(String language) => language == 'zh'
    ? '红绿颜色比较的是上一次成功刷新的价格，不是 24 小时涨跌。启动或更换品种后的第一次刷新为中性色。'
    : 'Red and green compare with the previous successful refresh, not the 24h change. The first refresh after launch or a symbol change stays neutral.';
