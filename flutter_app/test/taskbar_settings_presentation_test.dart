import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/system_metric.dart';
import 'package:cryptofloat/features/settings/taskbar_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPreview(WidgetTester tester, AppConfig config) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaskbarSettingsView(
              config: config,
              snapshot: const SystemMetricSnapshot(),
              status: 'displaying',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppConfig previewConfig(
    List<String> texts, {
    double width = 900,
    int lineCount = 1,
    int gap = 6,
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
    taskbar: TaskbarConfig(width: width, lineCount: lineCount, itemGap: gap),
  );

  Finder previewCell(int index) =>
      find.byKey(ValueKey('taskbar-preview-cell-row:$index'));

  testWidgets('preview uses compact measured width and real item gaps', (
    tester,
  ) async {
    await pumpPreview(tester, previewConfig(['A', 'B']));
    final preview = find.byKey(const ValueKey('taskbar-preview'));
    expect(tester.getSize(preview).width, lessThan(200));
    expect(
      tester.getTopLeft(previewCell(1)).dx -
          tester.getTopRight(previewCell(0)).dx,
      closeTo(6, .01),
    );
    final initialWidth = tester.getSize(preview).width;
    await pumpPreview(tester, previewConfig(['AAAA', 'BBBB'], gap: 6));
    final textWidth = tester.getSize(preview).width;
    expect(textWidth, greaterThan(initialWidth));
    await pumpPreview(tester, previewConfig(['AAAA', 'BBBB'], gap: 18));
    expect(tester.getSize(preview).width, closeTo(textWidth + 12, .01));
    expect(
      tester.getTopLeft(previewCell(1)).dx -
          tester.getTopRight(previewCell(0)).dx,
      closeTo(18, .01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview pairs rows into measured columns without an extra column',
    (tester) async {
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
      final preview = find.byKey(const ValueKey('taskbar-preview'));
      expect(
        tester.getTopRight(preview).dx - tester.getTopRight(previewCell(2)).dx,
        closeTo(4, .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow preview preserves short columns and full tooltips', (
    tester,
  ) async {
    const longText = 'A much longer original field that cannot fit';
    await pumpPreview(tester, previewConfig(['A', longText], width: 120));
    expect(
      tester.getSize(find.byKey(const ValueKey('taskbar-preview'))).width,
      120,
    );
    expect(
      tester.getSize(previewCell(0)).width,
      lessThan(tester.getSize(previewCell(1)).width),
    );
    expect(find.byTooltip(longText), findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: previewCell(1), matching: find.byType(Text)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('many cramped columns do not overflow and signal omitted items', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      previewConfig(
        List.generate(32, (i) => 'Reading $i'),
        width: 120,
        lineCount: 2,
        gap: 24,
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('taskbar-preview'))).width,
      120,
    );
    expect(previewCell(31), findsNothing);
    final previewTexts = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('taskbar-preview')),
        matching: find.byType(Text),
      ),
    );
    expect(
      previewTexts.any(
        (text) => text.textSpan?.toPlainText().endsWith(' …') ?? false,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

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
