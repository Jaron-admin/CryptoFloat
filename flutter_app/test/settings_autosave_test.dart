import 'dart:async';

import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

class _Store extends SettingsStore {
  bool fail = false;
  int writes = 0;
  @override
  Future<void> save(AppConfig config) async {
    writes++;
    if (fail) throw const FormatException('portable_directory_unwritable');
    await super.save(config);
  }
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('panel-title')),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('设置…'));
  await tester.pumpAndSettle();
}

Future<void> changeFont(WidgetTester tester) async {
  await tester.tap(find.text('外观').first);
  await tester.pumpAndSettle();
  final choose = find.text('选择系统字体').last;
  await tester.ensureVisible(choose);
  await tester.tap(choose);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Consolas'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'outside clicks ignore active editor then save after editor closes',
    (tester) async {
      final outside = StreamController<void>.broadcast();
      final store = _Store();
      final controller = settingsController(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'zh',
        ),
      );
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
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
            initialSection: 3,
            outsideClicks: outside.stream,
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.text('选择系统字体').last;
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      outside.add(null);
      await tester.pumpAndSettle();
      expect(closed, false);
      expect(store.writes, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Consolas'));
      await tester.pumpAndSettle();
      // Losing focus alone does not generate an outside-click event.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(closed, false);
      outside.add(null);
      outside.add(null);
      await tester.pumpAndSettle();
      expect(closed, true);
      expect(store.writes, 1);
      expect(store.saved?.numberFontFamily, 'Consolas');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await outside.close();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('unchanged settings close without another write', (tester) async {
    final store = _Store();
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    expect(find.byType(SettingsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing settings saves once and briefly confirms success', (
    tester,
  ) async {
    final store = _Store();
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('保存并返回'), findsNothing);
    await changeFont(tester);
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(store.saved?.numberFontFamily, 'Consolas');
    expect(store.writes, 1);
    expect(find.text('设置已保存'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('设置已保存'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('save failure retains draft and retry succeeds', (tester) async {
    final store = _Store()..fail = true;
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await changeFont(tester);
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(store.saved, isNull);
    expect(controller.appearanceConfig.numberFontFamily, 'Consolas');
    store.fail = false;
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(store.saved?.numberFontFamily, 'Consolas');
    expect(find.byType(SettingsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
