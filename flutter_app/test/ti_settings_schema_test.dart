import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/ti_settings_appearance.dart';
import 'package:cryptofloat/features/settings/ti_settings_schema.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  TiSettingsCatalog catalog({bool floating = true}) =>
      buildAppearanceCatalog(l10n, floating: floating);

  group('declaration', () {
    test('every declared default matches AppConfig.defaults', () {
      // The contract says a default must be good enough that most people never
      // change it. If the declaration and the config model drift apart, reset
      // silently moves the user somewhere the app never shipped as default.
      final config = AppConfig.defaults;
      for (final spec in catalog().allSpecs) {
        expect(
          spec.read(config),
          spec.defaultValue,
          reason: '${spec.key} declares ${spec.defaultValue} but the model '
              'defaults to ${spec.read(config)}',
        );
      }
    });

    test('a fresh config has nothing marked as changed', () {
      expect(catalog().modifiedCount(AppConfig.defaults), 0);
      for (final spec in catalog().allSpecs) {
        expect(spec.isModified(AppConfig.defaults), isFalse, reason: spec.key);
      }
    });

    test('keys are unique across the catalog', () {
      // The constructor throws on duplicates; building twice proves the
      // declaration is stable and does not depend on build order.
      expect(() => catalog(), returnsNormally);
      expect(() => catalog(), returnsNormally);
    });

    test('a duplicate key is rejected', () {
      final spec = TiSettingSpec.toggle(
        key: 'a.b',
        label: 'x',
        read: (config) => config.alwaysOnTop,
        write: (config, value) => config.copyWith(alwaysOnTop: value),
      );
      expect(
        () => TiSettingsCatalog(
          groups: [
            TiSettingGroup(
              id: 'one',
              section: TiSettingSection.general,
              title: 'one',
              items: [spec],
            ),
            TiSettingGroup(
              id: 'two',
              section: TiSettingSection.appearance,
              title: 'two',
              items: [spec],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a choice of three renders as segments, four as a dropdown', () {
      TiSettingType typeFor(int count) => TiSettingSpec.choice(
        key: 'k',
        label: 'l',
        options: [
          for (var i = 0; i < count; i++) TiSettingOption('$i', '$i'),
        ],
        defaultValue: '0',
        read: (config) => config.language,
        write: (config, value) => config.copyWith(language: value),
      ).type;

      expect(typeFor(2), TiSettingType.segment);
      expect(typeFor(3), TiSettingType.segment);
      expect(typeFor(4), TiSettingType.select);
    });

    test('groups come out in section order, not declaration order', () {
      final ordered = catalog().orderedGroups();
      final sections = ordered.map((group) => group.section.index).toList();
      expect(sections, orderedEquals([...sections]..sort()));
      // general must precede appearance
      expect(ordered.first.section, TiSettingSection.general);
    });
  });

  group('reset', () {
    test('resets a single setting and leaves the rest alone', () {
      final config = AppConfig.defaults.copyWith(fontSize: 28, rowSpacing: 2);
      final spec = catalog().allSpecs.firstWhere(
        (spec) => spec.key == 'appearance.fontSize',
      );

      final reset = spec.reset(config);

      expect(reset.fontSize, AppConfig.defaults.fontSize);
      expect(reset.rowSpacing, 2, reason: 'other keys must not move');
    });

    test('resets one group without touching another', () {
      final config = AppConfig.defaults.copyWith(fontSize: 28, language: 'en');
      final group = catalog().groups.firstWhere(
        (group) => group.id == 'appearance.text',
      );

      final reset = catalog().resetGroup(config, group);

      expect(reset.fontSize, AppConfig.defaults.fontSize);
      expect(reset.language, 'en');
    });

    test('resets everything', () {
      final config = AppConfig.defaults.copyWith(
        fontSize: 28,
        rowSpacing: 2,
        language: 'en',
        opacity: 0.5,
      );

      final reset = catalog().resetAll(config);

      expect(catalog().modifiedCount(reset), 0);
      expect(reset.language, AppConfig.defaults.language);
      expect(reset.opacity, AppConfig.defaults.opacity);
    });
  });

  group('export and import', () {
    test('exports only what differs from the defaults', () {
      final config = AppConfig.defaults.copyWith(fontSize: 20);
      final values = catalog().export(config);

      expect(values.keys, ['appearance.fontSize']);
      expect(values['appearance.fontSize'], 20);
    });

    test('a round trip restores the same config', () {
      final config = AppConfig.defaults.copyWith(
        fontSize: 21,
        rowSpacing: 3,
        language: 'en',
      );

      final result = catalog().import(
        AppConfig.defaults,
        catalog().export(config),
      );

      expect(result.skipped, isEmpty);
      expect(result.config.fontSize, 21);
      expect(result.config.rowSpacing, 3);
      expect(result.config.language, 'en');
    });

    test('unknown keys are skipped instead of rejected', () {
      // A file written by a newer build must still restore what it shares.
      final result = catalog().import(AppConfig.defaults, {
        'appearance.fontSize': 24,
        'future.setting': 'whatever',
      });

      expect(result.config.fontSize, 24);
      expect(result.skipped, ['future.setting']);
    });

    test('numbers arriving as ints still land in double fields', () {
      final result = catalog().import(AppConfig.defaults, {
        'appearance.rowSpacing': 6,
      });

      expect(result.config.rowSpacing, 6.0);
    });
  });

  group('search', () {
    test('finds a setting by its label', () {
      final hits = catalog().search('字号');
      expect(hits.expand((group) => group.specs).map((spec) => spec.key),
          contains('appearance.fontSize'));
    });

    test('finds a setting by its key', () {
      final hits = catalog().search('appearance.rowSpacing');
      expect(hits, isNotEmpty);
    });

    test('an empty query returns everything', () {
      final all = catalog().search('');
      expect(
        all.expand((group) => group.items).length,
        catalog().groups.expand((group) => group.items).length,
      );
    });

    test('a miss returns nothing', () {
      expect(catalog().search('zzzz-not-a-setting'), isEmpty);
    });
  });

  group('visibility', () {
    test('the panel-only groups disappear for the taskbar surface', () {
      final floating = catalog(floating: true);
      final taskbar = catalog(floating: false);

      expect(
        floating.groups.map((group) => group.id),
        contains('appearance.window'),
      );
      expect(
        taskbar.groups.map((group) => group.id),
        isNot(contains('appearance.window')),
      );
      expect(
        taskbar.groups.map((group) => group.id),
        isNot(contains('appearance.header')),
      );
    });
  });
}
