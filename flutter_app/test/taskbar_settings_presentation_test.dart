import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/refresh_price.dart';
import 'package:cryptofloat/domain/system_metric.dart';
import 'package:cryptofloat/features/settings/taskbar_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester,
    AppConfig config, {
    double available = 760,
    Map<String, MarketQuote> quotes = const {},
    Map<String, PriceTick> ticks = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: available,
              child: TaskbarPreview(
                config: config,
                snapshot: const SystemMetricSnapshot(),
                quotes: quotes,
                priceTicks: ticks,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppConfig previewConfig(
    List<String> texts, {
    int lineCount = 1,
    int gap = 6,
    String mode = 'auto',
    int seconds = 5,
  }) => AppConfig.defaults.copyWith(
    selectedAssetIds: [],
    selectedMetricIds: [],
    selectedCustomFieldIds: [],
    showDefaultRows: false,
    fontSize: 12,
    displayRows: [
      for (var i = 0; i < texts.length; i++)
        DisplayRow(id: '$i', segments: [DisplaySegment.literal(texts[i])]),
    ],
    taskbar: TaskbarConfig(
      width: 120,
      lineCount: lineCount,
      itemGap: gap,
      overflowMode: mode,
      carouselIntervalSeconds: seconds,
    ),
  );

  Finder previewCell(int index) =>
      find.byKey(ValueKey('taskbar-preview-cell-row:$index'));

  testWidgets('legacy width no longer caps the taskbar preview', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      previewConfig(['A complete readable taskbar metric']),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('taskbar-preview'))).width,
      greaterThan(120),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('preview uses measured widths and configured item spacing', (
    tester,
  ) async {
    await pumpPreview(tester, previewConfig(['A', 'B']));
    final preview = find.byKey(const ValueKey('taskbar-preview'));
    final firstWidth = tester.getSize(preview).width;
    expect(
      tester.getTopLeft(previewCell(1)).dx -
          tester.getTopRight(previewCell(0)).dx,
      closeTo(6, .01),
    );
    await pumpPreview(tester, previewConfig(['AAAA', 'BBBB']));
    final textWidth = tester.getSize(preview).width;
    expect(textWidth, greaterThan(firstWidth));
    await pumpPreview(tester, previewConfig(['AAAA', 'BBBB'], gap: 18));
    expect(tester.getSize(preview).width, closeTo(textWidth + 12, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('preview keeps paired rows together without extra columns', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      previewConfig(['A', 'Longer', 'B'], lineCount: 2),
    );
    expect(
      tester.getTopLeft(previewCell(0)).dx,
      tester.getTopLeft(previewCell(1)).dx,
    );
    expect(
      tester.getSize(previewCell(0)).width,
      tester.getSize(previewCell(1)).width,
    );
    expect(
      tester.getTopLeft(previewCell(2)).dx -
          tester.getTopRight(previewCell(0)).dx,
      closeTo(6, .01),
    );
    expect(
      tester.getTopLeft(previewCell(0)).dy,
      tester.getTopLeft(previewCell(2)).dy,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('overflow carousel reaches later items at the chosen interval', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      previewConfig(
        List.generate(36, (i) => 'Reading $i'),
        lineCount: 2,
        seconds: 3,
      ),
      available: 140,
    );
    expect(previewCell(0), findsOneWidget);
    expect(previewCell(2), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(previewCell(0), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(previewCell(0), findsNothing);
    expect(previewCell(2), findsOneWidget);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    expect(previewCell(34), findsOneWidget);
    expect(previewCell(35), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hover pauses carousel and restarts a full interval after exit', (
    tester,
  ) async {
    final config = previewConfig([
      'First long metric',
      'Second long metric',
      'Third long metric',
    ], seconds: 3);
    await pumpPreview(tester, config, available: 140);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await tester.pump(const Duration(seconds: 2));
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('taskbar-preview'))),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(previewCell(0), findsOneWidget);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(
          find.byKey(const ValueKey('taskbar-preview')),
        ),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(previewCell(1), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(previewCell(1), findsOneWidget);
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump(const Duration(seconds: 2));
    expect(previewCell(1), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(previewCell(2), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wheel restarts carousel interval but quote updates do not', (
    tester,
  ) async {
    final config = previewConfig([
      'First long metric',
      'Second long metric',
      'Third long metric',
    ], seconds: 3);
    await pumpPreview(tester, config, available: 140);
    await tester.pump(const Duration(seconds: 2));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(
          find.byKey(const ValueKey('taskbar-preview')),
        ),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(previewCell(1), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(previewCell(1), findsOneWidget);
    await pumpPreview(
      tester,
      config,
      available: 140,
      quotes: {
        'OKX:BTC-USDT': MarketQuote(
          assetId: 'OKX:BTC-USDT',
          price: 81701,
          currency: 'USDT',
          updatedAt: DateTime.now(),
        ),
      },
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(previewCell(1), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(previewCell(2), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('manual mode waits for wheel and keeps full tooltips', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      previewConfig([
        'First long metric',
        'Second long metric',
      ], mode: 'manual'),
      available: 140,
    );
    expect(find.byTooltip('First long metric'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(previewCell(0), findsOneWidget);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(
          find.byKey(const ValueKey('taskbar-preview')),
        ),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(previewCell(0), findsNothing);
    expect(previewCell(1), findsOneWidget);
    expect(find.byTooltip('Second long metric'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'price and 24h change have independent color with fixed label gap',
    (tester) async {
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT'],
        fontSize: 12,
        themeMode: 'dark',
        priceColorMode: 'greenUp',
        marketColorStyle: 'redUp',
        taskbar: const TaskbarConfig(lineCount: 1, labelValueGap: 13),
      );
      await pumpPreview(
        tester,
        config,
        quotes: {
          'OKX:BTC-USDT': MarketQuote(
            assetId: 'OKX:BTC-USDT',
            price: 81700,
            currency: 'USDT',
            changePercent: 2.3,
            updatedAt: DateTime.now(),
          ),
        },
        ticks: {'OKX:BTC-USDT': PriceTick.up},
      );
      final label = find.byKey(
        const ValueKey('taskbar-preview-label-asset:OKX:BTC-USDT'),
      );
      final value = find.byKey(
        const ValueKey('taskbar-preview-value-asset:OKX:BTC-USDT'),
      );
      final suffix = find.byKey(
        const ValueKey('taskbar-preview-suffix-asset:OKX:BTC-USDT'),
      );
      expect(
        tester.getTopLeft(value).dx - tester.getTopRight(label).dx,
        closeTo(13, .01),
      );
      expect(
        tester.getTopLeft(suffix).dx - tester.getTopRight(value).dx,
        closeTo(4, .01),
      );
      expect(
        (tester.widget<Text>(value).textSpan as TextSpan).style!.color,
        const Color(0xFF65D9AA),
      );
      expect(
        (tester.widget<Text>(suffix).textSpan as TextSpan).style!.color,
        const Color(0xFFFF8391),
      );
      expect(
        (tester.widget<Text>(label).textSpan as TextSpan).style!.color,
        isNot(const Color(0xFF65D9AA)),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final language in ['zh', 'en']) {
    testWidgets('$language compact taskbar preferences and aliases', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(460, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var config = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:ETH-USDT'],
        selectedMetricIds: ['cpu.usage'],
        displayRows: [],
      );
      final originalProfile = config.taskbar.profile.toJson();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TaskbarSettingsView(
                    config: config,
                    snapshot: const SystemMetricSnapshot(),
                    status: 'displaying',
                    onChanged: (value) => setState(() => config = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(language == 'zh' ? '最大宽度' : 'Maximum width'),
        findsNothing,
      );
      final labelGap = find.byKey(const ValueKey('taskbar-label-value-gap'));
      await tester.ensureVisible(labelGap);
      tester.widget<Slider>(labelGap).onChanged!(11);
      await tester.pumpAndSettle();
      expect(config.taskbar.labelValueGap, 11);
      final interval = find.byKey(const ValueKey('taskbar-carousel-interval'));
      await tester.ensureVisible(interval);
      tester.widget<Slider>(interval).onChanged!(17);
      await tester.pumpAndSettle();
      expect(config.taskbar.carouselIntervalSeconds, 17);
      final overflow = find.byKey(const ValueKey('taskbar-overflow-mode'));
      await tester.ensureVisible(overflow);
      tester.widget<SegmentedButton<String>>(overflow).onSelectionChanged!({
        'manual',
      });
      await tester.pumpAndSettle();
      expect(config.taskbar.overflowMode, 'manual');
      expect(interval, findsNothing);
      final transparency = find.byKey(const ValueKey('taskbar-transparent'));
      await tester.ensureVisible(transparency);
      await tester.tap(transparency);
      await tester.pumpAndSettle();
      expect(config.taskbar.transparentBackground, false);
      final gap = find.byKey(const ValueKey('taskbar-item-gap'));
      await tester.ensureVisible(gap);
      tester.widget<Slider>(gap).onChanged!(2);
      await tester.pumpAndSettle();
      expect(config.taskbar.itemGap, 2);
      final full = find.text(language == 'zh' ? '完整名称' : 'Full labels');
      await tester.ensureVisible(full);
      await tester.tap(full);
      await tester.pumpAndSettle();
      expect(config.taskbar.labelMode, 'full');
      final aliases = find.byKey(const ValueKey('taskbar-aliases'));
      await tester.ensureVisible(aliases);
      await tester.tap(aliases);
      await tester.pumpAndSettle();
      final alias = find.byKey(
        const ValueKey('taskbar-alias-asset:OKX:ETH-USDT'),
      );
      await tester.ensureVisible(alias);
      await tester.enterText(alias, 'Ether');
      await tester.pumpAndSettle();
      expect(config.taskbar.labelAliases['asset:OKX:ETH-USDT'], 'Ether');
      expect(config.taskbar.profile.toJson(), originalProfile);
      expect(config.selectedAssetIds, ['OKX:ETH-USDT']);
      await tester.enterText(alias, '');
      await tester.pumpAndSettle();
      expect(config.taskbar.labelAliases, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
