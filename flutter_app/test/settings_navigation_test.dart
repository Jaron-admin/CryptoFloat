import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';
import 'support/settings_navigation.dart';

void main() {
  for (final query in ['fonts', 'columns', 'header']) {
    testWidgets('search reveals the $query control in appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = settingsController(
        SettingsStore(),
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          language: 'en',
          proxyEnabled: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsPage(
            controller: controller,
            initialSection: query == 'header' ? 2 : 0,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (query == 'header') {
        await tester.tap(find.text('Taskbar').first);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(FTextField).first, query);
      await tester.pumpAndSettle();
      final headerTitle = lookupAppLocalizations(const Locale('en'))
          .settingCatalogHeader;
      await tester.tap(
        query == 'header'
            ? find.widgetWithText(FListTile, headerTitle)
            : find.byType(FListTile).first,
      );
      await tester.pumpAndSettle();
      final control = switch (query) {
        'fonts' => settingsFontPicker(),
        'header' => find.byKey(const ValueKey('header-name')),
        _ => find.byKey(const ValueKey('panel-label-value-gap')),
      };
      expect(
        control.hitTestable(),
        findsOneWidget,
        reason: 'A search result must scroll its real control into view.',
      );
      expect(
        find.byTooltip('More'),
        findsOneWidget,
        reason: 'Import and export must use the page-level validation path.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }
}
