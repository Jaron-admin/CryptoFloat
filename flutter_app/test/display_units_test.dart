import 'package:cryptofloat/domain/display_formatter.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/unit_conversion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 2);
  final quotes = {
    'OKX:BTC-USDT': MarketQuote(
      assetId: 'OKX:BTC-USDT',
      price: 10,
      currency: 'USDT',
      updatedAt: now,
    ),
  };
  const currency = DisplaySegment.field(
    assetId: 'OKX:BTC-USDT',
    fieldId: 'currency',
  );
  test('invalid saved multiplier never silently relabels money one to one', () {
    for (final invalid in [null, 'NaN', 'Infinity', 'invalid']) {
      final rule = UnitConversionRule.fromJson({
        'sourceUnit': 'USD',
        'targetUnit': 'CNY',
        'multiplier': invalid,
      });
      final result = convertUnitValue(
        10,
        'USD',
        AppConfig.defaults.copyWith(unitRules: [rule]),
        const {'CNY': 7},
      );
      expect(result.value, 10);
      expect(result.unit, 'USD');
      expect(result.converted, false);
      expect(result.error, isNotNull);
    }
  });
  test('built in currency field follows compact labels', () {
    expect(
      renderSegment(
        currency,
        AppConfig.defaults.copyWith(unitLabelMode: 'compact'),
        quotes,
      ),
      'U',
    );
  });
  test('display row price and currency use the same usable exchange rates', () {
    final config = AppConfig.defaults.copyWith(
      displayCurrency: 'CNY',
      unitLabelMode: 'custom',
      unitLabels: {'CNY': '元'},
    );
    const row = DisplayRow(
      id: 'price',
      segments: [
        DisplaySegment.field(
          assetId: 'OKX:BTC-USDT',
          fieldId: 'price',
          format: '.2f',
        ),
        DisplaySegment.literal(' '),
        currency,
      ],
    );
    expect(
      renderRow(row, config, quotes, rates: const {'USDT': 2, 'CNY': 7}),
      '35.00 元',
    );
    expect(renderRow(row, config, quotes), '10.00 USDT');
    expect(quotes.values.single.price, 10);
    expect(quotes.values.single.currency, 'USDT');
  });
  test('custom field manual conversion changes amount and unit together', () {
    final config = AppConfig.defaults.copyWith(
      customSources: [
        const CustomApiSource(
          id: 'weight',
          name: '重量',
          url: 'https://example.com',
          fields: [
            CustomField(id: 'mass', label: '重量', path: 'mass', unit: 'kg'),
          ],
        ),
      ],
      unitRules: [
        const UnitConversionRule(
          sourceUnit: 'kg',
          targetUnit: 'g',
          multiplier: 1000,
        ),
      ],
    );
    final data = {
      'custom:weight': MarketQuote(
        assetId: 'custom:weight',
        price: null,
        currency: '',
        updatedAt: now,
        extra: {'mass': 1.5},
      ),
    };
    expect(
      renderSegment(
        const DisplaySegment.field(
          assetId: 'custom:weight',
          fieldId: 'mass',
          format: '.2f',
        ),
        config,
        data,
      ),
      '1,500.00 g',
    );
  });
}
