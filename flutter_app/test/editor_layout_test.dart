import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/features/settings/row_editor.dart';
import 'package:cryptofloat/features/settings/source_editor.dart';
import 'package:cryptofloat/features/settings/template_picker.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

const _source = CustomApiSource(
  id: 'layout',
  name: 'Example source',
  url: 'https://example.com/status',
  fields: [
    CustomField(
      id: 'value',
      label: 'Example value',
      path: 'data.value',
      unit: '',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'zh']) {
    testWidgets('$language API editor and field dialog fit 450 by 420', (
      tester,
    ) async {
      final controller = settingsController(SettingsStore(), SettingsHost());
      try {
        SourceEditResult? result;
        final l10n = await _mount(tester, language, (context) async {
          result = await showDialog<SourceEditResult>(
            context: context,
            builder: (_) =>
                SourceEditor(controller: controller, source: _source),
          );
        });
        _fits(tester);
        await _reveal(tester, find.text(l10n.editSourceHeaders));
        await tester.tap(find.text(l10n.editSourceHeaders));
        await tester.pumpAndSettle();
        await _reveal(tester, find.text(l10n.editHeaderAdd));
        await tester.tap(find.text(l10n.editHeaderAdd));
        await tester.pumpAndSettle();
        await _reveal(tester, _field(l10n.editHeaderName));
        _fits(tester);
        await _reveal(tester, _field(l10n.editHeaderSecret));
        _fits(tester);
        await _reveal(tester, find.text('Example value'));
        await tester.tap(find.text('Example value'));
        await tester.pumpAndSettle();
        _fits(tester);
        await _reveal(tester, _field(l10n.editFieldName));
        await tester.enterText(_field(l10n.editFieldName), 'Updated value');
        await _reveal(tester, _field(l10n.editFieldUnit));
        await tester.enterText(_field(l10n.editFieldUnit), 'units');
        await _reveal(tester, _field(l10n.editFieldPath));
        await tester.enterText(_field(l10n.editFieldPath), 'data.updated');
        _fits(tester);
        await tester.tap(
          find.widgetWithText(FFilledButton, l10n.editAddToDisplay),
        );
        await tester.pumpAndSettle();
        _fits(tester);
        final save = find.widgetWithText(FFilledButton, l10n.editSave);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(420));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(result?.source.fields.single.label, 'Updated value');
        expect(result?.source.fields.single.path, 'data.updated');
        expect(result?.source.fields.single.unit, 'units');
        expect(result?.source.url, _source.url);
        _fits(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });

    testWidgets('$language row editor text and data dialogs fit 450 by 420', (
      tester,
    ) async {
      DisplayRow? result;
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: [],
        customSources: [_source],
      );
      final l10n = await _mount(tester, language, (context) async {
        result = await showDialog<DisplayRow>(
          context: context,
          builder: (_) => RowEditor(config: config, quotes: const {}),
        );
      });
      _fits(tester);
      await _reveal(tester, find.text(l10n.editAddText));
      await tester.tap(find.text(l10n.editAddText));
      await tester.pumpAndSettle();
      _fits(tester);
      await _reveal(tester, _field(l10n.editWantedText));
      await tester.enterText(
        _field(l10n.editWantedText),
        'Portable note · 便携文字',
      );
      await tester.tap(
        find.widgetWithText(FFilledButton, l10n.editAddToDisplay),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.text(l10n.editAddDataField));
      await tester.tap(find.text(l10n.editAddDataField));
      await tester.pumpAndSettle();
      _fits(tester);
      final numberFormat = find.byWidgetPredicate(
        (widget) =>
            widget is FDropdown<String> &&
            widget.decoration.labelText == l10n.editNumberFormat,
      );
      await _reveal(tester, numberFormat);
      await tester.tap(numberFormat);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editDecimalsTwo).last);
      await tester.pumpAndSettle();
      _fits(tester);
      await tester.tap(
        find.widgetWithText(FFilledButton, l10n.editAddToDisplay),
      );
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FFilledButton, l10n.editSaveRow);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(420));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(result?.segments.length, 2);
      expect(result?.segments.first.text, 'Portable note · 便携文字');
      expect(result?.segments.last.assetId, 'custom:layout');
      expect(result?.segments.last.format, '.2f');
      _fits(tester);
    });

    testWidgets(
      '$language all template forms fit 450 by 420 and reminder saves',
      (tester) async {
        AppConfig? result;
        final config = AppConfig.defaults.copyWith(
          displayRows: [
            const DisplayRow(
              id: 'existing',
              segments: [DisplaySegment.literal('Keep me')],
            ),
          ],
        );
        final l10n = await _mount(tester, language, (context) async {
          result = await showTemplatePicker(context, config: config);
        });
        _fits(tester);
        for (final label in [
          l10n.editTemplateWeather,
          l10n.editTemplateGithub,
          l10n.editTemplateRates,
          l10n.editTemplateMarket,
          l10n.editTemplateReminder,
        ]) {
          await _reveal(tester, find.text(label).first);
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          _fits(tester);
        }
        final input = find.byType(TextField);
        await _reveal(tester, input);
        await tester.enterText(input, 'A short bilingual note · 提醒');
        final save = find.widgetWithText(FFilledButton, l10n.editAddToDisplay);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(420));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(result?.displayRows.length, 2);
        expect(result?.displayRows.first.id, 'existing');
        expect(
          result?.displayRows.last.segments.single.text,
          'A short bilingual note · 提醒',
        );
        _fits(tester);
      },
    );
  }
}

Future<AppLocalizations> _mount(
  WidgetTester tester,
  String language,
  Future<void> Function(BuildContext) open,
) async {
  tester.view.physicalSize = const Size(450, 420);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildAppTheme(AppConfig.defaults, brightness: Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.text('Open')));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return l10n;
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .byType(Scrollable)
        .evaluate()
        .where((element) {
          if ((element.widget as Scrollable).axisDirection !=
              AxisDirection.down) {
            return false;
          }
          var textInput = false;
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget is EditableText) textInput = true;
            return !textInput;
          });
          return !textInput;
        })
        .last
        .widget;
    await tester.scrollUntilVisible(
      finder,
      100,
      maxScrolls: 25,
      scrollable: find.byWidget(scrollable),
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void _fits(WidgetTester tester) => expect(tester.takeException(), isNull);
