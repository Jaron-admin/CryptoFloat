import 'dart:io';

import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/data/storage_location.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<DataRoot> fixture() async {
    final directory = await Directory.systemTemp.createTemp(
      'duomonitor_switch_',
    );
    addTearDown(() => directory.delete(recursive: true));
    return DataRoot(
      portableDirectory: '${directory.path}/app/user_data',
      systemDirectory: '${directory.path}/system',
      executableMarkerPath: '${directory.path}/app/duomonitor_storage.json',
      systemMarkerPath: '${directory.path}/system/storage_mode.json',
    );
  }

  test(
    'switch without copying loads the destination before the next save',
    () async {
      final root = await fixture();
      final source = ConfigStore(directory: root.portableDirectory);
      final destination = ConfigStore(directory: root.systemDirectory);
      final oldConfig = AppConfig.defaults.copyWith(
        headerName: 'Portable',
        selectedAssetIds: [],
      );
      await source.save(oldConfig);
      await destination.save(oldConfig.copyWith(headerName: 'System'));
      final controller = AppController(
        config: oldConfig,
        store: source,
        host: SettingsHost(),
        secrets: SettingsSecrets(),
        assetCatalog: SettingsCatalog(),
        dataRoot: root,
      );
      addTearDown(controller.dispose);

      await controller.switchStorage(DataStorageMode.system, migrate: false);
      expect(controller.config.headerName, 'System');
      await controller.apply(controller.config.copyWith(opacity: 0.8));
      expect((await destination.load()).headerName, 'System');
      expect(
        (await ConfigStore(
          directory: root.portableDirectory,
        ).load()).headerName,
        'Portable',
      );
    },
  );

  test(
    'copy and switch retains the overwritten destination configuration',
    () async {
      final root = await fixture();
      final source = ConfigStore(directory: root.portableDirectory);
      final destination = ConfigStore(directory: root.systemDirectory);
      await source.save(AppConfig.defaults.copyWith(headerName: 'Incoming'));
      await destination.save(
        AppConfig.defaults.copyWith(headerName: 'Existing'),
      );
      await migrateDataStorage(
        root: root,
        from: DataStorageMode.portable,
        to: DataStorageMode.system,
        migrate: true,
      );

      expect((await destination.load()).headerName, 'Incoming');
      final retained = await Directory(root.systemDirectory)
          .list(recursive: true)
          .where(
            (entity) => entity is File && entity.path.endsWith('settings.json'),
          )
          .cast<File>()
          .toList();
      final contents = await Future.wait(
        retained.map((file) => file.readAsString()),
      );
      expect(contents.any((text) => text.contains('Existing')), isTrue);
    },
  );

  for (final migrate in [false, true]) {
    test(
      'missing stored font does not block a valid storage switch (migrate=$migrate)',
      () async {
        final root = await fixture();
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        const channel = MethodChannel('cryptofloat/platform');
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'window.getFontData') {
            throw PlatformException(code: 'font_unavailable');
          }
          throw MissingPluginException();
        });
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });
        final selected = AppConfig.defaults.copyWith(
          headerName: 'Selected data',
          selectedAssetIds: [],
          fontFamily: 'Missing imported font $migrate',
        );
        final original = migrate
            ? selected
            : AppConfig.defaults.copyWith(
                headerName: 'Original data',
                selectedAssetIds: [],
              );
        final source = ConfigStore(directory: root.portableDirectory);
        await source.save(original);
        if (!migrate) {
          await ConfigStore(directory: root.systemDirectory).save(selected);
        }
        final controller = AppController(
          config: original,
          store: source,
          host: SettingsHost(),
          secrets: SettingsSecrets(),
          assetCatalog: SettingsCatalog(),
          dataRoot: root,
        );
        addTearDown(controller.dispose);

        await controller.switchStorage(
          DataStorageMode.system,
          migrate: migrate,
        );
        expect(controller.config.headerName, 'Selected data');
        expect(controller.config.fontFamily, 'Missing imported font $migrate');
        expect(controller.startupMessage, isNotNull);
        expect(await readStoredStorageMode(root), DataStorageMode.system);
        expect(
          (await ConfigStore(
            directory: root.systemDirectory,
          ).load()).headerName,
          'Selected data',
        );
        expect(
          (await ConfigStore(
            directory: root.portableDirectory,
          ).load()).headerName,
          migrate ? 'Selected data' : 'Original data',
        );
      },
    );
  }

  test(
    'failed mode persistence restores the destination and current selection',
    () async {
      final root = await fixture();
      await Directory(root.portableDirectory).create(recursive: true);
      await File('${root.portableDirectory}/settings.json')
          .writeAsString('incoming');
      await Directory(root.systemDirectory).create(recursive: true);
      await File('${root.systemDirectory}/settings.json')
          .writeAsString('existing');
      final blocker = File(
        '${Directory(root.portableDirectory).parent.path}/blocked',
      );
      await blocker.writeAsString('blocked');
      final blockedRoot = DataRoot(
        portableDirectory: root.portableDirectory,
        systemDirectory: root.systemDirectory,
        executableMarkerPath: '${blocker.path}/mode.json',
        systemMarkerPath: '${blocker.path}/fallback.json',
      );
      await expectLater(
        migrateDataStorage(
          root: blockedRoot,
          from: DataStorageMode.portable,
          to: DataStorageMode.system,
          migrate: true,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        await File('${root.systemDirectory}/settings.json').readAsString(),
        'existing',
      );
      expect(
        await readStoredStorageMode(blockedRoot),
        DataStorageMode.portable,
      );
    },
  );

  test(
    'portable selection succeeds without writing to the system directory',
    () async {
      final root = await fixture();
      final blocked = File(
        '${Directory(root.portableDirectory).parent.parent.path}/blocked',
      );
      await blocked.writeAsString('blocked');
      final isolated = DataRoot(
        portableDirectory: root.portableDirectory,
        systemDirectory: '${blocked.path}/data',
        executableMarkerPath: root.executableMarkerPath,
        systemMarkerPath: '${blocked.path}/selector.json',
      );
      await persistStorageMode(isolated, DataStorageMode.portable);
      expect(await readStoredStorageMode(isolated), DataStorageMode.portable);
      expect(await blocked.readAsString(), 'blocked');
    },
  );

  test('legacy system data is copied once and original files remain available', () async {
    final root = await fixture();
    final legacyPath =
        '${Directory(root.systemDirectory).parent.path}/MetricPerch';
    await ConfigStore(directory: legacyPath)
        .save(AppConfig.defaults.copyWith(headerName: 'Legacy'));
    final legacyMarker =
        '${Directory(root.portableDirectory).parent.path}/metricperch_storage.json';
    await File(legacyMarker).parent.create(recursive: true);
    await File(legacyMarker).writeAsString('{"mode":"system"}');
    final secret = File('${root.portableDirectory}/secrets/legacy.dpapi');
    await secret.parent.create(recursive: true);
    await secret.writeAsBytes([1, 2, 3]);
    final compatible = DataRoot(
      portableDirectory: root.portableDirectory,
      systemDirectory: root.systemDirectory,
      executableMarkerPath: root.executableMarkerPath,
      systemMarkerPath: root.systemMarkerPath,
      legacyExecutableMarkerPath: legacyMarker,
      legacySystemDirectory: legacyPath,
    );
    expect(await initializeDataStorage(compatible), DataStorageMode.system);
    expect(
      (await ConfigStore(directory: root.systemDirectory).load()).headerName,
      'Legacy',
    );
    expect(
      (await ConfigStore(directory: legacyPath).load()).headerName,
      'Legacy',
    );
    expect(
      await File('${root.systemDirectory}/secrets/legacy.dpapi').readAsBytes(),
      [1, 2, 3],
    );
    await File('${root.systemDirectory}/settings.json').delete();
    await initializeDataStorage(compatible);
    expect(
      await File('${root.systemDirectory}/settings.json').exists(),
      isFalse,
      reason: 'An explicit new selection must not reimport old settings after a no-copy switch.',
    );
  });

  test('an invalid new selector reports corruption instead of choosing a different store', () async {
    final root = await fixture();
    await File(root.executableMarkerPath).parent.create(recursive: true);
    await File(root.executableMarkerPath).writeAsString('{');
    await expectLater(
      readStoredStorageMode(root),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'storage_mode_invalid',
        ),
      ),
    );
  });
}
