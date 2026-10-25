import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/panel/panel_page.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/features/settings/ti_settings_view.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

Widget app(Widget child, AppConfig config) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildAppTheme(config, brightness: Brightness.light),
  home: child,
);

class PreviewController extends AppController {
  PreviewController(AppConfig config, SettingsStore store)
    : super(
        config: config,
        store: store,
        host: SettingsHost(),
        secrets: SettingsSecrets(),
        assetCatalog: SettingsCatalog(),
      );
  final quotes = <String, MarketQuote>{};
  @override
  Map<String, MarketQuote> get displayQuotes => quotes;
  void quote(double price) {
    quotes['OKX:BTC-USDT'] = MarketQuote(
      assetId: 'OKX:BTC-USDT',
      price: price,
      currency: 'USDT',
      changePercent: -2.5,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }
}

void main() {
  testWidgets('settings keep a fixed live floating preview while editing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
      final font = File('$windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        await (FontLoader(
          'Segoe UI',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    });
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SettingsStore();
    final config = AppConfig.defaults.copyWith(
      selectedAssetIds: ['OKX:BTC-USDT'],
      showChangePercent: false,
      windowBounds: const WindowBounds(x: 0, y: 0, width: 700, height: 300),
      language: 'en',
      proxyEnabled: false,
    );
    final controller = PreviewController(config, store)..quote(103000);
    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: const ValueKey('settings-capture'),
          child: SettingsPage(
            controller: controller,
            onClose: () {},
            initialSection: 1,
          ),
        ),
        config,
      ),
    );
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('settings-live-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('BTC')),
      findsOneWidget,
    );
    final before = tester.getRect(preview);
    final row = find.descendant(
      of: preview,
      matching: find.byKey(const ValueKey('panel-asset:OKX:BTC-USDT')),
    );
    final originalWidth = tester.getSize(row).width;
    final gap = find.byKey(const ValueKey('panel-label-value-gap'));
    final scrollable = find
        .descendant(
          of: find.byType(TiSettingsView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(gap, 200, scrollable: scrollable);
    tester.widget<Slider>(gap).onChanged!(32);
    await tester.pumpAndSettle();
    expect(tester.getSize(row).width, closeTo(originalWidth + 24, .1));
    controller.quote(104000);
    await tester.pump();
    expect(
      find.descendant(of: preview, matching: find.text('104,000.00')),
      findsOneWidget,
    );
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(preview), before);
    expect(
      store.saved,
      isNull,
      reason: 'Preview never persists a settings draft',
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('settings-capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('dist/review-1.6.0')
        ..createSync(recursive: true);
      File('${directory.path}/settings-live-preview.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'floating rows stay compact and share right aligned value edges',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT', 'OKX:ETH-USDT'],
        showChangePercent: false,
        language: 'en',
        proxyEnabled: false,
      );
      final controller = settingsController(
        SettingsStore(),
        SettingsHost(),
        config: config,
      );
      await tester.pumpWidget(
        app(PanelPage(controller: controller, onSettings: (_) {}), config),
      );
      await tester.pumpAndSettle();
      final btc = tester.getRect(
        find.byKey(const ValueKey('panel-asset:OKX:BTC-USDT')),
      );
      final eth = tester.getRect(
        find.byKey(const ValueKey('panel-asset:OKX:ETH-USDT')),
      );
      expect(
        btc.width,
        lessThan(300),
        reason: 'Wide windows must not stretch name/value spacing',
      );
      expect(eth.right, closeTo(btc.right, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'floating name/value and column gaps change the rendered geometry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final initial = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT', 'OKX:ETH-USDT'],
        showChangePercent: false,
        panelColumnCount: 2,
        language: 'en',
        proxyEnabled: false,
      );
      final controller = PreviewController(initial, SettingsStore())
        ..quote(103000);
      Future<void> render(AppConfig config) async {
        await tester.pumpWidget(
          app(
            Scaffold(
              body: PanelContent(controller: controller, config: config),
            ),
            config,
          ),
        );
        await tester.pumpAndSettle();
      }

      Rect row(String id) =>
          tester.getRect(find.byKey(ValueKey('panel-asset:OKX:$id-USDT')));
      await render(initial);
      final original = row('BTC');
      expect(row('ETH').left - original.right, closeTo(12, .1));
      await render(
        initial.copyWith(panelLabelValueGap: 24, panelColumnGap: 36),
      );
      expect(row('BTC').width, closeTo(original.width + 16, .1));
      expect(row('ETH').left - row('BTC').right, closeTo(36, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'integrated taskbar preview pages within the settings viewport and accepts wheel input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: [],
        language: 'en',
        proxyEnabled: false,
        taskbar: TaskbarConfig(
          lineCount: 1,
          overflowMode: 'manual',
          profile: DisplayProfile(
            showDefaultRows: false,
            displayRows: [
              for (var i = 0; i < 12; i++)
                DisplayRow(
                  id: 'reading-$i',
                  segments: [
                    DisplaySegment.literal('Long reading $i = 123456.78'),
                  ],
                ),
            ],
          ),
        ),
      );
      final controller = PreviewController(config, SettingsStore());
      try {
        await tester.pumpWidget(
          app(
            SettingsPage(
              controller: controller,
              onClose: () {},
              initialSection: 2,
            ),
            config,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Taskbar').first);
        await tester.pumpAndSettle();
        final preview = find.byKey(const ValueKey('taskbar-preview'));
        expect(preview, findsOneWidget);
        expect(
          find.byKey(const ValueKey('taskbar-preview-cell-row:reading-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('taskbar-preview-cell-row:reading-11')),
          findsNothing,
          reason: 'The fixed preview must paginate before drawing cells outside its viewport',
        );
        expect(tester.getSize(preview).width, lessThanOrEqualTo(748));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(preview),
            scrollDelta: const Offset(0, 120),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('taskbar-preview-cell-row:reading-0')),
          findsNothing,
          reason: 'Wheel advances the taskbar page instead of scrolling an outer horizontal viewport',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'minimum-size settings keep preview and scrollable controls usable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(320, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT'],
        language: 'en',
        proxyEnabled: false,
        taskbar: TaskbarConfig(
          lineCount: 2,
          overflowMode: 'manual',
          profile: DisplayProfile(
            fontSize: 32,
            showDefaultRows: false,
            displayRows: [
              for (var i = 0; i < 12; i++)
                DisplayRow(
                  id: 'large-$i',
                  segments: [DisplaySegment.literal('Reading $i = 12345')],
                ),
            ],
          ),
        ),
      );
      final controller = PreviewController(config, SettingsStore())
        ..quote(81700);
      try {
        await tester.pumpWidget(
          app(
            RepaintBoundary(
              key: const ValueKey('minimum-settings-capture'),
              child: SettingsPage(
                controller: controller,
                onClose: () {},
                initialSection: 2,
              ),
            ),
            config,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final preview = find.byKey(const ValueKey('settings-live-preview'));
        expect(tester.getRect(preview).height, greaterThanOrEqualTo(70));
        expect(
          find.descendant(of: preview, matching: find.text('BTC')),
          findsOneWidget,
        );
        final categoryMenu = find.byKey(
          const ValueKey('compact-settings-categories'),
        );
        await tester.tap(categoryMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Appearance').last);
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byType(TiSettingsView),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(tester.getSize(scrollable).height, greaterThan(30));
        await tester.drag(scrollable, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('minimum-settings-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('dist/review-1.6.0')
            ..createSync(recursive: true);
          File('${directory.path}/settings-minimum-size.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.text('Taskbar').first);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Large two-line taskbar previews must scroll vertically within the compact viewport',
        );
        final viewport = find.byKey(const ValueKey('settings-preview-render'));
        final verticalScroll = find
            .descendant(of: viewport, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(verticalScroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getTopLeft(viewport) + const Offset(20, 10),
            scrollDelta: const Offset(0, 120),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('taskbar-preview-cell-row:large-0')),
          findsNothing,
        );
        await tester.dragFrom(
          tester.getTopRight(viewport) + const Offset(-3, 10),
          const Offset(0, 35),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(
          position.pixels,
          greaterThan(0),
          reason: 'The visible scrollbar remains draggable while the wheel is reserved for paging',
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('minimum-settings-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('dist/review-1.6.0/settings-minimum-taskbar-font32.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  for (final target in DisplayTarget.values) {
    testWidgets('${target.name} preview follows an unsaved display reorder', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const rows = [
        DisplayRow(id: 'alpha', segments: [DisplaySegment.literal('Alpha')]),
        DisplayRow(id: 'beta', segments: [DisplaySegment.literal('Beta')]),
      ];
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: [],
        selectedMetricIds: [],
        showDefaultRows: false,
        displayRows: rows,
        displayOrder: ['row:alpha', 'row:beta'],
        language: 'en',
        proxyEnabled: false,
        taskbar: const TaskbarConfig(
          lineCount: 1,
          overflowMode: 'manual',
          profile: DisplayProfile(
            showDefaultRows: false,
            displayRows: rows,
            displayOrder: ['row:alpha', 'row:beta'],
          ),
        ),
      );
      final store = SettingsStore();
      final controller = PreviewController(config, store);
      try {
        await tester.pumpWidget(
          app(
            SettingsPage(
              controller: controller,
              onClose: () {},
              initialSection: 2,
            ),
            config,
          ),
        );
        await tester.pumpAndSettle();
        if (target == DisplayTarget.taskbar) {
          await tester.tap(find.text('Taskbar').first);
          await tester.pumpAndSettle();
        }
        final preview = find.byKey(const ValueKey('settings-live-preview'));
        expect(preview, findsOneWidget);
        double previewPosition(String id) {
          final key = target == DisplayTarget.floating
              ? 'panel-row:$id'
              : 'taskbar-preview-cell-row:$id';
          final rect = tester.getRect(
            find.descendant(of: preview, matching: find.byKey(ValueKey(key))),
          );
          return target == DisplayTarget.floating ? rect.top : rect.left;
        }

        expect(previewPosition('alpha'), lessThan(previewPosition('beta')));
        final moveUp = find.descendant(
          of: find.byKey(const ValueKey('display-order-row:beta')),
          matching: find.widgetWithIcon(IconButton, Icons.arrow_upward),
        );
        await tester.ensureVisible(moveUp);
        await tester.tap(moveUp);
        await tester.pumpAndSettle();
        expect(previewPosition('beta'), lessThan(previewPosition('alpha')));
        expect(controller.appearanceConfig.displayFor(target).displayOrder, [
          'row:beta',
          'row:alpha',
        ]);
        expect(controller.config.displayFor(target).displayOrder, [
          'row:alpha',
          'row:beta',
        ]);
        expect(
          store.saved,
          isNull,
          reason: 'A preview edit never saves the draft',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });
  }

  testWidgets('vertical floating entries honor name/value spacing', (
    tester,
  ) async {
    final initial = AppConfig.defaults.copyWith(
      selectedAssetIds: ['OKX:BTC-USDT'],
      panelItemLayout: 'vertical',
      showChangePercent: false,
      language: 'en',
      proxyEnabled: false,
    );
    final controller = PreviewController(initial, SettingsStore())
      ..quote(81700);
    try {
      Future<void> render(double gap) async {
        final config = initial.copyWith(panelLabelValueGap: gap);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: PanelContent(controller: controller, config: config),
            ),
            config,
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(4);
      final first = tester.getTopLeft(find.text('81,700.00')).dy;
      await render(28);
      expect(
        tester.getTopLeft(find.text('81,700.00')).dy,
        closeTo(first + 24, .1),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}
