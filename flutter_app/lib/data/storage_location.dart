import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'portable_paths.dart';

enum DataStorageMode { portable, system }

const storageMarkerFileName = 'metricperch_storage.json';
const systemStorageMarkerFileName = 'storage_mode.json';

/// Roots and marker files for the portable folder and the system app-data folder.
class DataRoot {
  const DataRoot({
    required this.portableDirectory,
    required this.systemDirectory,
    required this.executableMarkerPath,
    required this.systemMarkerPath,
  });

  final String portableDirectory;
  final String systemDirectory;
  final String executableMarkerPath;
  final String systemMarkerPath;

  String directoryFor(DataStorageMode mode) => mode == DataStorageMode.system
      ? systemDirectory
      : portableDirectory;

  factory DataRoot.resolve({
    required String executable,
    required String operatingSystem,
    required Map<String, String> environment,
  }) {
    final paths = _paths(operatingSystem);
    final system = systemDataDirectory(
      operatingSystem: operatingSystem,
      environment: environment,
    );
    return DataRoot(
      portableDirectory: portableDataDirectory(
        executable: executable,
        operatingSystem: operatingSystem,
      ),
      systemDirectory: system,
      executableMarkerPath: paths.join(
        paths.dirname(executable),
        storageMarkerFileName,
      ),
      systemMarkerPath: paths.join(system, systemStorageMarkerFileName),
    );
  }
}

p.Context _paths(String operatingSystem) => p.Context(
  style: operatingSystem == 'windows' ? p.Style.windows : p.Style.posix,
);

String systemDataDirectory({
  required String operatingSystem,
  required Map<String, String> environment,
}) {
  final paths = _paths(operatingSystem);
  switch (operatingSystem) {
    case 'windows':
      final roaming = environment['APPDATA']?.trim();
      final profile = environment['USERPROFILE']?.trim();
      final base = roaming != null && roaming.isNotEmpty
          ? roaming
          : paths.join(
              profile != null && profile.isNotEmpty
                  ? profile
                  : r'C:\Users\Default',
              'AppData',
              'Roaming',
            );
      return paths.join(base, 'MetricPerch');
    case 'macos':
      return paths.join(
        _home(environment),
        'Library',
        'Application Support',
        'MetricPerch',
      );
    default:
      final configured = environment['XDG_DATA_HOME']?.trim();
      final base = configured != null && configured.isNotEmpty
          ? configured
          : paths.join(_home(environment), '.local', 'share');
      return paths.join(base, 'metricperch');
  }
}

String _home(Map<String, String> environment) {
  final home = environment['HOME']?.trim();
  return home != null && home.isNotEmpty ? home : '/tmp';
}

String encodeStorageMode(DataStorageMode mode) =>
    '${jsonEncode({'mode': mode.name})}\n';

DataStorageMode? decodeStorageMode(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return switch (decoded['mode']) {
      'portable' => DataStorageMode.portable,
      'system' => DataStorageMode.system,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// An executable marker travels with the app folder. Portable settings without
/// that marker keep the historical beside-the-exe location.
DataStorageMode resolveStorageMode({
  String? executableMarkerContents,
  String? systemMarkerContents,
  required bool portableSettingsExist,
}) {
  final executable = decodeStorageMode(executableMarkerContents);
  if (executable != null) return executable;
  if (portableSettingsExist) return DataStorageMode.portable;
  return decodeStorageMode(systemMarkerContents) ?? DataStorageMode.portable;
}

Future<DataStorageMode> readStoredStorageMode(DataRoot root) async {
  final settings = File(_child(root.portableDirectory, 'settings.json'));
  return resolveStorageMode(
    executableMarkerContents: await _readIfExists(root.executableMarkerPath),
    systemMarkerContents: await _readIfExists(root.systemMarkerPath),
    portableSettingsExist: await settings.exists(),
  );
}

Future<void> persistStorageMode(DataRoot root, DataStorageMode mode) async {
  final encoded = encodeStorageMode(mode);
  Object? executableError;
  try {
    await _writeAtomically(root.executableMarkerPath, encoded);
  } on FileSystemException catch (error) {
    executableError = error;
  }
  try {
    await _writeAtomically(root.systemMarkerPath, encoded);
  } on FileSystemException {
    if (executableError != null) {
      throw const FormatException('storage_mode_unwritable');
    }
    rethrow;
  }
  final portableSettings = await File(
    _child(root.portableDirectory, 'settings.json'),
  ).exists();
  if (executableError != null &&
      mode == DataStorageMode.system &&
      portableSettings) {
    throw const FormatException('storage_mode_unwritable');
  }
}

Future<String> migrateDataStorage({
  required DataRoot root,
  required DataStorageMode from,
  required DataStorageMode to,
  required bool migrate,
}) async {
  final destination = root.directoryFor(to);
  if (from != to && migrate) {
    await copyDataDirectory(root.directoryFor(from), destination);
  }
  if (from != to) await persistStorageMode(root, to);
  return destination;
}

Future<void> copyDataDirectory(String sourcePath, String destinationPath) async {
  final source = Directory(sourcePath);
  final destination = Directory(destinationPath);
  if (p.equals(p.normalize(source.path), p.normalize(destination.path))) return;
  if (!await source.exists()) return;
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name == storageMarkerFileName || name == systemStorageMarkerFileName) {
      continue;
    }
    final relative = p.relative(entity.path, from: source.path);
    final target = File(p.join(destination.path, relative));
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
  }
}

String _child(String directory, String name) =>
    '$directory${Platform.pathSeparator}$name';

Future<String?> _readIfExists(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  try {
    return await file.readAsString();
  } on FileSystemException {
    return null;
  }
}

Future<void> _writeAtomically(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents, flush: true);
}
