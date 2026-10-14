import 'package:cryptofloat/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('per-asset compact precision persists independently by display', () {
    final loaded = AppConfig.fromJson({
      'schemaVersion': 2,
      'display': {
        'priceFormats': {
          'OKX:BTC-USDT': {'compact': true, 'decimalPlaces': 1},
        },
      },
      'taskbar': {
        'profile': {
          'priceFormats': {
            'OKX:BTC-USDT': {'compact': false, 'decimalPlaces': 4},
          },
        },
      },
    });
    final edited = loaded.withDisplay(
      DisplayTarget.taskbar,
      loaded.displayFor(DisplayTarget.taskbar).copyWith(fontSize: 18),
    );
    final saved = AppConfig.fromJson(edited.toJson()).toJson();
    expect((saved['display'] as Map)['priceFormats'], {
      'OKX:BTC-USDT': {'compact': true, 'decimalPlaces': 1},
    });
    expect(((saved['taskbar'] as Map)['profile'] as Map)['priceFormats'], {
      'OKX:BTC-USDT': {'compact': false, 'decimalPlaces': 4},
    });
  });

  test(
    'spacing and overflow preferences survive profile switching and reload',
    () {
      final loaded = AppConfig.fromJson({
        'schemaVersion': 2,
        'display': {'panelLabelValueGap': 3.5, 'panelColumnGap': 9.0},
        'taskbar': {
          'labelValueGap': 2,
          'overflowMode': 'manual',
          'carouselIntervalSeconds': 12,
          'profile': {'panelLabelValueGap': 6.0, 'panelColumnGap': 14.0},
        },
      });
      final edited = loaded.withDisplay(
        DisplayTarget.taskbar,
        loaded.displayFor(DisplayTarget.taskbar).copyWith(fontSize: 18),
      );
      final saved = AppConfig.fromJson(edited.toJson()).toJson();
      expect((saved['display'] as Map)['panelLabelValueGap'], 3.5);
      expect((saved['display'] as Map)['panelColumnGap'], 9.0);
      final taskbar = saved['taskbar'] as Map;
      expect(taskbar['labelValueGap'], 2);
      expect(taskbar['overflowMode'], 'manual');
      expect(taskbar['carouselIntervalSeconds'], 12);
      expect((taskbar['profile'] as Map)['panelLabelValueGap'], 6.0);
      expect((taskbar['profile'] as Map)['panelColumnGap'], 14.0);
    },
  );

  test(
    'old settings receive compact defaults and malformed gaps are bounded',
    () {
      final old = AppConfig.fromJson({'schemaVersion': 2}).toJson();
      expect((old['display'] as Map)['panelLabelValueGap'], 8.0);
      expect((old['display'] as Map)['panelColumnGap'], 12.0);
      expect((old['taskbar'] as Map)['labelValueGap'], 4);
      expect((old['taskbar'] as Map)['overflowMode'], 'auto');
      expect((old['taskbar'] as Map)['carouselIntervalSeconds'], 5);
      final invalid = AppConfig.fromJson({
        'schemaVersion': 2,
        'display': {'panelLabelValueGap': -5, 'panelColumnGap': 900},
        'taskbar': {
          'labelValueGap': 900,
          'overflowMode': 'invalid',
          'carouselIntervalSeconds': 0,
          'profile': {'panelLabelValueGap': double.nan, 'panelColumnGap': -4},
        },
      }).toJson();
      expect((invalid['display'] as Map)['panelLabelValueGap'], 0.0);
      expect((invalid['display'] as Map)['panelColumnGap'], 48.0);
      final taskbar = invalid['taskbar'] as Map;
      expect(taskbar['labelValueGap'], 24);
      expect(taskbar['overflowMode'], 'auto');
      expect(taskbar['carouselIntervalSeconds'], 2);
      expect((taskbar['profile'] as Map)['panelLabelValueGap'], 8.0);
      expect((taskbar['profile'] as Map)['panelColumnGap'], 0.0);
    },
  );
}
