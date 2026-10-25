import 'dart:convert';

import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/features/settings/template_picker.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/platform/context_menu_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'language survives settings JSON and unsupported values follow system',
    () {
      for (final language in ['system', 'zh', 'en']) {
        final config = AppConfig.defaults.copyWith(language: language);
        final restored = AppConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
        );
        expect(restored.language, language);
      }
      for (final invalid in [null, 'fr', 'EN', 123, <String>[]]) {
        expect(
          AppConfig.fromJson({
            ...AppConfig.defaults.toJson(),
            'language': invalid,
          }).language,
          'system',
        );
      }
      final legacy = Map<String, dynamic>.from(AppConfig.defaults.toJson())
        ..remove('language');
      expect(AppConfig.fromJson(legacy).language, 'system');
    },
  );

  testWidgets(
    'language preview changes immediately and save keeps the settings open',
    (tester) async {
      final store = _JsonSettingsStore();
      final controller = settingsController(
        store,
        SettingsHost(),
        config: _baseConfig(),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await _openGeneral(tester, 'zh');
      await _chooseLanguage(tester, 'English');
      expect(controller.appearanceConfig.language, 'en');
      expect(controller.config.language, 'zh');
      expect(store.saved, isNull);
      for (final label in [
        'General',
        'Appearance',
        'Display',
        'Privacy and data',
        'About',
        'Language',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('悬浮窗透明度'), findsNothing);
      expect(
        Localizations.localeOf(tester.element(find.byType(SettingsPage)))
            .languageCode,
        'en',
      );

      expect(find.text('Discard changes'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(store.saved?.language, 'en');
      await tester.tap(find.byTooltip('Return to panel'));
      await tester.pumpAndSettle();
      expect(controller.config.language, 'en');
      expect(controller.appearanceConfig.language, 'en');
      expect(find.byType(SettingsPage), findsNothing);
      await _openGeneral(tester, 'en');
      expect(find.text('悬浮窗透明度'), findsNothing);
      expect(find.text('Language'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved language reloads in English and preserves custom content',
    (tester) async {
      final store = _JsonSettingsStore();
      final original = _baseConfig().copyWith(
        headerName: 'CryptoFloat',
        customAssets: const [
          Asset(
            id: 'YAHOO:600519.SS',
            provider: 'YAHOO',
            symbol: '600519.SS',
            name: '我的观察标的',
            kind: MarketKind.equity,
            currency: 'CNY',
          ),
        ],
        customSources: const [
          CustomApiSource(
            id: 'weather',
            name: '我的天气',
            url: 'https://example.com/weather',
            enabled: false,
            fields: [
              CustomField(
                id: 'temperature',
                label: '室外温度',
                path: 'temperature',
                unit: '摄氏度',
              ),
            ],
          ),
        ],
        displayRows: const [
          DisplayRow(
            id: 'personal-text',
            segments: [DisplaySegment.literal('未更新 · 我的中文提醒')],
          ),
        ],
        customThemes: const [
          UserThemePreset(
            id: 'user:evening',
            name: '我的夜晚',
            light: ThemePaletteData.lightDefaults,
            dark: ThemePaletteData.darkDefaults,
          ),
        ],
      );
      final controller = settingsController(
        store,
        SettingsHost(),
        config: original,
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await _openGeneral(tester, 'zh');
      await _chooseLanguage(tester, 'English');
      await tester.tap(find.byTooltip('Return to panel'));
      await tester.pumpAndSettle();
      expect(store.saved?.language, 'en');
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.text('未更新 · 我的中文提醒', findRichText: true), findsOneWidget);
      final reloaded = await store.load();
      final before = Map<String, Object?>.of(original.toJson())
        ..remove('language');
      final after = Map<String, Object?>.of(reloaded.toJson())
        ..remove('language');
      expect(after, equals(before));
      final english = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        localizedAssetName(reloaded.customAssets.single, english),
        '我的观察标的',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      final reopened = settingsController(
        store,
        SettingsHost(),
        config: reloaded,
      );
      await tester.pumpWidget(CryptoFloatApp(controller: reopened));
      await tester.pumpAndSettle();
      await _openGeneral(tester, 'en');
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(reopened.config.customSources.single.fields.single.label, '室外温度');
      expect(reopened.config.customThemes.single.name, '我的夜晚');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('follow system resolves Chinese and falls back to English', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    final controller = settingsController(
      _JsonSettingsStore(),
      SettingsHost(),
      config: _baseConfig().copyWith(language: 'system'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await _openGeneral(tester, 'zh');
    expect(find.text('跟随系统'), findsWidgets);

    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('fr', 'FR'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsWidgets);
    expect(controller.config.language, 'system');
    expect(tester.takeException(), isNull);
  });

  test(
    'native menu labels and cached appearance update when language changes',
    () async {
      const channel = MethodChannel('cryptofloat/platform');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'window.showContextMenu' ? 'settings' : null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      final host = ContextMenuHost();
      final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
      final english = await AppLocalizations.delegate.load(const Locale('en'));
      final theme = ThemeData.dark();
      await host.updateAppearance(theme, chinese);
      await host.updateAppearance(theme, chinese);
      expect(
        calls,
        hasLength(1),
        reason: 'Unchanged locale and colors are cached',
      );
      await host.updateAppearance(theme, english);
      expect(calls, hasLength(2));
      expect(
        calls.map((call) => call.method),
        everyElement('window.setMenuAppearance'),
      );
      expect((calls.first.arguments as Map)['labels'], {
        'hide': '隐藏到托盘',
        'show': '显示悬浮窗',
        'refresh': '立即刷新',
        'topmost': '窗口置顶',
        'settings': '设置',
        'exit': '退出',
      });
      final englishLabels = {
        'hide': 'Hide to tray',
        'show': 'Show floating panel',
        'refresh': 'Refresh now',
        'topmost': 'Always on top',
        'settings': 'Settings',
        'exit': 'Exit',
      };
      expect((calls.last.arguments as Map)['labels'], englishLabels);
      final action = await host.show(
        const Offset(15, 20),
        alwaysOnTop: true,
        theme: theme,
        l10n: english,
      );
      expect(action, (handled: true, action: 'settings'));
      expect(calls.last.method, 'window.showContextMenu');
      expect((calls.last.arguments as Map)['labels'], englishLabels);
      expect((calls.last.arguments as Map)['alwaysOnTop'], true);
      await host.updateAppearance(theme, chinese);
      expect(
        (calls.last.arguments as Map)['labels'],
        (calls.first.arguments as Map)['labels'],
      );
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets(
      'new weather template uses $language without rewriting saved text',
      (tester) async {
        AppConfig? result;
        final original = _baseConfig().copyWith(
          language: language,
          displayRows: const [
            DisplayRow(
              id: 'kept',
              segments: [DisplaySegment.literal('保留原始中文')],
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildAppTheme(original, brightness: Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showTemplatePicker(
                      context,
                      config: original,
                    );
                  },
                  child: const Text('Open templates'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open templates'));
        await tester.pumpAndSettle();
        expect(find.text(language == 'en' ? 'Beijing' : '北京'), findsOneWidget);
        expect(
          find.text(language == 'en' ? 'City weather' : '城市天气'),
          findsOneWidget,
        );
        await tester.tap(find.text(language == 'en' ? 'Add to panel' : '加入显示'));
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.displayRows.first.segments.single.text, '保留原始中文');
        expect(
          result!.customSources.single.name,
          language == 'en' ? 'Beijing weather' : '北京天气',
        );
        expect(
          result!.customSources.single.fields.first.label,
          language == 'en' ? 'Temperature' : '气温',
        );
        expect(
          Uri.parse(result!.customSources.single.url)
              .queryParameters['latitude'],
          '39.9042',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

AppConfig _baseConfig() => AppConfig.defaults.copyWith(
  selectedAssetIds: [],
  language: 'zh',
  proxyEnabled: false,
);

Future<void> _openGeneral(WidgetTester tester, String language) async {
  await tester.tap(
    find.byKey(const ValueKey('panel-title')),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(language == 'en' ? 'Settings…' : '设置…'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(language == 'en' ? 'General' : '通用').first);
  await tester.pumpAndSettle();
}

Future<void> _chooseLanguage(WidgetTester tester, String label) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is FDropdown<String> &&
        widget.items.any((item) => item.value == 'en') &&
        widget.items.any((item) => item.value == 'zh'),
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _JsonSettingsStore extends SettingsStore {
  String? _snapshot;

  @override
  Future<void> save(AppConfig config) async {
    _snapshot = jsonEncode(config.toJson());
    await super.save(config);
  }

  @override
  Future<AppConfig> load() async =>
      AppConfig.fromJson(jsonDecode(_snapshot!) as Map<String, dynamic>);
}
