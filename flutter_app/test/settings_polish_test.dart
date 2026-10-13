import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/unit_conversion.dart';
import 'package:cryptofloat/features/settings/settings_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(
    find.text('CryptoFloat'),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('设置…'));
  await tester.pumpAndSettle();
}

AppController _controller(
  SettingsStore store,
  SettingsHost host, {
  AppConfig? config,
}) => settingsController(
  store,
  host,
  config:
      (config ??
              AppConfig.defaults.copyWith(
                selectedAssetIds: [],
                proxyEnabled: false,
              ))
          .copyWith(language: 'zh'),
);

ThemeData _theme(WidgetTester tester) => Theme.of(
  tester.element(
    find.byType(SettingsPage).evaluate().isNotEmpty
        ? find.byType(SettingsPage)
        : find.byType(Scaffold).first,
  ),
);

Future<void> category(WidgetTester tester, String title) async {
  final chip = find.widgetWithText(ChoiceChip, title);
  final target = chip.evaluate().isNotEmpty ? chip : find.text(title).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> appearance(WidgetTester tester) => category(tester, '外观');

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  if (finder.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(
        finder,
        delta,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byType(Scrollbar).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    } on StateError {
      expect(finder, findsOneWidget, reason: '设置控件应能通过滚动访问。');
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new label replaces the same unit regardless of input case', (
    tester,
  ) async {
    final store = SettingsStore();
    final controller = _controller(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(
        selectedAssetIds: [],
        proxyEnabled: false,
        unitLabelMode: 'custom',
        unitLabels: {'USD': '旧标签', 'EUR': '欧元'},
      ),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await category(tester, '单位与换算');
    await reveal(tester, find.text('添加单位标签'));
    await tester.tap(find.text('添加单位标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('label-source')), ' usd ');
    await tester.enterText(find.byKey(const ValueKey('label-text')), '新美元标签');
    await tester.tap(find.text('保存标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(displayUnitLabel(' USD ', store.saved!), '新美元标签');
    expect(store.saved?.unitLabels.length, 2);
    expect(store.saved?.unitLabels['EUR'], '欧元');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a new multiplier replaces the same source unit regardless of input case',
    (tester) async {
      final store = SettingsStore();
      final controller = _controller(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          proxyEnabled: false,
          unitRules: const [
            UnitConversionRule(
              sourceUnit: ' oz ',
              targetUnit: 'g',
              multiplier: 28,
            ),
            UnitConversionRule(
              sourceUnit: 'ms',
              targetUnit: 's',
              multiplier: 0.001,
            ),
          ],
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await category(tester, '单位与换算');
      await reveal(tester, find.text('添加倍率规则'));
      await tester.tap(find.text('添加倍率规则'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rule-source')), 'OZ');
      await tester.enterText(find.byKey(const ValueKey('rule-target')), 'g');
      await tester.enterText(
        find.byKey(const ValueKey('rule-multiplier')),
        '30',
      );
      await tester.tap(find.text('保存规则'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();
      final converted = convertUnitValue(2, ' oz ', store.saved!, {});
      expect(converted.value, 60);
      expect(converted.unit, 'g');
      expect(store.saved?.unitRules.length, 2);
      expect(convertUnitValue(1000, 'ms', store.saved!, {}).value, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'templates append to the draft and cancel without changing existing rows',
    (tester) async {
      final store = SettingsStore();
      final controller = _controller(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          proxyEnabled: false,
          displayRows: [
            const DisplayRow(
              id: 'existing',
              segments: [DisplaySegment.literal('已有备注')],
            ),
          ],
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await category(tester, '显示布局');
      await reveal(tester, find.text('添加实用模板'));
      await tester.tap(find.text('添加实用模板'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.config.displayRows.single.id, 'existing');
      expect(store.saved, isNull);
      await tester.tap(find.text('添加实用模板'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('文字提醒'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '显示文字'), '休息一下');
      await tester.tap(find.text('加入显示'));
      await tester.pumpAndSettle();
      expect(store.saved, isNull);
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();
      expect(store.saved?.displayRows.length, 2);
      expect(store.saved?.displayRows.first.id, 'existing');
      expect(store.saved?.displayRows.last.segments.single.text, '休息一下');
      expect(store.saved?.showDefaultRows, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('hiding default rows preserves existing free rows', (
    tester,
  ) async {
    final store = SettingsStore();
    final controller = _controller(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(
        selectedAssetIds: [],
        proxyEnabled: false,
        displayRows: [
          const DisplayRow(
            id: 'note',
            segments: [DisplaySegment.literal('备注')],
          ),
        ],
      ),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await category(tester, '显示布局');
    expect(find.text('显示默认行情'), findsOneWidget);
    await tester.tap(find.text('显示默认行情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(store.saved?.showDefaultRows, false);
    expect(store.saved?.displayRows.single.id, 'note');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('header name and icon visibility can be saved independently', (
    tester,
  ) async {
    final store = SettingsStore();
    final controller = _controller(store, SettingsHost());
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await appearance(tester);
    await reveal(tester, find.byKey(const ValueKey('header-name')));
    await tester.enterText(find.byKey(const ValueKey('header-name')), '我的行情');
    final iconToggle = find.descendant(
      of: find.widgetWithText(SettingRow, '显示标题图标'),
      matching: find.byType(Switch),
    );
    await reveal(tester, iconToggle);
    await tester.tap(iconToggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(store.saved?.headerName, '我的行情');
    expect(store.saved?.showHeaderName, true);
    expect(store.saved?.showHeaderIcon, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a selected header image can be cleared without changing the header name',
    (tester) async {
      final store = SettingsStore();
      final controller = _controller(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          proxyEnabled: false,
          headerImagePath: 'missing-icon.png',
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await appearance(tester);
      await reveal(tester, find.text('清除图片图标'));
      await tester.tap(find.text('清除图片图标'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();
      expect(store.saved?.headerImagePath, '');
      expect(store.saved?.headerName, 'CryptoFloat');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unit preferences retain target currency labels and conversion rules',
    (tester) async {
      final store = SettingsStore();
      final controller = _controller(store, SettingsHost());
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await category(tester, '单位与换算');
      await reveal(tester, find.byKey(const ValueKey('unit-label-mode')));
      await tester.tap(find.byKey(const ValueKey('unit-label-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('display-currency')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('display-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNY').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('添加单位标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加单位标签'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('label-source')),
        'USDT',
      );
      await tester.enterText(find.byKey(const ValueKey('label-text')), 'U');
      await tester.tap(find.text('保存标签'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('添加倍率规则'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加倍率规则'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rule-source')), 'oz');
      await tester.enterText(find.byKey(const ValueKey('rule-target')), 'g');
      await tester.enterText(
        find.byKey(const ValueKey('rule-multiplier')),
        'NaN',
      );
      await tester.tap(find.text('保存规则'));
      await tester.pumpAndSettle();
      expect(find.text('请填写两个单位和大于 0 的有效倍率。'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('rule-multiplier')),
        '28.3495',
      );
      await tester.tap(find.text('保存规则'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();
      expect(store.saved?.unitLabelMode, 'custom');
      expect(store.saved?.displayCurrency, 'CNY');
      expect(store.saved?.unitLabels['USDT'], 'U');
      expect(store.saved?.unitRules.single.multiplier, 28.3495);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('settings title starts host movement', (tester) async {
    final host = SettingsHost();
    final controller = _controller(SettingsStore(), host);
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.drag(find.text('CryptoFloat 设置'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(host.drags, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'an unreadable installed font is visible and leaves the selected font unchanged',
    (tester) async {
      const channel = MethodChannel('cryptofloat/platform');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'font_unavailable'),
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final store = SettingsStore();
      final host = SettingsHost()..fonts = ['Broken Font Face'];
      final controller = _controller(store, host);
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await appearance(tester);
      await reveal(tester, find.text('选择系统字体').first);
      await tester.tap(find.text('选择系统字体').first);
      await tester.pumpAndSettle();
      expect(find.text('字体无法加载，请选择其他字体'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回悬浮窗'));
      await tester.pumpAndSettle();
      expect(controller.config.fontFamily, 'Segoe UI');
      expect(store.saved, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'draft background reaches surfaces and dialogs and cancels cleanly',
    (tester) async {
      final store = SettingsStore();
      final controller = _controller(store, SettingsHost());
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      final beforeTheme = _theme(tester);
      final before = beforeTheme.colorScheme.surface;
      await openSettings(tester);
      await appearance(tester);
      final mode = find.byKey(const ValueKey('theme-mode-system'));
      await tester.ensureVisible(mode);
      await tester.tap(mode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色').last);
      await tester.pumpAndSettle();
      final darkPalette = find.byKey(
        const ValueKey('theme-palette-true-fluent'),
      );
      await reveal(tester, darkPalette);
      await tester.tap(darkPalette);
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义背景').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('选择颜色'));
      await tester.tap(find.text('选择颜色'));
      await tester.pumpAndSettle();
      final hex = find.byKey(const ValueKey('theme-hex'));
      await reveal(tester, hex);
      await tester.enterText(hex, '14251F');
      await tester.tap(find.byKey(const ValueKey('theme-save')));
      await tester.pumpAndSettle();
      final theme = _theme(tester);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF14251F));
      expect(theme.colorScheme.surface, isNot(before));
      expect(
        theme.colorScheme.secondaryContainer,
        isNot(beforeTheme.colorScheme.secondaryContainer),
      );
      expect(theme.cardTheme.color, isNot(const Color(0xFF1B2531)));
      expect(
        theme.inputDecorationTheme.fillColor,
        isNot(const Color(0xFF10161F)),
      );
      await reveal(tester, find.text('文字字体'), delta: -250);
      await reveal(tester, find.text('选择系统字体').first);
      await tester.tap(find.text('选择系统字体').first);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AlertDialog)))
            .scaffoldBackgroundColor,
        const Color(0xFF14251F),
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回悬浮窗'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃更改'));
      await tester.pumpAndSettle();
      expect(_theme(tester).colorScheme.surface, before);
      expect(store.saved, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('draft font changes settings text and preview includes Chinese', (
    tester,
  ) async {
    final controller = _controller(SettingsStore(), SettingsHost());
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await appearance(tester);
    await reveal(tester, find.text('选择系统字体').first);
    await tester.tap(find.text('选择系统字体').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consolas'));
    await tester.pumpAndSettle();
    expect(_theme(tester).textTheme.bodyMedium?.fontFamily, 'Consolas');
    final samples = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join(' ');
    expect(samples, contains('中文预览'));
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    expect(_theme(tester).textTheme.bodyMedium?.fontFamily, 'Segoe UI');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('narrow settings keep search filters and save action usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(SettingsStore(), SettingsHost());
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Scrollbar && widget.thumbVisibility == true,
      ),
      findsWidgets,
    );
    await tester.tap(find.text('股票 / ETF'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final firstAsset = find.byType(FCheckboxListTile).first;
    await reveal(tester, firstAsset);
    await tester.tap(firstAsset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(find.text('CryptoFloat'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('narrow appearance and font dialog fit a reduced work area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(SettingsStore(), SettingsHost());
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await appearance(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('选择系统字体').first);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('选择系统字体').first);
    await tester.tap(find.text('选择系统字体').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Consolas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(controller.config.fontFamily, 'Consolas');
    expect(find.text('CryptoFloat'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
