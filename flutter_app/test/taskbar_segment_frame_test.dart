import 'package:cryptofloat/domain/display_snapshot.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/app/market_change_colors.dart';
import 'package:cryptofloat/app/theme_presets.dart';
import 'package:cryptofloat/domain/refresh_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('price rising with a negative 24h result uses opposite colors', () {
    final config = AppConfig.defaults.copyWith(
      priceColorMode: 'greenUp',
      marketColorStyle: 'greenUp',
    );
    const palette = MarketColors(positive: Colors.green, negative: Colors.red);
    final frame = buildTaskbarFrame(
      config: config.taskbar,
      chinese: false,
      cells: const [DisplayText('BTC', '100', change: -2.5)],
      background: 0xff000000,
      foreground: 0xffffffff,
      colorFor: (_) => priceTickColor(
        priceColorMode: config.priceColorMode,
        tick: PriceTick.up,
        neutral: Colors.white,
        brightness: Brightness.light,
        themeColors: palette,
      ).toARGB32(),
      suffixColorFor: (cell) => marketChangeColorValue(
        change: cell.change,
        config: config,
        neutral: Colors.grey,
        brightness: Brightness.light,
        themeColors: palette,
      ).toARGB32(),
    );
    final cell = (frame['cells'] as List).single as Map;
    expect(cell['color'], const Color(0xFF107C10).toARGB32());
    expect(cell['suffixColor'], const Color(0xFFC50F1F).toARGB32());
    expect(
      marketChangeColorValue(
        change: -2.5,
        config: config.copyWith(priceColorMode: 'plain'),
        neutral: Colors.grey,
        brightness: Brightness.light,
        themeColors: palette,
      ),
      const Color(0xFFC50F1F),
    );
  });

  test(
    'frame separates label, price and 24h percentage for native rendering',
    () {
      final frame = buildTaskbarFrame(
        config: const TaskbarConfig(),
        chinese: false,
        cells: const [
          DisplayText(
            'BTC-USDT',
            '91,000',
            id: 'asset:OKX:BTC-USDT',
            unit: 'USDT',
            change: -2.5,
          ),
        ],
        background: 0xff000000,
        foreground: 0xffffffff,
        colorFor: (_) => 0xff00ff00,
      );
      final cell = (frame['cells'] as List).single as Map;
      expect(cell['label'], 'BTC');
      expect(cell['value'], '91,000 USDT');
      expect(cell['suffix'], '-2.50%');
      expect(cell['color'], 0xff00ff00);
      expect(cell['suffixColor'], 0xffffffff);
    },
  );

  test('all ordinary overflow cells remain available to the carousel', () {
    final source = List.generate(80, (i) => DisplayText('Item $i', '$i'));
    final shown = taskbarVisibleCells(source, chinese: false);
    expect(shown.length, 80);
    expect(shown.last.label, 'Item 79');
  });

  test('large multibyte frames stay inside the native IPC budget', () {
    final longText = List.filled(400, '测试😀').join();
    final frame = buildTaskbarFrame(
      config: const TaskbarConfig(),
      chinese: true,
      cells: List.generate(
        256,
        (i) => DisplayText(
          '$i$longText',
          longText,
          unit: longText,
          change: -12.25,
        ),
      ),
      background: 0xff000000,
      foreground: 0xffffffff,
    );
    final cells = frame['cells'] as List;
    expect(cells.length, 256);
    var bytes =
        68 +
        2 *
            ((frame['fontFamily'] as String).length +
                (frame['numberFontFamily'] as String).length);
    for (final cell in cells.cast<Map>()) {
      bytes += 32;
      for (final field in ['text', 'tooltip', 'label', 'value', 'suffix']) {
        final value = cell[field] as String;
        bytes += 2 * value.length;
        expect(value.runes, isNot(contains(0xfffd)));
      }
    }
    expect(bytes, lessThanOrEqualTo(65520));
  });
}
