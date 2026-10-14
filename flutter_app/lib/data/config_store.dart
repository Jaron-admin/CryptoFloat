import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';
import 'legacy_importer.dart';
import 'source_security.dart';
import 'portable_paths.dart';

/// Each portable folder has its own settings; legacy profile data stays untouched.
class ConfigStore {
  ConfigStore({String? directory}) : this._(directory);

  ConfigStore._(this._directory);

  String? _directory;
  String get directory => _directory ?? portableDataDirectory();
  String get configPath => '$directory${Platform.pathSeparator}settings.json';

  void useDirectory(String directory) {
    _directory = directory;
  }
  String? resourcePath(String reference) =>
      portableResourcePath(directory, reference);
  String? loadWarning;
  String? _saveBlockedReason;
  bool get canSave => _saveBlockedReason == null;
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
    _saveBlockedReason = null;
    final file = File(configPath);
    if (!await file.exists()) return AppConfig.defaults;
    try {
      return await _read(file);
    } on Object catch (error) {
      if (error is FormatException && error.message == 'config_future_schema') {
        _saveBlockedReason = 'config_future_schema';
        loadWarning = '设置文件版本比本应用更新，已保留原文件并禁止覆盖。';
      }
      try {
        final config = await _read(File('$configPath.bak'));
        loadWarning ??= '设置文件无法读取，已恢复上次备份。原文件保留。';
        return config;
      } on Object {
        loadWarning ??= _saveBlockedReason != null
            ? '设置文件版本比本应用更新，已保留原文件并禁止覆盖。'
            : '设置文件无法读取，已使用默认设置。原文件保留。';
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
    final numericVersion = version is num
        ? version
        : int.tryParse('$version') ?? 1;
    if (numericVersion > 2) {
      _saveBlockedReason = 'config_future_schema';
      throw const FormatException('config_future_schema');
    }
    final config = AppConfig.fromJson(decoded);
    // Keep the exact original across later rolling backups and repeated launches.
    if (numericVersion < 2) {
      final original = File('$configPath.schema1.bak');
      if (!await original.exists()) await file.copy(original.path);
    }
    return config;
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
    if (_saveBlockedReason != null || config.schemaVersion > 2) {
      throw const FormatException('config_future_schema');
    }
    final target = File(configPath);
    // Recheck disk state so a future file appearing after load stays protected.
    if (await target.exists()) {
      try {
        await _read(target);
      } on FormatException catch (error) {
        if (error.message == 'config_future_schema') {
          _saveBlockedReason = 'config_future_schema';
          rethrow;
        }
      }
    }
    for (final source in config.customSources) {
      validateSource(source);
    }
    final encoded = '${encodeJson(config.toJson())}\n';
    if (utf8.encode(encoded).length > _maxConfigBytes) {
      throw const FormatException('设置内容超过 2 MB。');
    }
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
        } on FormatException catch (error) {
          if (error.message == 'config_future_schema') rethrow;
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
