import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cryptofloat/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

void main() {
  testWidgets('floating panel respects mixed display ordering', (tester) async {
    final config = AppConfig.defaults.copyWith(
      selectedAssetIds: [],
      selectedMetricIds: ['cpu.usage'],
      displayRows: [
        const DisplayRow(
          id: 'note',
          segments: [DisplaySegment.literal('My note')],
        ),
      ],
      displayOrder: ['row:note', 'metric:cpu.usage'],
    );
    await tester.pumpWidget(
      CryptoFloatApp(
        controller: settingsController(
          SettingsStore(),
          SettingsHost(),
          config: config,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('panel-row:note'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('panel-metric:cpu.usage')))
            .dy,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final language in ['en', 'zh']) {
    testWidgets(
      '$language system settings fit compact width and discard taskbar draft',
      (tester) async {
        tester.view.physicalSize = const Size(520, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = SettingsStore();
        final controller = settingsController(
          store,
          SettingsHost(),
          config: AppConfig.defaults.copyWith(
            selectedAssetIds: [],
            language: language,
          ),
        );
        final original = encodeJson(controller.config.toJson());
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            theme: buildAppTheme(
              controller.config,
              brightness: Brightness.light,
            ),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SettingsPage(
              controller: controller,
              initialSection: 6,
              onClose: () => closed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(language == 'zh' ? '任务栏' : 'Taskbar').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final checkbox = find.byKey(const ValueKey('metric-select-cpu.usage'));
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(language == 'zh' ? '返回悬浮窗' : 'Return to panel').last,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(language == 'zh' ? '放弃更改' : 'Discard changes'),
        );
        await tester.pumpAndSettle();
        expect(closed, true);
        expect(store.saved, isNull);
        expect(encodeJson(controller.config.toJson()), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
  testWidgets(
    'taskbar metric selection saves without changing floating content',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SettingsStore();
      final controller = settingsController(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'zh',
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppConfig.defaults.headerName),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置…'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('display-target-selector')),
        findsOneWidget,
      );
      await tester.tap(find.text('任务栏').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('系统监测').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('metric-select-gpu.usage')),
      );
      await tester.tap(find.byKey(const ValueKey('metric-select-gpu.usage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();
      expect(store.saved, isNotNull);
      final root = store.saved!.toJson();
      expect(root['selectedMetricIds'], isEmpty);
      final taskbar = root['taskbar'] as Map;
      expect(
        (taskbar['profile'] as Map)['selectedMetricIds'],
        contains('gpu.usage'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
