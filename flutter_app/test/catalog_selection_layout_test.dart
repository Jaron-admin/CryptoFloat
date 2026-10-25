import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catalog selection and deselection keep order and visible row', (
    tester,
  ) async {
    final catalog = _MutableCatalog(_fixtures());
    await _openSettings(tester, catalog: catalog);
    final row = _catalogRow('OKX:TST010-USDT');
    final originalOrder = _catalogOrder(tester);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(row).dy;

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<FCheckboxListTile>(row).value, isTrue);
    expect(_catalogOrder(tester), originalOrder);
    expect(tester.getTopLeft(row).dy, closeTo(top, 0.5));

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<FCheckboxListTile>(row).value, isFalse);
    expect(_catalogOrder(tester), originalOrder);
    expect(tester.getTopLeft(row).dy, closeTo(top, 0.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    're-entering watchlist and explicit refresh put checked rows first',
    (tester) async {
      final catalog = _MutableCatalog(_fixtures());
      await _openSettings(tester, catalog: catalog);
      final first = _catalogRow('OKX:TST010-USDT');
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(_catalogOrder(tester).first, isNot('OKX:TST010-USDT'));

      await tester.tap(find.text('Appearance').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Display').first);
      await tester.pumpAndSettle();
      expect(_catalogOrder(tester).first, 'OKX:TST010-USDT');

      final second = _catalogRow('OKX:TST020-USDT');
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(_catalogOrder(tester)[1], isNot('OKX:TST020-USDT'));
      final refresh = find.text('Refresh catalog');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(catalog.forcedRefreshes, 1);
      expect(_catalogOrder(tester).take(2), [
        'OKX:TST010-USDT',
        'OKX:TST020-USDT',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('asynchronous catalog additions leave displayed rows in place', (
    tester,
  ) async {
    final catalog = _MutableCatalog(_fixtures());
    await _openSettings(tester, catalog: catalog);
    final row = _catalogRow('OKX:TST010-USDT');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final before = _catalogOrder(tester);
    final top = tester.getTopLeft(row).dy;
    catalog.publish([
      const Asset(
        id: 'BINANCE:AAAAUSDT',
        provider: 'BINANCE',
        symbol: 'AAAAUSDT',
        name: 'Async catalog asset',
        kind: MarketKind.crypto,
        currency: 'USDT',
      ),
      ..._fixtures().reversed,
    ]);
    await tester.pumpAndSettle();
    expect(_catalogOrder(tester).take(before.length), before);
    expect(_catalogOrder(tester).last, 'BINANCE:AAAAUSDT');
    expect(tester.getTopLeft(row).dy, closeTo(top, 0.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['en', 'zh']) {
    for (final size in [const Size(520, 620), const Size(700, 580)]) {
      testWidgets('$language compact settings fit ${size.width.toInt()} px', (
        tester,
      ) async {
        await _openSettings(
          tester,
          catalog: _MutableCatalog(_fixtures()),
          language: language,
          size: size,
        );
        final sections = language == 'en'
            ? ['General', 'Appearance', 'Display', 'Privacy and data', 'About']
            : ['通用', '外观', '显示', '隐私与数据', '关于'];
        for (final title in sections) {
          final category = size.width < 560
              ? find.widgetWithText(ChoiceChip, title)
              : find.byTooltip(title);
          await tester.ensureVisible(category);
          await tester.tap(category);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: title);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('render Material settings previews with synthetic content', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
      for (final font in {
        'Segoe UI': 'segoeui.ttf',
        'Microsoft YaHei': 'msyh.ttc',
        'Consolas': 'consola.ttf',
      }.entries) {
        final file = File('$windows/Fonts/${font.value}');
        if (!await file.exists()) continue;
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    });
    for (final language in ['en', 'zh']) {
      final captureKey = GlobalKey();
      await _openSettings(
        tester,
        catalog: _MutableCatalog(_fixtures()),
        language: language,
        captureKey: captureKey,
        size: const Size(980, 720),
      );
      for (final id in ['OKX:BTC-USDT', 'OKX:ETH-USDT', 'OKX:SOL-USDT']) {
        final row = _catalogRow(id);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.text(language == 'en' ? 'Watchlist' : '关注行情').last,
      );
      await tester.pumpAndSettle();
      await _capture(tester, captureKey, 'settings-watchlist-$language');
      await tester.tap(find.text(language == 'en' ? 'Appearance' : '外观').first);
      await tester.pumpAndSettle();
      await _capture(tester, captureKey, 'settings-appearance-$language');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<void> _openSettings(
  WidgetTester tester, {
  required _MutableCatalog catalog,
  String language = 'en',
  Size size = const Size(980, 720),
  GlobalKey? captureKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = AppController(
    config: AppConfig.defaults.copyWith(
      selectedAssetIds: [],
      language: language,
      themeMode: 'light',
      proxyEnabled: false,
    ),
    store: SettingsStore(),
    host: SettingsHost(),
    secrets: SettingsSecrets(),
    assetCatalog: catalog,
  );
  final app = CryptoFloatApp(controller: controller);
  await tester.pumpWidget(
    captureKey == null ? app : RepaintBoundary(key: captureKey, child: app),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('panel-title')),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(language == 'en' ? 'Settings…' : '设置…'));
  await tester.pumpAndSettle();
  expect(find.byType(SettingsPage), findsOneWidget);
  final display = language == 'en' ? 'Display' : '显示';
  await tester.tap(
    size.width >= 560 && size.width < 760
        ? find.byTooltip(display)
        : find.text(display).first,
  );
  await tester.pumpAndSettle();
}

Finder _catalogRow(String id) => find.byKey(ValueKey('catalog-$id'));

List<String> _catalogOrder(WidgetTester tester) => tester
    .widgetList<FCheckboxListTile>(find.byType(FCheckboxListTile))
    .map((widget) => (widget.key! as ValueKey<String>).value.substring(8))
    .toList();

List<Asset> _fixtures() => [
  for (var i = 0; i < 35; i++)
    Asset(
      id: 'OKX:TST${i.toString().padLeft(3, '0')}-USDT',
      provider: 'OKX',
      symbol: 'TST${i.toString().padLeft(3, '0')}-USDT',
      name: 'Sample asset ${i.toString().padLeft(3, '0')}',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
];

class _MutableCatalog extends SettingsCatalog {
  _MutableCatalog(this._assets);
  List<Asset> _assets;
  int forcedRefreshes = 0;
  @override
  List<Asset> get assets => _assets;
  @override
  Future<void> refresh({bool force = false}) async {
    if (force) forcedRefreshes++;
  }

  void publish(List<Asset> assets) {
    _assets = assets;
    notifyListeners();
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('dist/review-1.2.0/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
