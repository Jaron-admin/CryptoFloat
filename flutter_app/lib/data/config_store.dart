import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';
import 'legacy_importer.dart';
import 'source_security.dart';
import 'portable_paths.dart';

/// Each portable folder has its own settings; legacy profile data stays untouched.
class ConfigStore {
  ConfigStore({String? directory})
    : configPath =
          '${directory ?? portableDataDirectory()}${Platform.pathSeparator}settings.json';

  final String configPath;
  String get directory => File(configPath).parent.path;
  String? resourcePath(String reference) =>
      portableResourcePath(directory, reference);
  String? loadWarning;
  Future<void> _writeQueue = Future<void>.value();
  static const _maxConfigBytes = 2 * 1024 * 1024;

  Future<void> prepare() async {
    final folder = Directory(directory);
    File? probe;
    try {
      await folder.create(recursive: true);
      probe = File(
        '$directory${Platform.pathSeparator}.write-check-${pid}_${DateTime.now().microsecondsSinceEpoch}',
      );
      await probe.writeAsString('', flush: true);
    } on FileSystemException {
      throw const FormatException('portable_directory_unwritable');
    } finally {
      if (probe != null && await probe.exists()) {
        try {
          await probe.delete();
        } on FileSystemException {
          /* Report on save. */
        }
      }
    }
  }

  Future<AppConfig> load() async {
    loadWarning = null;
    final file = File(configPath);
    if (!await file.exists()) return AppConfig.defaults;
    try {
      return await _read(file);
    } on Object {
      try {
        final config = await _read(File('$configPath.bak'));
        loadWarning = '设置文件无法读取，已恢复上次备份。原文件保留。';
        return config;
      } on Object {
        loadWarning = '设置文件无法读取，已使用默认设置。原文件保留。';
        return AppConfig.defaults;
      }
    }
  }

  Future<AppConfig> _read(File file) async {
    if (await file.length() > _maxConfigBytes) {
      throw const FormatException('设置文件过大。');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('设置文件需要 JSON 对象。');
    }
    final version = decoded['schemaVersion'];
    if (version is num && version > 1) {
      throw const FormatException('设置文件版本比本应用更新。');
    }
    return AppConfig.fromJson(decoded);
  }

  /// Serializes concurrent saves; each replacement is renamed on the same disk.
  Future<void> save(AppConfig config) {
    final operation = _writeQueue.then((_) async {
      try {
        await _save(config);
      } on FileSystemException {
        throw const FormatException('portable_directory_unwritable');
      }
    });
    _writeQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _save(AppConfig config) async {
    for (final source in config.customSources) {
      validateSource(source);
    }
    final encoded = '${encodeJson(config.toJson())}\n';
    if (utf8.encode(encoded).length > _maxConfigBytes) {
      throw const FormatException('设置内容超过 2 MB。');
    }
    final target = File(configPath);
    await target.parent.create(recursive: true);
    final suffix = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final temporary = File('$configPath.$suffix.tmp');
    final temporaryBackup = File('$configPath.$suffix.bak.tmp');
    try {
      await temporary.writeAsString(encoded, flush: true);
      if (await target.exists()) {
        // Preserve a known-good backup when recovering from a corrupt file.
        try {
          await _read(target);
          await target.copy(temporaryBackup.path);
          await temporaryBackup.rename('$configPath.bak');
        } on FormatException {
          await target.copy('$configPath.corrupt.$suffix');
        }
      }
      await temporary.rename(configPath);
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (await temporaryBackup.exists()) await temporaryBackup.delete();
    }
  }

  /// Returns an imported settings draft; [save] applies it after the user saves.
  /// Legacy source and credentials are never changed or implicitly reused.
  Future<AppConfig> importLegacy(String path) async {
    final source = File(path);
    if (await source.length() > _maxConfigBytes) {
      throw const FormatException('旧版设置文件超过 2 MB。');
    }
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('旧版设置文件需要 JSON 对象。');
      }
      return importLegacyConfig(decoded);
    } on FormatException {
      // Parser errors can contain an input excerpt; never surface that excerpt.
      throw const FormatException('旧版设置文件不是有效的 JSON 设置对象。');
    }
  }
}
