import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/panel_layout_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('columns and entry direction can be selected independently', (
    tester,
  ) async {
    var draft = AppConfig.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: PanelLayoutSettings(
                config: draft,
                target: DisplayTarget.floating,
                onChanged: (value) => setState(() => draft = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('panel-column-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 columns').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('panel-item-layout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name above value').last);
    await tester.pumpAndSettle();
    expect(draft.panelColumnCount, 3);
    expect(draft.panelItemLayout, 'vertical');
    await tester.tap(find.text('Show 24h change percentage'));
    await tester.pumpAndSettle();
    expect(draft.showChangePercent, false);
    expect(draft.panelColumnCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'taskbar choices include percentage and colors without floating columns',
    (tester) async {
      var draft = AppConfig.defaults.displayFor(DisplayTarget.taskbar);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PanelLayoutSettings(
                config: draft,
                target: DisplayTarget.taskbar,
                onChanged: (value) => setState(() => draft = value),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('panel-column-count')), findsNothing);
      expect(find.byKey(const ValueKey('panel-item-layout')), findsNothing);
      expect(find.byKey(const ValueKey('market-color-style')), findsNothing);
      expect(find.text('Show 24h change percentage'), findsOneWidget);
      expect(draft.showChangePercent, isTrue);
    },
  );
}
