import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/price_format_settings.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('price controls select compact notation and decimals per asset', (
    tester,
  ) async {
    const id = 'OKX:BTC-USDT';
    var config = AppConfig.defaults.copyWith(
      selectedAssetIds: [id],
      language: 'en',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: PriceFormatSettings(
                config: config,
                quotes: {
                  id: MarketQuote(
                    assetId: id,
                    price: 81678.42,
                    currency: 'USDT',
                    updatedAt: DateTime.now(),
                  ),
                },
                onChanged: (value) => setState(() => config = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Price display precision'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('price-format-compact-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compact K / M / B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('price-format-decimals-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 decimal').last);
    await tester.pumpAndSettle();
    expect(config.priceFormats[id]?.compact, true);
    expect(config.priceFormats[id]?.decimalPlaces, 1);
    expect(config.taskbar.profile.priceFormats, isEmpty);
    expect(find.text('Current display: 81.7K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
