import 'package:cryptofloat/domain/display_snapshot.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/system_metric.dart';
import 'package:cryptofloat/domain/display_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'OKX:BTC-USDT';
  test(
    'compact units round across boundaries and preserve low-priced decimals',
    () {
      const compact = PriceDisplayFormat(compact: true, decimalPlaces: 1);
      expect(formatPriceValue(81678.42, format: compact), '81.7K');
      expect(formatPriceValue(999960, format: compact), '1.0M');
      expect(formatPriceValue(1250000000, format: compact), '1.3B');
      expect(formatPriceValue(-81678.42, format: compact), '-81.7K');
      expect(
        formatPriceValue(
          0.00012345,
          format: const PriceDisplayFormat(compact: true, decimalPlaces: 8),
        ),
        '0.00012345',
      );
      expect(
        formatPriceValue(
          81678.42,
          format: const PriceDisplayFormat(decimalPlaces: 0),
        ),
        '81,678',
      );
      expect(formatPriceValue(null, format: compact), '—');
      expect(formatPriceValue(double.nan, format: compact), '—');
      expect(formatPriceValue(81678.42), '81,678.42');
    },
  );

  test(
    'converted price uses selected precision; template explicit format wins',
    () {
      final view = AppConfig.defaults.copyWith(
        selectedAssetIds: [id],
        priceFormats: {
          id: const PriceDisplayFormat(compact: true, decimalPlaces: 1),
        },
        unitRules: const [
          UnitConversionRule(
            sourceUnit: 'USDT',
            targetUnit: 'USD',
            multiplier: 2,
          ),
        ],
      );
      final quote = MarketQuote(
        assetId: id,
        price: 81678.42,
        currency: 'USDT',
        updatedAt: DateTime.now(),
      );
      final cells = buildDisplayTexts(view, {
        id: quote,
      }, const SystemMetricSnapshot());
      expect(cells.single.value, '163.4K');
      expect(cells.single.unit, 'USD');
      expect(
        renderSegment(
          const DisplaySegment.field(assetId: id, fieldId: 'price'),
          view,
          {id: quote},
        ),
        '163.4K',
      );
      expect(
        renderSegment(
          const DisplaySegment.field(
            assetId: id,
            fieldId: 'price',
            format: '.2f',
          ),
          view,
          {id: quote},
        ),
        '163,356.84',
      );
    },
  );
  test(
    'BTC compact precision changes display without changing source price',
    () {
      final base = AppConfig.defaults.copyWith(selectedAssetIds: [id]);
      final json = base.toJson();
      (json['display'] as Map)['priceFormats'] = {
        id: {'compact': true, 'decimalPlaces': 1},
      };
      final view = AppConfig.fromJson(json);
      final quote = MarketQuote(
        assetId: id,
        price: 81678.42,
        currency: 'USDT',
        updatedAt: DateTime.now(),
        changePercent: -2.5,
      );
      final cells = buildDisplayTexts(view, {
        id: quote,
      }, const SystemMetricSnapshot());
      expect(cells.single.value, '81.7K');
      expect(cells.single.change, -2.5);
      expect(quote.price, 81678.42);
    },
  );
}
