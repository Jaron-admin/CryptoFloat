import 'dart:io';

import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/data/storage_location.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows system data uses the user profile and portable stays beside the exe', () {
    final root = DataRoot.resolve(
      executable: r'D:\Apps\MetricPerch\metricperch.exe',
      operatingSystem: 'windows',
      environment: {'APPDATA': r'C:\Users\ada\AppData\Roaming'},
    );
    expect(root.portableDirectory, r'D:\Apps\MetricPerch\user_data');
    expect(root.systemDirectory, r'C:\Users\ada\AppData\Roaming\MetricPerch');
    expect(
      root.executableMarkerPath,
      r'D:\Apps\MetricPerch\metricperch_storage.json',
    );
    expect(
      root.systemMarkerPath,
      r'C:\Users\ada\AppData\Roaming\MetricPerch\storage_mode.json',
    );
    expect(
      root.directoryFor(DataStorageMode.portable),
      root.portableDirectory,
    );
    expect(root.directoryFor(DataStorageMode.system), root.systemDirectory);
  });

  test('linux prefers XDG_DATA_HOME and otherwise uses the home data dir', () {
    final xdg = DataRoot.resolve(
      executable: '/opt/metricperch/metricperch',
      operatingSystem: 'linux',
      environment: {
        'HOME': '/home/ada',
        'XDG_DATA_HOME': '/home/ada/data',
      },
    );
    expect(xdg.portableDirectory, '/opt/metricperch/user_data');
    expect(xdg.systemDirectory, '/home/ada/data/metricperch');

    final fallback = DataRoot.resolve(
      executable: '/opt/metricperch/metricperch',
      operatingSystem: 'linux',
      environment: {'HOME': '/home/ada'},
    );
    expect(fallback.systemDirectory, '/home/ada/.local/share/metricperch');
  });

  test('macos system data uses Application Support', () {
    final root = DataRoot.resolve(
      executable: '/Applications/MetricPerch.app/Contents/MacOS/metricperch',
      operatingSystem: 'macos',
      environment: {'HOME': '/Users/ada'},
    );
    expect(root.portableDirectory, '/Applications/user_data');
    expect(
      root.systemDirectory,
      '/Users/ada/Library/Application Support/MetricPerch',
    );
  });

  test('a missing marker keeps an existing portable install', () {
    expect(
      resolveStorageMode(
        executableMarkerContents: null,
        systemMarkerContents: '{"mode":"system"}',
        portableSettingsExist: true,
      ),
      DataStorageMode.portable,
    );
  });

  test('the executable marker wins over leftover portable settings', () {
    expect(
      resolveStorageMode(
        executableMarkerContents: '{"mode":"system"}',
        systemMarkerContents: '{"mode":"portable"}',
        portableSettingsExist: true,
      ),
      DataStorageMode.system,
    );
  });

  test('the system marker applies when the folder has no portable settings', () {
    expect(
      resolveStorageMode(
        executableMarkerContents: null,
        systemMarkerContents: '{"mode":"system"}',
        portableSettingsExist: false,
      ),
      DataStorageMode.system,
    );
  });

  test('invalid or empty markers stay on the portable default', () {
    expect(
      resolveStorageMode(
        executableMarkerContents: '{',
        systemMarkerContents: '{"mode":"elsewhere"}',
        portableSettingsExist: false,
      ),
      DataStorageMode.portable,
    );
    expect(
      resolveStorageMode(
        executableMarkerContents: null,
        systemMarkerContents: null,
        portableSettingsExist: false,
      ),
      DataStorageMode.portable,
    );
  });

  test('migrate copies settings and icons without removing the original', () async {
    final fixture = await Directory.systemTemp.createTemp('metricperch_storage_');
    addTearDown(() => fixture.delete(recursive: true));
    final exeDir = await Directory('${fixture.path}/app').create();
    final portable = await Directory('${exeDir.path}/user_data').create();
    await File('${portable.path}/settings.json').writeAsString('{"keep":true}');
    final icon = File('${portable.path}/icons/a.png');
    await icon.parent.create();
    await icon.writeAsBytes([9, 8, 7]);
    final root = DataRoot.resolve(
      executable: '${exeDir.path}/metricperch',
      operatingSystem: 'linux',
      environment: {'HOME': fixture.path, 'XDG_DATA_HOME': '${fixture.path}/xdg'},
    );

    expect(await readStoredStorageMode(root), DataStorageMode.portable);
    final destination = await migrateDataStorage(
      root: root,
      from: DataStorageMode.portable,
      to: DataStorageMode.system,
      migrate: true,
    );
    expect(destination, root.systemDirectory);
    expect(await readStoredStorageMode(root), DataStorageMode.system);
    expect(
      await File('${root.systemDirectory}/settings.json').readAsString(),
      '{"keep":true}',
    );
    expect(
      await File('${root.systemDirectory}/icons/a.png').readAsBytes(),
      [9, 8, 7],
    );
    expect(await File('${portable.path}/settings.json').exists(), isTrue);
    expect(
      await File('${root.systemDirectory}/storage_mode.json').readAsString(),
      contains('"system"'),
    );
    expect(
      await File(root.executableMarkerPath).readAsString(),
      contains('"system"'),
    );

    await File('${root.systemDirectory}/icons/only-system.png').writeAsBytes([
      1,
    ]);
    await migrateDataStorage(
      root: root,
      from: DataStorageMode.system,
      to: DataStorageMode.portable,
      migrate: false,
    );
    expect(await readStoredStorageMode(root), DataStorageMode.portable);
    expect(
      await File('${portable.path}/icons/only-system.png').exists(),
      isFalse,
    );
    expect(await File('${portable.path}/settings.json').readAsString(), '{"keep":true}');
  });

  test('a copied tree does not treat the storage marker as user data', () async {
    final fixture = await Directory.systemTemp.createTemp('metricperch_copy_');
    addTearDown(() => fixture.delete(recursive: true));
    final source = Directory('${fixture.path}/system');
    await source.create();
    await File('${source.path}/settings.json').writeAsString('{}');
    await File('${source.path}/storage_mode.json').writeAsString('{"mode":"system"}');
    final destination = '${fixture.path}/user_data';
    await copyDataDirectory(source.path, destination);
    expect(await File('$destination/settings.json').exists(), isTrue);
    expect(await File('$destination/storage_mode.json').exists(), isFalse);
    expect(await File('${source.path}/settings.json').exists(), isTrue);
  });

  test(
    'system mode is rejected when portable settings exist and the exe marker cannot be written',
    () async {
      final fixture = await Directory.systemTemp.createTemp('metricperch_ro_');
      addTearDown(() => fixture.delete(recursive: true));
      final portable = await Directory('${fixture.path}/user_data').create();
      await File('${portable.path}/settings.json').writeAsString('{}');
      final blocked = File('${fixture.path}/not-a-directory');
      await blocked.writeAsString('x');
      final root = DataRoot(
        portableDirectory: portable.path,
        systemDirectory: '${fixture.path}/system',
        executableMarkerPath: '${blocked.path}/metricperch_storage.json',
        systemMarkerPath: '${fixture.path}/system/storage_mode.json',
      );

      await expectLater(
        persistStorageMode(root, DataStorageMode.system),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'storage_mode_unwritable',
          ),
        ),
      );
      expect(await readStoredStorageMode(root), DataStorageMode.portable);
    },
  );

  test('config saves follow the directory selected after a storage switch', () async {
    final fixture = await Directory.systemTemp.createTemp('metricperch_store_');
    addTearDown(() => fixture.delete(recursive: true));
    final store = ConfigStore(directory: '${fixture.path}/old');
    await store.save(AppConfig.defaults.copyWith(headerName: 'Kept'));
    store.useDirectory('${fixture.path}/new');
    await store.save(AppConfig.defaults.copyWith(headerName: 'Moved'));

    expect((await store.load()).headerName, 'Moved');
    final previous = ConfigStore(directory: '${fixture.path}/old');
    expect((await previous.load()).headerName, 'Kept');
  });
}
