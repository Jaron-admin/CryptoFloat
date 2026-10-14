import 'package:cryptofloat/app/market_change_colors.dart';
import 'package:cryptofloat/app/theme_presets.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/refresh_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  MarketQuote quote(String id, double? price, DateTime updatedAt, {String? error}) =>
      MarketQuote(
        assetId: id,
        price: price,
        currency: 'USDT',
        updatedAt: updatedAt,
        changePercent: 2.5,
        error: error,
      );

  test('the first successful refresh is neutral and later ticks compare with it', () {
    var memory = const RefreshPriceMemory();
    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0,
      price: 100,
      successful: true,
    );
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.neutral);
    expect(memory.baselineFor('OKX:BTC-USDT'), 100);

    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 15)),
      price: 110,
      successful: true,
    );
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.up);

    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 30)),
      price: 90,
      successful: true,
    );
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.down);
    expect(memory.baselineFor('OKX:BTC-USDT'), 90);
  });

  test('a failed refresh keeps the last successful baseline', () {
    var memory = const RefreshPriceMemory().observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0,
      price: 100,
      successful: true,
    );
    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 15)),
      price: 50,
      successful: false,
    );
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.neutral);
    expect(memory.baselineFor('OKX:BTC-USDT'), 100);

    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 30)),
      price: 80,
      successful: true,
    );
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.down);
  });

  test('an unchanged price and a repeated sample stay neutral or unchanged', () {
    var memory = const RefreshPriceMemory().observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0,
      price: 100,
      successful: true,
    );
    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 15)),
      price: 100,
      successful: true,
    );
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.neutral);

    memory = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 30)),
      price: 120,
      successful: true,
    );
    final again = memory.observe(
      id: 'OKX:BTC-USDT',
      updatedAt: t0.add(const Duration(seconds: 30)),
      price: 1,
      successful: true,
    );
    expect(again.tickFor('OKX:BTC-USDT'), PriceTick.up);
    expect(again.baselineFor('OKX:BTC-USDT'), 120);
  });

  test('a different symbol starts neutral and leaving the list clears its baseline', () {
    final btc = quote('OKX:BTC-USDT', 100, t0);
    final higher = quote('OKX:BTC-USDT', 130, t0.add(const Duration(seconds: 15)));
    final eth = quote('OKX:ETH-USDT', 20, t0.add(const Duration(seconds: 15)));
    var memory = const RefreshPriceMemory().observeAll({'OKX:BTC-USDT': btc});
    memory = memory.observeAll({'OKX:BTC-USDT': higher, 'OKX:ETH-USDT': eth});
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.up);
    expect(memory.tickFor('OKX:ETH-USDT'), PriceTick.neutral);

    memory = memory.observeAll({'OKX:ETH-USDT': eth});
    expect(memory.baselineFor('OKX:BTC-USDT'), isNull);
    memory = memory.observeAll({'OKX:BTC-USDT': higher});
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.neutral);
  });

  test('quote errors do not move the baseline even when a stale price is retained', () {
    final first = quote('OKX:BTC-USDT', 100, t0);
    final failed = quote(
      'OKX:BTC-USDT',
      100,
      t0,
      error: 'offline',
    );
    var memory = const RefreshPriceMemory().observeAll({'OKX:BTC-USDT': first});
    memory = memory.observeAll({'OKX:BTC-USDT': failed});
    expect(memory.baselineFor('OKX:BTC-USDT'), 100);
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.neutral);

    final next = quote('OKX:BTC-USDT', 140, t0.add(const Duration(seconds: 15)));
    memory = memory.observeAll({'OKX:BTC-USDT': next});
    expect(memory.tickFor('OKX:BTC-USDT'), PriceTick.up);
  });

  test('plain mode and a neutral tick use theme text; red and green follow the tick', () {
    const neutral = Color(0xFF242424);
    const theme = MarketColors(positive: Colors.purple, negative: Colors.orange);
    Color color(String mode, PriceTick tick) => priceTickColor(
      priceColorMode: mode,
      tick: tick,
      neutral: neutral,
      brightness: Brightness.light,
      themeColors: theme,
    );

    expect(color('plain', PriceTick.up), neutral);
    expect(color('redUp', PriceTick.neutral), neutral);
    expect(color('redUp', PriceTick.up), const Color(0xFFC50F1F));
    expect(color('redUp', PriceTick.down), const Color(0xFF107C10));
    expect(color('greenUp', PriceTick.up), const Color(0xFF107C10));
    expect(color('greenUp', PriceTick.down), const Color(0xFFC50F1F));
    expect(color('theme', PriceTick.up), Colors.purple);
    expect(color('theme', PriceTick.down), Colors.orange);
  });

  test('taskbar colors asset prices from the tick and leaves other cells in theme text', () {
    const foreground = Color(0xFF111111);
    const secondary = Color(0xFF888888);
    const theme = MarketColors(positive: Color(0xFF107C10), negative: Color(0xFFC50F1F));
    Color cell(String id, {bool stale = false, PriceTick tick = PriceTick.up}) =>
        taskbarPriceColor(
          cellId: id,
          stale: stale,
          priceColorMode: 'greenUp',
          tick: tick,
          foreground: foreground,
          secondary: secondary,
          brightness: Brightness.light,
          themeColors: theme,
        );

    expect(cell('asset:OKX:BTC-USDT'), const Color(0xFF107C10));
    expect(cell('asset:OKX:BTC-USDT', tick: PriceTick.down), const Color(0xFFC50F1F));
    expect(cell('asset:OKX:BTC-USDT', tick: PriceTick.neutral), foreground);
    expect(cell('asset:OKX:BTC-USDT', stale: true), secondary);
    expect(cell('metric:cpu.usage'), foreground);
    expect(
      taskbarPriceColor(
        cellId: 'asset:OKX:BTC-USDT',
        stale: false,
        priceColorMode: 'plain',
        tick: PriceTick.up,
        foreground: foreground,
        secondary: secondary,
        brightness: Brightness.light,
        themeColors: theme,
      ),
      foreground,
    );
  });

  test('price color mode is shared and old files keep their saved convention', () {
    expect(AppConfig.defaults.priceColorMode, 'theme');
    final legacy = AppConfig.fromJson({
      'schemaVersion': 2,
      'display': {'marketColorStyle': 'redUp'},
    });
    expect(legacy.priceColorMode, 'redUp');
    final chosen = AppConfig.fromJson({
      'schemaVersion': 2,
      'priceColorMode': 'plain',
      'display': {'marketColorStyle': 'redUp'},
    });
    expect(chosen.priceColorMode, 'plain');
    expect(
      AppConfig.fromJson({
        'schemaVersion': 2,
        'priceColorMode': 'rainbow',
      }).priceColorMode,
      'theme',
    );

    final shared = AppConfig.defaults.copyWith(priceColorMode: 'greenUp');
    final taskbarEdit = shared.withDisplay(
      DisplayTarget.taskbar,
      shared.displayFor(DisplayTarget.taskbar).copyWith(fontSize: 18),
    );
    expect(taskbarEdit.priceColorMode, 'greenUp');
    expect(taskbarEdit.taskbar.profile.fontSize, 18);
    expect(
      taskbarEdit.displayFor(DisplayTarget.floating).priceColorMode,
      'greenUp',
    );
    expect(
      taskbarEdit.displayFor(DisplayTarget.taskbar).priceColorMode,
      'greenUp',
    );

    final switched = taskbarEdit.withDisplay(
      DisplayTarget.taskbar,
      taskbarEdit
          .displayFor(DisplayTarget.taskbar)
          .copyWith(priceColorMode: 'plain'),
    );
    expect(switched.priceColorMode, 'plain');
    expect(AppConfig.fromJson(switched.toJson()).priceColorMode, 'plain');
  });
}
