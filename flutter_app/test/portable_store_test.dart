import 'dart:convert';
import 'dart:io';

import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/data/portable_paths.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('portable executable paths', () {
    test('Windows data sits beside the executable regardless of cwd', () {
      expect(
        portableDataDirectory(
          executable: r'D:\Portable Apps\CryptoFloat\cryptofloat.exe',
          operatingSystem: 'windows',
        ),
        r'D:\Portable Apps\CryptoFloat\user_data',
      );
    });

    test('macOS data sits beside the app bundle', () {
      expect(
        portableDataDirectory(
          executable:
              '/Applications/CryptoFloat.app/Contents/MacOS/cryptofloat',
          operatingSystem: 'macos',
        ),
        '/Applications/user_data',
      );
    });

    test('a loose macOS executable keeps data in its parent folder', () {
      expect(
        portableDataDirectory(
          executable: '/Users/example/Portable/cryptofloat',
          operatingSystem: 'macos',
        ),
        '/Users/example/Portable/user_data',
      );
    });

    test('Linux data sits beside the executable', () {
      expect(
        portableDataDirectory(
          executable: '/opt/cryptofloat/cryptofloat',
          operatingSystem: 'linux',
        ),
        '/opt/cryptofloat/user_data',
      );
    });
  });

  group('portable configuration', () {
    late Directory fixture;
    late Directory appFolder;
    late ConfigStore store;

    setUp(() async {
      fixture = await Directory.systemTemp.createTemp('cryptofloat_portable_');
      appFolder = await Directory('${fixture.path}/application').create();
      store = ConfigStore(directory: '${appFolder.path}/user_data');
    });

    tearDown(() async {
      if (await fixture.exists()) await fixture.delete(recursive: true);
    });

    test(
      'first launch uses defaults and leaves a synthetic legacy profile alone',
      () async {
        final oldProfile = await Directory(
          '${fixture.path}/old-profile/CryptoFloatFlutter',
        ).create(recursive: true);
        final oldSettings = File('${oldProfile.path}/settings.json');
        final oldContents = jsonEncode(
          AppConfig.defaults.copyWith(headerName: 'Old profile only').toJson(),
        );
        await oldSettings.writeAsString(oldContents);

        await store.prepare();
        final first = await store.load();
        expect(first.toJson(), AppConfig.defaults.toJson());
        expect(store.loadWarning, isNull);
        expect(await File(store.configPath).exists(), isFalse);
        expect(await Directory(store.directory).list().toList(), isEmpty);
        expect(await oldSettings.readAsString(), oldContents);

        await store.save(first.copyWith(headerName: 'Portable profile'));
        expect((await store.load()).headerName, 'Portable profile');
        expect(await oldSettings.readAsString(), oldContents);
      },
    );

    test('save reload and backup stay in the portable directory', () async {
      final first = AppConfig.defaults.copyWith(
        headerName: 'Portable one',
        language: 'en',
      );
      final second = first.copyWith(headerName: 'Portable two');
      await store.save(first);
      await store.save(second);

      final reopened = ConfigStore(directory: store.directory);
      expect((await reopened.load()).toJson(), second.toJson());
      final backup = File('${store.configPath}.bak');
      expect(await backup.exists(), isTrue);
      expect(jsonDecode(await backup.readAsString()), first.toJson());
      final entries = await Directory(store.directory).list().toList();
      expect(
        entries.map((entry) => File(entry.path).uri.pathSegments.last),
        unorderedEquals(['settings.json', 'settings.json.bak']),
      );
    });

    test(
      'damaged primary recovers its local backup without replacing it',
      () async {
        await store.save(AppConfig.defaults.copyWith(headerName: 'Last good'));
        await store.save(AppConfig.defaults.copyWith(headerName: 'Newer'));
        await File(store.configPath).writeAsString('not valid json');

        final reopened = ConfigStore(directory: store.directory);
        expect((await reopened.load()).headerName, 'Last good');
        expect(reopened.loadWarning, contains('备份'));
        expect(await File(store.configPath).readAsString(), 'not valid json');
      },
    );

    test('moving the application retains relative image references', () async {
      await store.prepare();
      final icon = File('${store.directory}/icons/example.png');
      await icon.parent.create();
      await icon.writeAsBytes([1, 2, 3, 4]);
      await store.save(
        AppConfig.defaults.copyWith(headerImagePath: 'icons/example.png'),
      );

      final movedFolder = await appFolder.rename('${fixture.path}/moved');
      final moved = ConfigStore(directory: '${movedFolder.path}/user_data');
      final config = await moved.load();
      expect(config.headerImagePath, 'icons/example.png');
      final imagePath = moved.resourcePath(config.headerImagePath);
      expect(imagePath, isNotNull);
      expect(await File(imagePath!).readAsBytes(), [1, 2, 3, 4]);
      expect(await Directory(store.directory).exists(), isFalse);
      expect(
        await File(moved.configPath).readAsString(),
        isNot(contains(appFolder.path)),
      );
    });

    test('resource references accept portable separators', () {
      final expected =
          '${store.directory}${Platform.pathSeparator}icons${Platform.pathSeparator}a.png';
      expect(store.resourcePath('icons/a.png'), expected);
      expect(store.resourcePath(r'icons\a.png'), expected);
    });

    test('resource references reject traversal and absolute paths', () {
      for (final reference in [
        '',
        '../secret.png',
        'icons/../../secret.png',
        r'icons\..\secret.png',
        'icons/.. /secret.png',
        'icons/.../secret.png',
        'icons/a.png ',
        'icons/a.png.',
        'icons/./a.png',
        'icons//a.png',
        '/tmp/a.png',
        r'C:\Users\example\a.png',
        'C:/Users/example/a.png',
        'C:a.png',
        r'\\server\share\a.png',
        'file:///tmp/a.png',
        'icons/a.png\u0000',
      ]) {
        expect(store.resourcePath(reference), isNull, reason: reference);
      }
    });

    test(
      'a file blocking the data directory produces the storage error',
      () async {
        final blocked = File('${fixture.path}/blocked');
        await blocked.writeAsString('Keep this file');
        final blockedStore = ConfigStore(directory: blocked.path);
        final storageError = isA<FormatException>().having(
          (error) => error.message,
          'message',
          'portable_directory_unwritable',
        );

        await expectLater(blockedStore.prepare(), throwsA(storageError));
        await expectLater(
          blockedStore.save(AppConfig.defaults),
          throwsA(storageError),
        );
        expect(await blocked.readAsString(), 'Keep this file');
        expect(await File('${appFolder.path}/settings.json').exists(), isFalse);
      },
    );
  });
}
