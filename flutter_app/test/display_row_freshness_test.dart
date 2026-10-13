import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/panel/display_row_view.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a template reports its field timestamp and error independently',
    (tester) async {
      final old = DateTime(2026, 10, 13, 10);
      final recent = old.add(const Duration(minutes: 5));
      const row = DisplayRow(
        id: 'a',
        segments: [
          DisplaySegment.field(assetId: 'custom:fixture', fieldId: 'a'),
        ],
      );
      final config = AppConfig.defaults.copyWith(
        customSources: [
          const CustomApiSource(
            id: 'fixture',
            name: 'Fixture',
            url: 'https://example.com',
            fields: [CustomField(id: 'a', label: 'A', path: 'a')],
          ),
        ],
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
          home: Scaffold(
            body: DisplayRowView(
              row: row,
              config: config,
              quotes: {
                'custom:fixture': MarketQuote(
                  assetId: 'custom:fixture',
                  price: null,
                  currency: '',
                  updatedAt: recent,
                  extra: const {'a': 7, 'b': 8},
                  fieldErrors: const {'a': '所选字段暂无有效数据。'},
                  fieldUpdatedAt: {'a': old, 'b': recent},
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('10:00:00'));
      expect(
        tooltip.message,
        contains('The selected field has no valid data yet.'),
      );
      expect(tooltip.message, isNot(contains('10:05:00')));
      expect(find.textContaining('10:00:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
