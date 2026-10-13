import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/platform/floating_window_host.dart';
import 'package:cryptofloat/platform/secret_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppController _controller(AppConfig config) => AppController(
  config: config.copyWith(proxyEnabled: false, language: 'zh'),
  store: _Store(),
  host: _Host(),
  secrets: _Secrets(),
);

void main() {
  testWidgets('adding a free text row keeps the selected default market rows', (
    tester,
  ) async {
    final controller = _controller(
      AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT'],
        displayRows: [
          const DisplayRow(
            id: 'note',
            segments: [DisplaySegment.literal('提醒：起来走走')],
          ),
        ],
      ),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.textContaining('提醒：起来走走'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'right click anywhere in the panel opens the menu without a dots button',
    (tester) async {
      final controller = _controller(
        AppConfig.defaults.copyWith(selectedAssetIds: ['OKX:BTC-USDT']),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Bitcoin'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.text('设置…'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('设置…'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'custom header name and hidden icon survive configuration loading',
    (tester) async {
      final json = AppConfig.defaults
          .copyWith(selectedAssetIds: ['OKX:BTC-USDT'])
          .toJson();
      json['appearance'] = {
        ...json['appearance'] as Map<String, Object?>,
        'headerName': '我的小面板',
        'showHeaderIcon': false,
      };
      final controller = _controller(AppConfig.fromJson(json));
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('我的小面板'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'compact unit labels show USDT as U without changing subscriptions',
    (tester) async {
      final json = AppConfig.defaults
          .copyWith(selectedAssetIds: ['OKX:BTC-USDT'])
          .toJson();
      json['display'] = {'unitLabelMode': 'compact', 'showDefaultRows': true};
      final controller = _controller(AppConfig.fromJson(json));
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('U'), findsOneWidget);
      expect(controller.config.assets.single.currency, 'USDT');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('display choices and manual conversions round trip independently of original data', () {
    final json = AppConfig.defaults.toJson();
    json['display'] = {
      'showDefaultRows': false,
      'unitLabelMode': 'custom',
      'unitLabels': {'USDT': 'U', 'CNY': '元'},
      'displayCurrency': 'CNY',
      'unitRules': [
        {'sourceUnit': 'kg', 'targetUnit': 'g', 'multiplier': 1000.0},
      ],
    };
    final loaded = AppConfig.fromJson(json);
    final display = loaded.toJson()['display'] as Map<String, Object?>?;
    expect(display?['showDefaultRows'], false);
    expect(display?['unitLabelMode'], 'custom');
    expect(display?['unitLabels'], {'USDT': 'U', 'CNY': '元'});
    expect(display?['displayCurrency'], 'CNY');
    expect((display?['unitRules'] as List?)?.single, {
      'sourceUnit': 'kg',
      'targetUnit': 'g',
      'multiplier': 1000.0,
    });
  });
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
  Future<List<String>> getSystemFonts() async => ['Segoe UI', 'Consolas'];
}
