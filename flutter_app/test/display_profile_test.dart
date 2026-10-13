import 'dart:convert';
import 'dart:io';

import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/data/legacy_importer.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cross-kind display order persists through reload', () {
    final json = AppConfig.defaults.toJson();
    const order = ['metric:cpu.usage', 'asset:OKX:BTC-USDT', 'row:fixture'];
    json['displayOrder'] = order;
    expect(AppConfig.fromJson(json).toJson()['displayOrder'], order);
  });
  const fields = [
    CustomApiSource(
      id: 'weather',
      name: 'Weather',
      url: 'https://example.com/weather',
      fields: [
        CustomField(id: 'temperature', label: 'Temperature', path: 't'),
        CustomField(id: 'humidity', label: 'Humidity', path: 'h'),
      ],
    ),
  ];
  const templates = [
    DisplayRow(
      id: 'weather-row',
      segments: [
        DisplaySegment.literal('Now: '),
        DisplaySegment.field(
          assetId: 'custom:weather',
          fieldId: 'temperature',
          format: '.1f',
        ),
      ],
    ),
  ];

  test(
    'both displays enabled with taskbar metrics and no floating metrics',
    () {
      expect(AppConfig.defaults.floatingEnabled, isTrue);
      expect(AppConfig.defaults.taskbar.enabled, isTrue);
      expect(AppConfig.defaults.selectedMetricIds, isEmpty);
      expect(AppConfig.defaults.taskbar.profile.selectedMetricIds, [
        'cpu.usage',
        'memory.usage',
        'network.upload',
        'network.download',
      ]);
    },
  );

  test('taskbar edit keeps floating style and applies shared changes', () {
    final original = AppConfig.defaults.copyWith(
      headerName: 'Private title',
      displayRows: templates,
      customSources: fields,
    );
    final view = original
        .displayFor(DisplayTarget.taskbar)
        .copyWith(
          selectedAssetIds: ['YAHOO:MSFT'],
          selectedMetricIds: ['gpu.usage'],
          displayOrder: ['metric:gpu.usage', 'asset:YAHOO:MSFT'],
          fontSize: 22,
          numberFontFamily: 'Consolas',
          displayCurrency: 'CNY',
          unitLabelMode: 'compact',
          language: 'en',
          customAssets: [Asset.popular[1]],
          systemMonitor: const SystemMonitorSettings(
            networkAdapterId: 'fixture-adapter',
          ),
          taskbar: original.taskbar.copyWith(width: 480, lineCount: 1),
        );
    final edited = original.withDisplay(DisplayTarget.taskbar, view);
    expect(
      DisplayProfile.fromConfig(edited).toJson(),
      DisplayProfile.fromConfig(original).toJson(),
    );
    expect(edited.taskbar.profile.selectedAssetIds, ['YAHOO:MSFT']);
    expect(edited.taskbar.profile.displayOrder, [
      'metric:gpu.usage',
      'asset:YAHOO:MSFT',
    ]);
    expect(edited.taskbar.profile.fontSize, 22);
    expect(edited.taskbar.profile.numberFontFamily, 'Consolas');
    expect(edited.taskbar.profile.displayCurrency, 'CNY');
    expect(edited.taskbar.width, 480);
    expect(edited.taskbar.lineCount, 1);
    expect(edited.systemMonitor.networkAdapterId, 'fixture-adapter');
    expect(edited.language, 'en');
    expect(edited.customAssets.single.id, Asset.popular[1].id);
    expect(AppConfig.fromJson(edited.toJson()).toJson(), edited.toJson());
  });

  test('schema one custom automatic order survives hidden market rows', () {
    final old = AppConfig.defaults
        .copyWith(
          showDefaultRows: false,
          customSources: fields,
          displayRows: templates,
        )
        .toJson();
    old['schemaVersion'] = 1;
    final migrated = AppConfig.fromJson(old);
    expect(migrated.selectedCustomFieldIds, ['custom:weather|humidity']);
    expect(migrated.displayRows.single.toJson(), templates.single.toJson());
    expect(migrated.showDefaultRows, isFalse);
  });

  test('legacy text import shares custom selection normalization', () {
    final imported = importLegacyConfig({
      'custom_sources': fields.map((source) => source.toJson()).toList(),
      'display_rows': ['Now: {{weather.temperature;.1f}}'],
    });
    expect(imported.selectedCustomFieldIds, ['custom:weather|humidity']);
    expect(imported.displayRows.single.segments.last.fieldId, 'temperature');
    expect(imported.schemaVersion, 2);
  });

  test(
    'templates acquire unselected markets once and retain closed references',
    () {
      const row = DisplayRow(
        id: 'template',
        segments: [
          DisplaySegment.field(assetId: 'YAHOO:MSFT', fieldId: 'price'),
        ],
      );
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT'],
        showDefaultRows: false,
        displayRows: [row],
        taskbar: const TaskbarConfig(
          profile: DisplayProfile(
            displayRows: [row],
            selectedCustomFieldIds: ['custom:weather|humidity'],
            displayCurrency: 'CNY',
          ),
        ),
      );
      expect(config.acquisitionAssets.map((asset) => asset.id), ['YAHOO:MSFT']);
      expect(config.activeCustomSourceIds, {'weather'});
      expect(config.needsExchangeRates, isTrue);
      final disabled = config.copyWith(
        taskbar: config.taskbar.copyWith(enabled: false),
      );
      expect(disabled.activeCustomSourceIds, isEmpty);
      expect(
        DisplayDependencies.forConfig(
          disabled,
          includeDisabled: true,
        ).customFieldIds,
        {'custom:weather|humidity'},
      );
    },
  );

  test('schema one original backup outlives rolling saves', () async {
    final folder = await Directory.systemTemp.createTemp('profile_fixture_');
    try {
      final store = ConfigStore(directory: folder.path);
      final old = AppConfig.defaults.copyWith(headerName: 'Keep this').toJson();
      old['schemaVersion'] = 1;
      final text = jsonEncode(old);
      await File(store.configPath).writeAsString(text);
      final migrated = await store.load();
      await store.save(migrated);
      await store.save(migrated.copyWith(headerName: 'Later edit'));
      expect(
        await File('${store.configPath}.schema1.bak').readAsString(),
        text,
      );
    } finally {
      await folder.delete(recursive: true);
    }
  });
  test('schema one upgrades without losing a user title or template', () {
    final old = AppConfig.defaults
        .copyWith(headerName: 'My own title')
        .toJson();
    old['schemaVersion'] = 1;
    old['customSources'] = [
      const CustomApiSource(
        id: 'weather',
        name: 'Weather',
        url: 'https://example.com/weather',
        fields: [
          CustomField(id: 'temperature', label: 'Temperature', path: 't'),
        ],
      ).toJson(),
    ];
    final migrated = AppConfig.fromJson(old);
    expect(migrated.schemaVersion, 2);
    expect(migrated.headerName, 'My own title');
  });

  test('future schema remains intact when a fallback is later saved', () async {
    final folder = await Directory.systemTemp.createTemp('profile_fixture_');
    try {
      final store = ConfigStore(directory: folder.path);
      final original = jsonEncode({'schemaVersion': 99, 'future': 'keep me'});
      await File(store.configPath).writeAsString(original);
      final fallback = await store.load();
      await expectLater(store.save(fallback), throwsA(isA<FormatException>()));
      expect(await File(store.configPath).readAsString(), original);
    } finally {
      await folder.delete(recursive: true);
    }
  });

  test(
    'future backup also protects the original after damaged primary',
    () async {
      final folder = await Directory.systemTemp.createTemp('profile_fixture_');
      try {
        final store = ConfigStore(directory: folder.path);
        await File(store.configPath).writeAsString('damaged primary');
        final backup = jsonEncode({
          'schemaVersion': 99,
          'future': 'backup contents',
        });
        await File('${store.configPath}.bak').writeAsString(backup);
        final fallback = await store.load();
        await expectLater(
          store.save(fallback),
          throwsA(isA<FormatException>()),
        );
        expect(store.canSave, isFalse);
        expect(await File('${store.configPath}.bak').readAsString(), backup);
      } finally {
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'a future file replacing a loaded profile cannot be overwritten',
    () async {
      final folder = await Directory.systemTemp.createTemp('profile_fixture_');
      try {
        final store = ConfigStore(directory: folder.path);
        final loaded = await store.load();
        final future = jsonEncode({
          'schemaVersion': '99',
          'future': 'new contents',
        });
        await File(store.configPath).writeAsString(future);
        await expectLater(store.save(loaded), throwsA(isA<FormatException>()));
        expect(await File(store.configPath).readAsString(), future);
      } finally {
        await folder.delete(recursive: true);
      }
    },
  );
}
