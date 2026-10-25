import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/domain/display_formatter.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/features/panel/display_row_view.dart';
import 'package:cryptofloat/platform/floating_window_host.dart';
import 'package:cryptofloat/platform/secret_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart' show SettingsCatalog;
import 'support/settings_navigation.dart';

void main() {
  AppController createController(_MemoryConfigStore store, _WindowHost host) =>
      AppController(
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: ['OKX:BTC-USDT'],
          language: 'zh',
          proxyEnabled: false,
        ),
        store: store,
        host: host,
        secrets: _MemorySecrets(),
        assetCatalog: SettingsCatalog(),
      );

  testWidgets('menu dismisses on a click inside the panel outside the menu', (
    tester,
  ) async {
    final controller = createController(_MemoryConfigStore(), _WindowHost());
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('panel-title')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('立即刷新'), findsOneWidget);
    await tester.tapAt(const Offset(8, 580));
    await tester.pumpAndSettle();
    expect(find.text('立即刷新'), findsNothing);
    expect(find.byKey(const ValueKey('panel-title')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'saving a different system number font returns to the active panel',
    (tester) async {
      final store = _MemoryConfigStore();
      final host = _WindowHost();
      final controller = createController(store, host);
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('panel-title')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      await revealSetting(tester, settingsFontPicker(numbers: true));
      await tester.tap(settingsFontPicker(numbers: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consolas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回悬浮窗'));
      await tester.pumpAndSettle();
      expect(store.saved?.numberFontFamily, 'Consolas');
      expect(host.closed, isFalse);
      expect(host.settingsModes, [true, false]);
      expect(find.byKey(const ValueKey('panel-title')), findsOneWidget);
      expect(find.text('USDT'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == '—' &&
              widget.style?.fontFamily == 'Consolas',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('free text, units, decimal signs and never-updated timestamps stay readable', () {
    const source = CustomApiSource(
      id: 'weather',
      name: '天气',
      url: 'https://example.com/api',
      fields: [
        CustomField(
          id: 'temperature',
          label: '温度',
          path: 'data.temp',
          unit: '°C',
        ),
      ],
    );
    final config = AppConfig.defaults.copyWith(customSources: [source]);
    final quote = MarketQuote(
      assetId: 'custom:weather',
      price: null,
      currency: '',
      updatedAt: DateTime.now(),
      extra: {'temperature': 23.5},
    );
    const row = DisplayRow(
      id: 'weather-line',
      segments: [
        DisplaySegment.literal('室外温度：'),
        DisplaySegment.field(
          assetId: 'custom:weather',
          fieldId: 'temperature',
          format: '.2f',
        ),
      ],
    );
    expect(renderRow(row, config, {'custom:weather': quote}), '室外温度：23.50 °C');
    expect(formatValue(1234567.89, '.2f'), '1,234,567.89');
    expect(formatValue(-0.37, '+.2f'), '-0.37');
    expect(formatValue(0.37, '+.2f'), '+0.37');
    expect(formatValue('00123', 'raw'), '00123');
    expect(formatValue('000123'), '000123');
    expect(formatValue(DateTime.fromMillisecondsSinceEpoch(0)), '未更新');
  });
  test(
    'a committed configuration survives a native appearance failure',
    () async {
      final store = _MemoryConfigStore();
      final host = _WindowHost()..failAppearance = true;
      final controller = createController(store, host);
      addTearDown(controller.dispose);
      const source = CustomApiSource(
        id: 'protected',
        name: '我的 API',
        url: 'https://example.com/data',
        secretHeaderRefs: {'Authorization': 'saved-key'},
        fields: [CustomField(id: 'balance', label: '余额', path: 'data.balance')],
      );
      await expectLater(
        controller.apply(controller.config.copyWith(customSources: [source])),
        completes,
      );
      expect(
        store.saved?.customSources.single.secretHeaderRefs['Authorization'],
        'saved-key',
      );
      expect(
        controller
            .config
            .customSources
            .single
            .secretHeaderRefs['Authorization'],
        'saved-key',
      );
      expect(host.closed, isFalse);
    },
  );

  testWidgets(
    'free rows mark failed sources and keep text and numeric fonts separate',
    (tester) async {
      final controller = AppController(
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: ['OKX:BTC-USDT'],
          proxyEnabled: false,
          fontFamily: 'Segoe UI',
          numberFontFamily: 'Consolas',
          displayRows: [
            const DisplayRow(
              id: 'row',
              segments: [
                DisplaySegment.literal('观察 '),
                DisplaySegment.field(assetId: 'OKX:BTC-USDT', fieldId: 'name'),
                DisplaySegment.literal(' '),
                DisplaySegment.field(assetId: 'OKX:BTC-USDT', fieldId: 'price'),
              ],
            ),
          ],
        ),
        store: _MemoryConfigStore(),
        host: _WindowHost(),
        secrets: _MemorySecrets(),
      );
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      expect(controller.data.quotes.values.single.isStale, isTrue);
      expect(
        find.descendant(
          of: find.byType(DisplayRowView),
          matching: find.byIcon(Icons.error_outline),
        ),
        findsOneWidget,
      );
      final rich = tester.widget<RichText>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().startsWith('观察 '),
            )
            .first,
      );
      final spans = _leafSpans(rich.text).toList();
      expect(spans[1].style?.fontFamily, 'Segoe UI');
      expect(spans[3].style?.fontFamily, 'Consolas');
    },
  );

  testWidgets(
    'a manually added Binance quote preserves the actual quote currency',
    (tester) async {
      final store = _MemoryConfigStore();
      final controller = createController(store, _WindowHost());
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('panel-title')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('添加代码'));
      await tester.tap(find.text('添加代码'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Binance').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        'ETHBTC',
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回悬浮窗'));
      await tester.pumpAndSettle();
      expect(store.saved?.customAssets.single.currency, 'BTC');
    },
  );
}

class _MemoryConfigStore extends ConfigStore {
  AppConfig? saved;
  @override
  Future<void> save(AppConfig config) async => saved = config;
}

Iterable<TextSpan> _leafSpans(InlineSpan span) sync* {
  if (span is TextSpan) {
    if (span.text != null && span.text!.isNotEmpty) yield span;
    for (final child in span.children ?? <InlineSpan>[]) {
      yield* _leafSpans(child);
    }
  }
}

class _MemorySecrets implements SecretStore {
  final Map<String, String> _values = {};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class _WindowHost implements FloatingWindowHost {
  bool closed = false;
  bool failAppearance = false;
  final List<bool> settingsModes = [];
  @override
  bool get supported => false;
  @override
  Future<void> initialize({
    WindowBounds? bounds,
    bool alwaysOnTop = true,
    double opacity = 0.96,
  }) async {}
  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (failAppearance) throw StateError('window appearance unavailable');
  }

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
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<List<String>> getSystemFonts() async => ['Segoe UI', 'Consolas'];
  @override
  Future<void> setSettingsMode(bool enabled) async {
    settingsModes.add(enabled);
  }
}
