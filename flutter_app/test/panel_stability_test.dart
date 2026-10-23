import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/data/system_metrics_service.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/refresh_price.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/platform/floating_window_host.dart';
import 'package:cryptofloat/platform/system_metrics_host.dart';
import 'package:cryptofloat/platform/secret_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live numbers change width all the time (a network speed switches between
/// "999.9 KiB/s" and "1.0 MiB/s"). Nothing around them may move because of it.
void main() {
  for (final layout in ['horizontal', 'vertical']) {
    testWidgets('$layout panel stays pinned while a value grows', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(520, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _Controller(
        AppConfig.defaults.copyWith(
          panelItemLayout: layout,
          selectedAssetIds: ['OKX:BTC-USDT', 'OKX:ETH-USDT'],
          showChangePercent: false,
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();

      const btc = ValueKey('panel-asset:OKX:BTC-USDT');
      const eth = ValueKey('panel-asset:OKX:ETH-USDT');
      final btcCell = tester.getTopLeft(find.byKey(btc));
      final ethCell = tester.getTopLeft(find.byKey(eth));
      // A panel narrower than the window stays at the panel's left edge: it must
      // never be re-centred around the current text width.
      expect(btcCell.dx, 12);
      expect(ethCell.dx, 12);

      controller.setPrice('OKX:BTC-USDT', 1234567.89);
      await tester.pumpAndSettle();

      expect(find.text('1,234,567.89'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(btc)), btcCell);
      final ethAfter = tester.getTopLeft(find.byKey(eth));
      expect(ethAfter.dx, ethCell.dx);
      // The test font rounds line heights by a fraction of a pixel; the point
      // is that a wider number never moves a row by a whole entry.
      expect(ethAfter.dy, closeTo(ethCell.dy, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$layout price and unit stay put when a 24h change appears', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(520, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _Controller(
        AppConfig.defaults.copyWith(
          panelItemLayout: layout,
          selectedAssetIds: ['OKX:BTC-USDT', 'OKX:ETH-USDT'],
          showChangePercent: true,
        ),
        quotes: _quotes(changePercent: null),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();

      const btc = ValueKey('panel-asset:OKX:BTC-USDT');
      final priceRight = tester.getRect(find.text('101.00')).right;
      final unitLeft = tester.getRect(_unit(btc)).left;

      // "—" and "+2.50%" share one reserved slot, so neither the price nor the
      // unit moves when the first quote with a change arrives.
      controller.setPrice('OKX:BTC-USDT', 101, changePercent: 2.5);
      await tester.pumpAndSettle();

      expect(find.text('+2.50%'), findsOneWidget);
      expect(tester.getRect(find.text('101.00')).right, priceRight);
      expect(tester.getRect(_unit(btc)).left, unitLeft);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a network speed switching units keeps both columns in place', (
    tester,
  ) async {
    // Wide enough that the column is not clamped: its width follows the
    // widest value in it.
    await tester.binding.setSurfaceSize(const Size(900, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final metrics = _MetricsHost()..sample(download: 999.9 * 1024);
    final controller = _Controller(
      AppConfig.defaults.copyWith(
        panelColumnCount: 2,
        selectedAssetIds: [],
        selectedMetricIds: ['network.download', 'network.upload'],
        showChangePercent: false,
      ),
      metricsService: SystemMetricsService(host: metrics),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await controller.metrics.refresh();
    await tester.pumpAndSettle();

    const download = ValueKey('panel-metric:network.download');
    const upload = ValueKey('panel-metric:network.upload');
    expect(find.text('999.9 KiB/s'), findsOneWidget);
    final downloadCell = tester.getTopLeft(find.byKey(download));
    final uploadCell = tester.getTopLeft(find.byKey(upload));
    final valueRight = tester.getRect(find.text('999.9 KiB/s')).right;

    // 999.9 KiB/s and 1.5 MiB/s differ by two characters. The reserved slot
    // must absorb that, or the second column slides on every speed change.
    metrics.sample(download: 1.5 * 1024 * 1024);
    await controller.metrics.refresh();
    await tester.pumpAndSettle();

    expect(find.text('1.5 MiB/s'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(download)), downloadCell);
    expect(tester.getTopLeft(find.byKey(upload)), uploadCell);
    expect(tester.getRect(find.text('1.5 MiB/s')).right, valueRight);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a stale source does not shift the numbers beside it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _Controller(
      AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT', 'OKX:ETH-USDT'],
        showChangePercent: true,
      ),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();

    const btc = ValueKey('panel-asset:OKX:BTC-USDT');
    final priceRight = tester.getRect(find.text('101.00')).right;
    final unitLeft = tester.getRect(_unit(btc)).left;

    controller.markStale('OKX:BTC-USDT');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(tester.getRect(find.text('101.00')).right, priceRight);
    expect(tester.getRect(_unit(btc)).left, unitLeft);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _unit(ValueKey<String> cell) =>
    find.descendant(of: find.byKey(cell), matching: find.text('USDT'));

Map<String, MarketQuote> _quotes({double? changePercent = 2.5}) => {
  'OKX:BTC-USDT': MarketQuote(
    assetId: 'OKX:BTC-USDT',
    price: 101,
    changePercent: changePercent,
    currency: 'USDT',
    updatedAt: DateTime.now(),
  ),
  'OKX:ETH-USDT': MarketQuote(
    assetId: 'OKX:ETH-USDT',
    price: 2000,
    changePercent: changePercent,
    currency: 'USDT',
    updatedAt: DateTime.now(),
  ),
};

class _Controller extends AppController {
  _Controller(
    AppConfig config, {
    Map<String, MarketQuote>? quotes,
    super.metricsService,
  }) : quotes = quotes ?? _quotes(),
       super(
         config: config.copyWith(language: 'en', proxyEnabled: false),
         store: _Store(),
         host: _Host(),
         secrets: _Secrets(),
       );
  final Map<String, MarketQuote> quotes;

  void setPrice(String id, double price, {double? changePercent}) {
    final quote = quotes[id]!;
    quotes[id] = MarketQuote(
      assetId: id,
      price: price,
      changePercent: changePercent ?? quote.changePercent,
      currency: quote.currency,
      updatedAt: quote.updatedAt.add(const Duration(seconds: 15)),
    );
    notifyListeners();
  }

  void markStale(String id) {
    final quote = quotes[id]!;
    quotes[id] = MarketQuote(
      assetId: id,
      price: quote.price,
      changePercent: quote.changePercent,
      currency: quote.currency,
      updatedAt: quote.updatedAt,
      error: 'network_unreachable',
    );
    notifyListeners();
  }

  @override
  PriceTick priceTickFor(String assetId) => PriceTick.neutral;

  @override
  Map<String, MarketQuote> get displayQuotes => quotes;
}

class _MetricsHost implements SystemMetricsHost {
  double _download = 0;
  double _upload = 0;

  void sample({required double download, double upload = 0}) {
    _download = download;
    _upload = upload;
  }

  @override
  bool get supported => true;

  @override
  Future<void> configure(Map<String, Object?> options) async {}

  @override
  Future<Map<Object?, Object?>> read() async => {
    'values': {
      'network.download': {'value': _download, 'unit': 'B/s', 'state': 'valid'},
      'network.upload': {'value': _upload, 'unit': 'B/s', 'state': 'valid'},
    },
    'sampledAtMs': DateTime.now().millisecondsSinceEpoch,
  };
}

class _Store extends ConfigStore {
  @override
  Future<void> save(AppConfig config) async {}
}

class _Secrets implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Host implements FloatingWindowHost {
  @override
  bool get supported => false;
  @override
  Future<void> initialize({
    WindowBounds? bounds,
    bool alwaysOnTop = true,
    double opacity = .96,
  }) async {}
  @override
  Future<void> setAlwaysOnTop(bool value) async {}
  @override
  Future<void> setOpacity(double value) async {}
  @override
  Future<WindowBounds?> getBounds() async => null;
  @override
  Future<void> setBounds(WindowBounds bounds) async {}
  @override
  Future<void> beginDrag() async {}
  @override
  Future<void> beginResize(String edge) async {}
  @override
  Future<void> setSettingsMode(bool enabled) async {}
  @override
  Future<void> close() async {}
  @override
  Future<List<String>> getSystemFonts() async => ['Segoe UI'];
}
