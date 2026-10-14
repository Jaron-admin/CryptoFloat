import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'portable_paths.dart';

enum DataStorageMode { portable, system }

const storageMarkerFileName = 'duomonitor_storage.json';
const legacyStorageMarkerFileName = 'metricperch_storage.json';
const systemStorageMarkerFileName = 'storage_mode.json';

class DataRoot {
  const DataRoot({
    required this.portableDirectory,
    required this.systemDirectory,
    required this.executableMarkerPath,
    required this.systemMarkerPath,
    this.legacyExecutableMarkerPath,
    this.legacySystemDirectory,
  });
  final String portableDirectory;
  final String systemDirectory;
  final String executableMarkerPath;

  /// Per-install fallback selector for read-only application folders.
  final String systemMarkerPath;
  final String? legacyExecutableMarkerPath;
  final String? legacySystemDirectory;
  String directoryFor(DataStorageMode mode) =>
      mode == DataStorageMode.system ? systemDirectory : portableDirectory;
  factory DataRoot.resolve({
    required String executable,
    required String operatingSystem,
    required Map<String, String> environment,
  }) {
    final paths = _paths(operatingSystem);
    final app = paths.dirname(executable);
    final system = systemDataDirectory(
      operatingSystem: operatingSystem,
      environment: environment,
    );
    final normalized = paths.normalize(app);
    final identity = operatingSystem == 'windows'
        ? normalized.replaceAll('/', r'\').toLowerCase()
        : normalized;
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(identity)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return DataRoot(
      portableDirectory: portableDataDirectory(
        executable: executable,
        operatingSystem: operatingSystem,
      ),
      systemDirectory: system,
      executableMarkerPath: paths.join(app, storageMarkerFileName),
      systemMarkerPath: paths.join(
        system,
        '.storage-selection',
        '${hash.toRadixString(16).padLeft(8, '0')}.json',
      ),
      legacyExecutableMarkerPath: paths.join(app, legacyStorageMarkerFileName),
      legacySystemDirectory: paths.join(
        paths.dirname(system),
        operatingSystem == 'linux' ? 'metricperch' : 'MetricPerch',
      ),
    );
  }
}

p.Context _paths(String os) =>
    p.Context(style: os == 'windows' ? p.Style.windows : p.Style.posix);
String systemDataDirectory({
  required String operatingSystem,
  required Map<String, String> environment,
}) {
  final paths = _paths(operatingSystem);
  final home = environment['HOME']?.trim();
  final userHome = home != null && home.isNotEmpty ? home : '/tmp';
  switch (operatingSystem) {
    case 'windows':
      final roaming = environment['APPDATA']?.trim();
      final profile = environment['USERPROFILE']?.trim();
      return paths.join(
        roaming != null && roaming.isNotEmpty
            ? roaming
            : paths.join(
                profile != null && profile.isNotEmpty
                    ? profile
                    : r'C:\Users\Default',
                'AppData',
                'Roaming',
              ),
        'DuoMonitor',
      );
    case 'macos':
      return paths.join(
        userHome,
        'Library',
        'Application Support',
        'DuoMonitor',
      );
    default:
      final xdg = environment['XDG_DATA_HOME']?.trim();
      return paths.join(
        xdg != null && xdg.isNotEmpty
            ? xdg
            : paths.join(userHome, '.local', 'share'),
        'duomonitor',
      );
  }
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

DataStorageMode resolveStorageMode({
  String? executableMarkerContents,
  String? systemMarkerContents,
  required bool portableSettingsExist,
}) {
  final mode = decodeStorageMode(executableMarkerContents);
  if (mode != null) return mode;
  if (portableSettingsExist) return DataStorageMode.portable;
  return decodeStorageMode(systemMarkerContents) ?? DataStorageMode.portable;
}

Future<DataStorageMode> readStoredStorageMode(DataRoot root) async {
  for (final path in [root.systemMarkerPath, root.executableMarkerPath]) {
    final raw = await _readIfExists(path);
    if (raw == null) continue;
    final mode = decodeStorageMode(raw);
    if (mode == null) throw const FormatException('storage_mode_invalid');
    return mode;
  }
  return resolveStorageMode(
    executableMarkerContents: root.legacyExecutableMarkerPath == null
        ? null
        : await _readIfExists(root.legacyExecutableMarkerPath!),
    systemMarkerContents: root.legacySystemDirectory == null
        ? null
        : await _readIfExists(
            p.join(root.legacySystemDirectory!, systemStorageMarkerFileName),
          ),
    portableSettingsExist: await File(
      p.join(root.portableDirectory, 'settings.json'),
    ).exists(),
  );
}

/// Product rename compatibility copies data, retaining the original folder.
Future<DataStorageMode> initializeDataStorage(DataRoot root) async {
  final mode = await readStoredStorageMode(root);
  final legacy = root.legacySystemDirectory;
  final selectedLegacy =
      !await File(root.executableMarkerPath).exists() &&
      !await File(root.systemMarkerPath).exists();
  if (selectedLegacy &&
      mode == DataStorageMode.system &&
      legacy != null &&
      !await File(p.join(root.systemDirectory, 'settings.json')).exists() &&
      await File(p.join(legacy, 'settings.json')).exists()) {
    await _replaceDataDirectory(
      legacy,
      root.systemDirectory,
      () => persistStorageMode(root, mode),
      // Earlier system-mode builds still stored new DPAPI blobs beside the exe.
      validate: (staging) => copyDataDirectory(
        p.join(root.portableDirectory, 'secrets'),
        p.join(staging, 'secrets'),
        overwrite: false,
      ),
    );
  }
  return mode;
}

Future<void> persistStorageMode(DataRoot root, DataStorageMode mode) async {
  final encoded = encodeStorageMode(mode);
  final previous = await _readIfExists(root.executableMarkerPath);
  try {
    await _writeAtomically(root.executableMarkerPath, encoded);
  } on FileSystemException {
    try {
      await _writeAtomically(root.systemMarkerPath, encoded);
      return;
    } on FileSystemException {
      throw const FormatException('storage_mode_unwritable');
    }
  }
  // A portable install needs no profile writes unless an old fallback exists.
  if (!await File(root.systemMarkerPath).exists()) return;
  try {
    await _writeAtomically(root.systemMarkerPath, encoded);
  } on FileSystemException {
    if (previous == null) {
      await File(root.executableMarkerPath).delete();
    } else {
      await _writeAtomically(root.executableMarkerPath, previous);
    }
    throw const FormatException('storage_mode_unwritable');
  }
}

Future<String> migrateDataStorage({
  required DataRoot root,
  required DataStorageMode from,
  required DataStorageMode to,
  required bool migrate,
  Future<void> Function(String)? validate,
}) async {
  final destination = root.directoryFor(to);
  if (from == to) return destination;
  if (migrate) {
    await _replaceDataDirectory(
      root.directoryFor(from),
      destination,
      () => persistStorageMode(root, to),
      validate: validate,
    );
  } else {
    await _checkWritable(destination);
    await validate?.call(destination);
    await persistStorageMode(root, to);
  }
  return destination;
}

Future<void> _replaceDataDirectory(
  String source,
  String destination,
  Future<void> Function() commit, {
  Future<void> Function(String)? validate,
}) async {
  final suffix = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
  final staging = Directory('$destination.migrating-$suffix');
  final previous = Directory('$destination.previous-$suffix');
  final target = Directory(destination);
  var movedPrevious = false;
  var installed = false;
  try {
    await staging.create(recursive: true);
    await copyDataDirectory(destination, staging.path, includeSelectors: true);
    await copyDataDirectory(
      source,
      staging.path,
      collisionBackup: p.join(staging.path, 'migration-backups', suffix),
    );
    await _checkWritable(staging.path);
    await validate?.call(staging.path);
    if (await target.exists()) {
      await target.rename(previous.path);
      movedPrevious = true;
    }
    await staging.rename(destination);
    installed = true;
    await commit();
  } catch (_) {
    if (installed && await target.exists()) {
      await target.delete(recursive: true);
    }
    if (movedPrevious) await previous.rename(destination);
    rethrow;
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
  if (movedPrevious && await previous.exists()) {
    try {
      await previous.delete(recursive: true);
    } on FileSystemException {
      /* Retain backup if cleanup fails. */
    }
  }
}

Future<void> copyDataDirectory(
  String sourcePath,
  String destinationPath, {
  String? collisionBackup,
  bool includeSelectors = false,
  bool overwrite = true,
}) async {
  final source = Directory(sourcePath);
  if (p.equals(p.normalize(sourcePath), p.normalize(destinationPath)) ||
      !await source.exists()) {
    return;
  }
  final files = await source
      .list(recursive: true, followLinks: false)
      .where((e) => e is File)
      .cast<File>()
      .toList();
  for (final file in files) {
    final relative = p.relative(file.path, from: source.path);
    final name = p.basename(file.path);
    if (!includeSelectors &&
        (name == storageMarkerFileName ||
            name == legacyStorageMarkerFileName ||
            name == systemStorageMarkerFileName ||
            p.split(relative).contains('.storage-selection'))) {
      continue;
    }
    final target = File(p.join(destinationPath, relative));
    if (!overwrite && await target.exists()) continue;
    if (collisionBackup != null && await target.exists()) {
      final backup = File(p.join(collisionBackup, relative));
      await backup.parent.create(recursive: true);
      await target.copy(backup.path);
    }
    await target.parent.create(recursive: true);
    await file.copy(target.path);
  }
}

Future<void> _checkWritable(String directory) async {
  final probe = File(
    p.join(
      directory,
      '.storage-check-${pid}_${DateTime.now().microsecondsSinceEpoch}',
    ),
  );
  try {
    await probe.parent.create(recursive: true);
    await probe.writeAsString('', flush: true);
  } on FileSystemException {
    throw const FormatException('storage_mode_unwritable');
  } finally {
    if (await probe.exists()) await probe.delete();
  }
}

Future<String?> _readIfExists(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> _writeAtomically(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final temporary = File(
    '$path.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}
