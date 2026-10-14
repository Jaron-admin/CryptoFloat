import 'dart:io';

import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/app/market_change_colors.dart';
import 'package:cryptofloat/app/theme_presets.dart';
import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/platform/floating_window_host.dart';
import 'package:cryptofloat/platform/secret_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old and invalid settings keep safe panel layout defaults', () {
    final old = AppConfig.fromJson({'schemaVersion': 2});
    expect(old.panelColumnCount, 1);
    expect(old.panelItemLayout, 'horizontal');
    expect(old.showChangePercent, isTrue);
    expect(old.marketColorStyle, 'theme');
    final invalid = AppConfig.fromJson({
      'schemaVersion': 2,
      'display': {
        'panelColumnCount': 900,
        'panelItemLayout': 'bad',
        'showChangePercent': 'no',
        'marketColorStyle': 'bad',
      },
    });
    expect(invalid.panelColumnCount, 8);
    expect(invalid.panelItemLayout, 'horizontal');
    expect(invalid.showChangePercent, isTrue);
    expect(invalid.marketColorStyle, 'theme');
  });

  testWidgets(
    'theme colors stay custom and missing or unchanged quotes stay neutral',
    (tester) async {
      const custom = MarketColors(
        positive: Colors.purple,
        negative: Colors.orange,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [custom]),
          home: Builder(
            builder: (context) {
              final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
              expect(
                marketChangeColor(context, AppConfig.defaults, 2),
                Colors.purple,
              );
              expect(
                marketChangeColor(context, AppConfig.defaults, -2),
                Colors.orange,
              );
              for (final value in <num?>[null, 0, double.nan]) {
                expect(
                  marketChangeColor(
                    context,
                    AppConfig.defaults.copyWith(marketColorStyle: 'redUp'),
                    value,
                  ),
                  neutral,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      for (final convention in ['greenUp', 'redUp']) {
        final colors = resolveMarketChangeColors(
          AppConfig.defaults.copyWith(marketColorStyle: convention),
          brightness: Brightness.light,
          themeColors: custom,
        );
        expect(
          colors.positive,
          convention == 'greenUp'
              ? const Color(0xFF107C10)
              : const Color(0xFFC50F1F),
        );
        expect(
          colors.negative,
          convention == 'greenUp'
              ? const Color(0xFFC50F1F)
              : const Color(0xFF107C10),
        );
      }
    },
  );

  test('layout choices survive saving with separate taskbar choices', () async {
    final directory = await Directory.systemTemp.createTemp('panel_layout_');
    addTearDown(() => directory.delete(recursive: true));
    final json = AppConfig.defaults.toJson();
    json['display'] = {
      ...json['display'] as Map<String, Object?>,
      'panelColumnCount': 3,
      'panelItemLayout': 'vertical',
      'showChangePercent': false,
      'marketColorStyle': 'redUp',
    };
    final taskbar = json['taskbar'] as Map<String, Object?>;
    taskbar['profile'] = {
      ...taskbar['profile'] as Map<String, Object?>,
      'showChangePercent': true,
      'marketColorStyle': 'greenUp',
    };
    final config = AppConfig.fromJson(json);
    final edited = config.withDisplay(
      DisplayTarget.taskbar,
      config.displayFor(DisplayTarget.taskbar).copyWith(fontSize: 20),
    );
    final store = ConfigStore(directory: directory.path);
    await store.save(edited);
    final reloaded = await store.load();
    final display = reloaded.toJson()['display'] as Map<String, Object?>;
    expect(display['panelColumnCount'], 3);
    expect(display['panelItemLayout'], 'vertical');
    expect(display['showChangePercent'], false);
    expect(display['marketColorStyle'], 'redUp');
    final profile = reloaded.taskbar.profile.toJson();
    expect(profile['showChangePercent'], true);
    expect(profile['marketColorStyle'], 'greenUp');
    expect(reloaded.taskbar.profile.fontSize, 20);
  });

  testWidgets(
    'three columns keep their order at narrow widths without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(250, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _Controller(
        AppConfig.defaults.copyWith(
          panelColumnCount: 3,
          panelItemLayout: 'vertical',
          selectedAssetIds: [
            'OKX:BTC-USDT',
            'OKX:ETH-USDT',
            'OKX:SOL-USDT',
            'OKX:XRP-USDT',
          ],
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('panel-asset:OKX:BTC-USDT')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('panel-asset:OKX:ETH-USDT')),
      );
      final fourth = tester.getTopLeft(
        find.byKey(const ValueKey('panel-asset:OKX:XRP-USDT')),
      );
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      expect(fourth.dy, greaterThan(first.dy));
      expect(fourth.dx, first.dx);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-230, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('panel-asset:OKX:BTC-USDT')))
            .dx,
        lessThan(first.dx),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'vertical entries put market, custom and metric names above values',
    (tester) async {
      final controller = _Controller(
        AppConfig.defaults.copyWith(
          panelItemLayout: 'vertical',
          selectedAssetIds: ['OKX:BTC-USDT'],
          selectedMetricIds: ['cpu.usage'],
          selectedCustomFieldIds: ['custom:weather|temperature'],
          customSources: const [
            CustomApiSource(
              id: 'weather',
              name: 'Weather',
              url: 'https://example.test',
              fields: [
                CustomField(id: 'temperature', label: 'Temperature', path: 't'),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      for (final pair in [
        ('BTC', '101.00'),
        ('Temperature', '23.50'),
        ('CPU usage', '—'),
      ]) {
        expect(
          tester.getTopLeft(find.text(pair.$2)).dy,
          greaterThan(tester.getBottomLeft(find.text(pair.$1)).dy),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'hidden change percentage colors price using the selected convention',
    (tester) async {
      final controller = _Controller(
        AppConfig.defaults.copyWith(
          selectedAssetIds: ['OKX:BTC-USDT'],
          showChangePercent: false,
          marketColorStyle: 'redUp',
          themeMode: 'light',
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('+2.50%'), findsNothing);
      expect(
        tester.widget<Text>(find.text('101.00')).style?.color,
        const Color(0xFFC50F1F),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'panel uses bottom space for content without status footer or resize arrow',
    (tester) async {
      final controller = _Controller(
        AppConfig.defaults.copyWith(selectedAssetIds: ['OKX:BTC-USDT']),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.south_east), findsNothing);
      final scrollArea = tester.getRect(find.byType(ListView));
      expect(scrollArea.bottom, 600);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'custom market templates honor the selected rise and fall colors',
    (tester) async {
      final controller = _Controller(
        AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          displayRows: const [
            DisplayRow(
              id: 'change',
              segments: [
                DisplaySegment.field(
                  assetId: 'OKX:BTC-USDT',
                  fieldId: 'change',
                  format: '+.2f',
                ),
              ],
            ),
          ],
          marketColorStyle: 'redUp',
          themeMode: 'light',
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const ValueKey('panel-row:change')),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(
        (text.textSpan! as TextSpan).children!.first.style?.color,
        const Color(0xFFC50F1F),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final columns in [1, 2, 4, 8]) {
    for (final layout in ['horizontal', 'vertical']) {
      testWidgets('$columns $layout columns fit large text in a narrow panel', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(220, 420));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _Controller(
          AppConfig.defaults.copyWith(
            panelColumnCount: columns,
            panelItemLayout: layout,
            fontSize: 32,
            selectedAssetIds: ['OKX:BTC-USDT', 'OKX:ETH-USDT', 'OKX:SOL-USDT'],
          ),
        );
        await tester.pumpWidget(CryptoFloatApp(controller: controller));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _Controller extends AppController {
  _Controller(AppConfig config)
    : super(
        config: config.copyWith(language: 'en', proxyEnabled: false),
        store: _Store(),
        host: _Host(),
        secrets: _Secrets(),
      );
  @override
  Map<String, MarketQuote> get displayQuotes => {
    'OKX:BTC-USDT': MarketQuote(
      assetId: 'OKX:BTC-USDT',
      price: 101,
      changePercent: 2.5,
      currency: 'USDT',
      updatedAt: DateTime.now(),
    ),
    'custom:weather': MarketQuote(
      assetId: 'custom:weather',
      price: null,
      currency: '',
      updatedAt: DateTime.now(),
      extra: const {'temperature': 23.5},
    ),
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
