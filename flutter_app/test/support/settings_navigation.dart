import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/features/settings/settings_catalog.dart';
import 'package:cryptofloat/features/settings/ti_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder settingsFontPicker({bool numbers = false}) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is SettingRow &&
        (numbers
            ? ['数字字体', 'Number font'].contains(widget.title)
            : ['正文字体', 'Text font'].contains(widget.title)),
  ),
  matching: find.byType(FButton),
);

/// Reveal a control through the settings body's real scrolling surface,
/// including controls in lazily built appearance groups.
Future<void> revealSetting(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final declared = find.byType(TiSettingsView);
    final scrollable = find
        .descendant(
          of: declared.evaluate().isNotEmpty
              ? declared
              : find.byType(Scrollbar).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      250,
      maxScrolls: 60,
      scrollable: scrollable,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
