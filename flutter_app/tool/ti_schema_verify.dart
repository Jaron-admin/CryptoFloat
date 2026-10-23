// Throwaway verification for the declared settings layer.
// Run with: dart run tool/ti_schema_verify.dart
//
// flutter_test cannot start in this environment (flutter_tester refuses the
// websocket), but the schema layer has no Flutter dependency, so the same
// assertions can be executed straight from the Dart VM.
import 'dart:io';

import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/ti_settings_schema.dart';

int failures = 0;

void check(String name, bool ok, [String extra = '']) {
  if (ok) {
    stdout.writeln('  ok    $name');
  } else {
    failures++;
    stdout.writeln('  FAIL  $name${extra.isEmpty ? '' : ' -> $extra'}');
  }
}

TiSettingsCatalog buildCatalog() => TiSettingsCatalog(
  groups: [
    TiSettingGroup(
      id: 'general.language',
      section: TiSettingSection.general,
      title: 'Language',
      items: [
        TiSettingSpec.choice(
          key: 'general.language',
          label: 'Language',
          defaultValue: 'system',
          options: const [
            TiSettingOption('system', 'System'),
            TiSettingOption('zh', 'Chinese'),
            TiSettingOption('en', 'English'),
          ],
          read: (config) => config.language,
          write: (config, value) => config.copyWith(language: value),
        ),
      ],
    ),
    TiSettingGroup(
      id: 'appearance.text',
      section: TiSettingSection.appearance,
      title: 'Text',
      items: [
        TiSettingSpec.range(
          key: 'appearance.fontSize',
          label: 'Font size',
          min: 10,
          max: 32,
          step: 1,
          defaultValue: AppConfig.defaults.fontSize,
          read: (config) => config.fontSize,
          write: (config, value) => config.copyWith(fontSize: value),
        ),
        TiSettingSpec.range(
          key: 'appearance.rowSpacing',
          label: 'Row spacing',
          min: 0,
          max: 24,
          step: 1,
          defaultValue: AppConfig.defaults.rowSpacing,
          read: (config) => config.rowSpacing,
          write: (config, value) => config.copyWith(rowSpacing: value),
        ),
        TiSettingSpec(
          key: 'appearance.transparency',
          type: TiSettingType.slider,
          label: 'Transparency',
          defaultValue: (1 - AppConfig.defaults.opacity) * 100,
          read: (config) => (1 - config.opacity) * 100,
          write: (config, value) =>
              config.copyWith(opacity: 1 - (value as num) / 100),
        ),
      ],
    ),
  ],
);

void main() {
  final catalog = buildCatalog();
  final defaults = AppConfig.defaults;

  stdout.writeln('defaults');
  check('nothing modified on a fresh config', catalog.modifiedCount(defaults) == 0,
      '${catalog.modifiedCount(defaults)} modified');
  check(
    'declared defaults match the model',
    catalog.allSpecs.every((spec) => spec.read(defaults) == spec.defaultValue),
    catalog.allSpecs
        .where((spec) => spec.read(defaults) != spec.defaultValue)
        .map((spec) => '${spec.key}: ${spec.read(defaults)} != ${spec.defaultValue}')
        .join(', '),
  );

  stdout.writeln('reset');
  final edited = defaults.copyWith(fontSize: 28, rowSpacing: 2, language: 'en');
  final fontSize = catalog.allSpecs.firstWhere((s) => s.key == 'appearance.fontSize');
  final afterOne = fontSize.reset(edited);
  check('single reset restores its own key', afterOne.fontSize == defaults.fontSize);
  check('single reset leaves others alone', afterOne.rowSpacing == 2);
  final textGroup = catalog.groups.firstWhere((g) => g.id == 'appearance.text');
  final afterGroup = catalog.resetGroup(edited, textGroup);
  check('group reset clears the group', afterGroup.fontSize == defaults.fontSize);
  check('group reset leaves other groups alone', afterGroup.language == 'en');
  final afterAll = catalog.resetAll(edited);
  check('reset all clears the counter', catalog.modifiedCount(afterAll) == 0);

  stdout.writeln('export / import');
  final exported = catalog.export(edited);
  check('export keeps only changed keys',
      exported.length == 3 && exported['appearance.fontSize'] == 28,
      exported.toString());
  final restored = catalog.import(defaults, exported);
  check('round trip restores values',
      restored.config.fontSize == 28 && restored.config.language == 'en');
  check('round trip reports nothing skipped', restored.skipped.isEmpty);
  final partial = catalog.import(defaults, {
    'appearance.rowSpacing': 6,
    'future.setting': 'x',
  });
  check('unknown keys are skipped', partial.skipped.length == 1);
  check('int lands in a double field', partial.config.rowSpacing == 6.0,
      '${partial.config.rowSpacing}');

  stdout.writeln('search');
  check('finds by label', catalog.search('font').isNotEmpty);
  check('finds by key',
      catalog.search('appearance.rowSpacing').isNotEmpty);
  check('empty query returns everything',
      catalog.search('').expand((g) => g.items).length ==
          catalog.groups.expand((g) => g.items).length);
  check('miss returns nothing', catalog.search('zzzz').isEmpty);

  stdout.writeln('declaration rules');
  check('three options render as segments',
      buildCatalog().allSpecs.first.type == TiSettingType.segment);
  var threw = false;
  try {
    TiSettingsCatalog(
      groups: [
        TiSettingGroup(
          id: 'a',
          section: TiSettingSection.general,
          title: 'a',
          items: [fontSize],
        ),
        TiSettingGroup(
          id: 'b',
          section: TiSettingSection.appearance,
          title: 'b',
          items: [fontSize],
        ),
      ],
    );
  } on ArgumentError {
    threw = true;
  }
  check('duplicate keys are rejected', threw);
  final ordered = catalog.orderedGroups();
  check('general comes before appearance',
      ordered.first.section == TiSettingSection.general);

  stdout.writeln('');
  stdout.writeln(failures == 0 ? 'ALL CHECKS PASSED' : '$failures CHECK(S) FAILED');
  exit(failures == 0 ? 0 : 1);
}
