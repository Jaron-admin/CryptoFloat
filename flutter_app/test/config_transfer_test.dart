import 'dart:convert';

import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/data/config_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> settings() =>
    jsonDecode(jsonEncode(AppConfig.defaults.toJson())) as Map<String, dynamic>;

void main() {
  for (final taskbar in [false, true]) {
    test(
      'rejects missing theme references before fallback (taskbar=$taskbar)',
      () {
        final json = settings();
        final target = taskbar
            ? (json['taskbar'] as Map)['profile'] as Map
            : json['appearance'] as Map;
        target['darkTheme'] = 'missing-user-theme';
        expect(() => importSettings(json), throwsFormatException);
      },
    );

    test(
      'rejects duplicate custom theme IDs before repair (taskbar=$taskbar)',
      () {
        final json = settings();
        final target = taskbar
            ? (json['taskbar'] as Map)['profile'] as Map
            : json['appearance'] as Map;
        const theme = UserThemePreset(
          id: 'user:duplicate',
          name: 'Duplicate',
          light: ThemePaletteData.lightDefaults,
          dark: ThemePaletteData.darkDefaults,
        );
        target['customThemes'] = [theme.toJson(), theme.toJson()];
        expect(() => importSettings(json), throwsFormatException);
      },
    );
  }

  test(
    'shareable settings preserve both displays and explicit mixed order',
    () {
      final config = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:ETH-USDT', 'OKX:BTC-USDT'],
        selectedMetricIds: ['cpu.usage'],
        displayOrder: [
          'asset:OKX:ETH-USDT',
          'metric:cpu.usage',
          'asset:OKX:BTC-USDT',
        ],
        fontSize: 22,
        taskbar: AppConfig.defaults.taskbar.copyWith(
          width: 420,
          profile: DisplayProfile.taskbarDefaults.copyWith(fontSize: 17),
        ),
      );
      final result = importSettings(exportSettings(config).json).config;
      expect(result.selectedAssetIds, config.selectedAssetIds);
      expect(result.displayOrder, config.displayOrder);
      expect(result.fontSize, 22);
      expect(result.taskbar.width, 420);
      expect(result.taskbar.profile.fontSize, 17);
    },
  );

  for (final version in [null, 3, 2.5, 0, -1, 'future', true]) {
    test('rejects unsupported or malformed version $version', () {
      final json = settings()..['schemaVersion'] = version;
      expect(() => importSettings(json), throwsFormatException);
    });
  }

  for (final value in ['large', true, 33, -1]) {
    test('rejects invalid font size $value without repairing it', () {
      final json = settings();
      (json['appearance'] as Map)['fontSize'] = value;
      expect(() => importSettings(json), throwsFormatException);
    });
  }

  test('rejects invalid nested collection types', () {
    final json = settings()..['customSources'] = 'not a list';
    expect(() => importSettings(json), throwsFormatException);
  });

  test('reports supported-version unknown keys at their actual location', () {
    final json = settings()..['futureSetting'] = true;
    (json['appearance'] as Map)['newEffect'] = 'x';
    final result = importSettings(json);
    expect(
      result.skipped,
      containsAll(['futureSetting', 'appearance.newEffect']),
    );
    expect(result.config.fontSize, AppConfig.defaults.fontSize);
  });

  test('rejects duplicate row IDs and dangling custom field references', () {
    final json = settings()
      ..['displayRows'] = [
        {
          'id': 'same',
          'segments': [
            {'text': 'one'},
          ],
        },
        {
          'id': 'same',
          'segments': [
            {'text': 'two'},
          ],
        },
      ];
    expect(() => importSettings(json), throwsFormatException);
    json['displayRows'] = [];
    json['selectedCustomFieldIds'] = ['custom:missing|price'];
    expect(() => importSettings(json), throwsFormatException);
  });

  test(
    'export removes credentials and their references from both displays',
    () {
      const field = CustomField(id: 'price', label: 'Price', path: 'price');
      final config = AppConfig.defaults.copyWith(
        customSources: [
          const CustomApiSource(
            id: 'key-header',
            name: 'Key header',
            url: 'https://example.test/data',
            headers: {'X-Key': 'private-x-key'},
            fields: [field],
          ),
          const CustomApiSource(
            id: 'public',
            name: 'Public',
            url: 'https://example.test/public',
            fields: [field],
          ),
          const CustomApiSource(
            id: 'secret',
            name: 'Private',
            url: 'https://example.test/private',
            secretHeaderRefs: {'Authorization': 'secret_local_ref'},
            fields: [field],
          ),
          const CustomApiSource(
            id: 'query',
            name: 'Query',
            url: 'https://example.test/data?token=private-token',
            fields: [field],
          ),
          const CustomApiSource(
            id: 'header',
            name: 'Header',
            url: 'https://example.test/data',
            headers: {'Authorization': 'private-header'},
            fields: [field],
          ),
        ],
        selectedCustomFieldIds: ['custom:public|price', 'custom:secret|price'],
        displayRows: const [
          DisplayRow(
            id: 'private-row',
            segments: [
              DisplaySegment.field(assetId: 'custom:secret', fieldId: 'price'),
            ],
          ),
        ],
        taskbar: AppConfig.defaults.taskbar.copyWith(
          profile: DisplayProfile.taskbarDefaults.copyWith(
            selectedCustomFieldIds: ['custom:secret|price'],
          ),
        ),
      );
      final exported = exportSettings(config);
      final encoded = jsonEncode(exported.json);
      for (final secret in [
        'secret_local_ref',
        'private-token',
        'private-header',
        'private-x-key',
        'secretHeaderRefs',
      ]) {
        expect(encoded, isNot(contains(secret)));
      }
      final restored = importSettings(exported.json).config;
      expect(restored.customSources.map((s) => s.id), ['public']);
      expect(restored.selectedCustomFieldIds, ['custom:public|price']);
      expect(restored.displayRows, isEmpty);
      expect(restored.taskbar.profile.selectedCustomFieldIds, isEmpty);
      expect(exported.omitted, isNotEmpty);
    },
  );

  test('export omits device paths and adapter choices in both targets', () {
    final config = AppConfig.defaults.copyWith(
      headerImagePath: 'icons/private.png',
      systemMonitor: const SystemMonitorSettings(
        networkAdapterId: 'local-device',
      ),
      taskbar: AppConfig.defaults.taskbar.copyWith(
        profile: DisplayProfile.taskbarDefaults.copyWith(
          headerImagePath: 'icons/taskbar.png',
        ),
      ),
    );
    final exported = exportSettings(config);
    expect(jsonEncode(exported.json), isNot(contains('headerImagePath')));
    expect(jsonEncode(exported.json), isNot(contains('local-device')));
    expect(importSettings(exported.json).config.headerImagePath, isEmpty);
    expect(exported.omitted, isNotEmpty);
  });

  test('accepts schema 1 migration and preserves legitimate identifiers', () {
    final json = settings()
      ..['schemaVersion'] = 1
      ..['selected_assets'] = ['OKX:ETH-USDT']
      ..remove('selectedAssetIds');
    expect(importSettings(json).config.selectedAssetIds, ['OKX:ETH-USDT']);
  });
}
