import 'package:cryptofloat/data/currency_rates.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/unit_conversion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic conversion changes amount and actual unit together', () {
    final result = convertUnitValue(
      100,
      'USD',
      AppConfig.defaults.copyWith(displayCurrency: 'CNY'),
      {'USD': 1, 'CNY': 7},
    );
    expect(result.value, 700);
    expect(result.unit, 'CNY');
    expect(result.converted, isTrue);
    expect(result.error, isNull);
  });

  test('USDT and USDC use their real rates rather than a dollar peg', () {
    final config = AppConfig.defaults.copyWith(displayCurrency: 'USD');
    expect(convertUnitValue(10, 'USDT', config, {'USDT': 2}).value, 5);
    expect(convertUnitValue(10, 'USDC', config, {'USDC': 4}).value, 2.5);
  });

  test('missing or invalid rates preserve the original amount and unit', () {
    final config = AppConfig.defaults.copyWith(displayCurrency: 'CNY');
    for (final rates in <Map<String, double>>[
      {},
      {'CNY': 0},
      {'CNY': double.nan},
    ]) {
      final result = convertUnitValue(10, 'USD', config, rates);
      expect(result.value, 10);
      expect(result.unit, 'USD');
      expect(result.converted, isFalse);
      expect(result.error, isNotNull);
    }
    final stable = convertUnitValue(10, 'USDT', config, {'CNY': 7});
    expect(stable.unit, 'USDT');
    expect(stable.error, isNotNull);
  });

  test('manual source rule wins and supports non currency units', () {
    final config = AppConfig.defaults.copyWith(
      displayCurrency: 'USD',
      unitRules: const [
        UnitConversionRule(
          sourceUnit: ' ms ',
          targetUnit: 's',
          multiplier: 0.001,
        ),
      ],
    );
    final result = convertUnitValue(2500, 'MS', config, {});
    expect(result.value, 2.5);
    expect(result.unit, 's');
    expect(result.error, isNull);
  });

  test('global currency leaves non currency and unknown units unchanged', () {
    final config = AppConfig.defaults.copyWith(displayCurrency: 'CNY');
    for (final unit in ['°C', '%', 'ms', 'widgets', 'XYZ', '']) {
      final result = convertUnitValue(25, unit, config, {'CNY': 7});
      expect(result.value, 25);
      expect(result.unit, unit);
      expect(result.converted, isFalse);
      expect(result.error, isNull);
    }
  });

  test(
    'invalid manual rule cannot fall through into a misleading conversion',
    () {
      final config = AppConfig.defaults.copyWith(
        displayCurrency: 'CNY',
        unitRules: const [
          UnitConversionRule(
            sourceUnit: 'USD',
            targetUnit: 'CNY',
            multiplier: -1,
          ),
        ],
      );
      final result = convertUnitValue(10, 'USD', config, {'CNY': 7});
      expect(result.value, 10);
      expect(result.unit, 'USD');
      expect(result.error, isNotNull);
    },
  );

  test('original mode and matching target need no external rate', () {
    expect(convertUnitValue(0, 'USD', AppConfig.defaults, {}).value, 0);
    final same = convertUnitValue(
      10,
      'CNY',
      AppConfig.defaults.copyWith(displayCurrency: 'CNY'),
      {},
    );
    expect(same.value, 10);
    expect(same.unit, 'CNY');
    expect(same.error, isNull);
  });

  test('label modes only change the label of an actual unit', () {
    expect(displayUnitLabel('CNY', AppConfig.defaults), 'CNY');
    expect(displayUnitLabel('USDT', AppConfig.defaults), 'USDT');
    expect(
      displayUnitLabel(
        'USD',
        AppConfig.defaults.copyWith(unitLabelMode: 'compact'),
      ),
      r'$',
    );
    expect(
      displayUnitLabel(
        'USDT',
        AppConfig.defaults.copyWith(unitLabelMode: 'compact'),
      ),
      'U',
    );
    expect(
      displayUnitLabel(
        'USD',
        AppConfig.defaults.copyWith(
          unitLabelMode: 'custom',
          unitLabels: {'USD': '美金'},
        ),
      ),
      '美金',
    );
    expect(displayUnitLabel('widgets', AppConfig.defaults), 'widgets');
  });

  test(
    'USD rate response retains real stablecoin rates and rejects wrong base',
    () {
      final rates = parseUsdExchangeRates({
        'data': {
          'currency': 'USD',
          'rates': {'USD': '1', 'CNY': '7', 'USDT': '1.002'},
        },
      });
      expect(rates['USDT'], 1.002);
      expect(rates.containsKey('USDC'), isFalse);
      expect(
        () => parseUsdExchangeRates({
          'data': {
            'currency': 'EUR',
            'rates': {'USD': '1'},
          },
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'expired rate cache disables conversion without erasing cached values',
    () {
      final now = DateTime(2026, 10, 2, 12);
      final cached = {'USD': 1.0, 'CNY': 7.0};
      expect(
        usableExchangeRates(
          rates: cached,
          fetchedAt: now.subtract(const Duration(seconds: 300)),
          now: now,
        )['CNY'],
        7,
      );
      expect(
        usableExchangeRates(
          rates: cached,
          fetchedAt: now.subtract(const Duration(seconds: 301)),
          now: now,
        ),
        isEmpty,
      );
      expect(
        usableExchangeRates(rates: cached, fetchedAt: null, now: now),
        isEmpty,
      );
      expect(cached['CNY'], 7);
    },
  );
}
