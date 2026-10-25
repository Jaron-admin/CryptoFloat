import 'dart:convert';

import '../domain/models.dart';
import 'source_security.dart';

const maxSettingsTransferBytes = 2 * 1024 * 1024;

/// A safe diagnostic identifies a field, never its possibly secret value.
class SettingsTransferException extends FormatException {
  const SettingsTransferException(this.field, {this.unsupportedVersion = false})
    : super('Invalid settings file');
  final String field;
  final bool unsupportedVersion;
}

({AppConfig config, List<String> skipped}) decodeSettings(
  String text, {
  AppConfig? current,
}) {
  if (utf8.encode(text).length > maxSettingsTransferBytes) {
    throw const SettingsTransferException('fileSize');
  }
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const SettingsTransferException('JSON');
  }
  return importSettings(decoded, current: current);
}

/// Validate the entire document before exposing a replacement draft. The disk
/// loader remains lenient for recovery; interactive imports must not repair a
/// malformed file into a new configuration silently.
({AppConfig config, List<String> skipped}) importSettings(
  Object? value, {
  AppConfig? current,
}) {
  if (value is! Map<String, dynamic>) {
    throw const SettingsTransferException('JSON');
  }
  final rawVersion = value.containsKey('schemaVersion')
      ? value['schemaVersion']
      : 1;
  final version = rawVersion is String ? int.tryParse(rawVersion) : rawVersion;
  if (version is! int || (version != 1 && version != 2)) {
    throw const SettingsTransferException(
      'schemaVersion',
      unsupportedVersion: true,
    );
  }
  final skipped = <String>[];
  final input = Map<String, dynamic>.of(value)..['schemaVersion'] = version;
  final json = _object(input, _rootShape, '', skipped);
  // Keep all published legacy spellings supported by AppConfig.fromJson.
  if (json.isEmpty || !json.keys.any((key) => key != 'schemaVersion')) {
    throw const SettingsTransferException('JSON');
  }
  _uniqueIds(json['customSources'] ?? json['custom_sources'], 'customSources');
  _uniqueIds(json['customAssets'] ?? json['custom_assets'], 'customAssets');
  _validateRawThemes(json['appearance'] as Map<String, dynamic>?, 'appearance');
  _validateRawThemes(
    (json['taskbar'] as Map<String, dynamic>?)?['profile']
        as Map<String, dynamic>?,
    'taskbar.profile',
  );
  final config = AppConfig.fromJson(json);
  for (final source in config.customSources) {
    if (source.secretHeaderRefs.isNotEmpty) {
      throw const SettingsTransferException('customSources.secretHeaderRefs');
    }
    try {
      validateSource(source);
    } on FormatException {
      throw const SettingsTransferException('customSources');
    }
  }
  _validateProfile(
    DisplayProfile.fromConfig(config),
    config.customSources,
    'floating',
  );
  _validateProfile(config.taskbar.profile, config.customSources, 'taskbar');
  _removeDeviceSettings(json, skipped);
  var imported = AppConfig.fromJson(json);
  if (current != null) {
    imported = imported.copyWith(
      proxyEnabled: current.proxyEnabled,
      proxyHost: current.proxyHost,
      proxyPort: current.proxyPort,
      headerImagePath: current.headerImagePath,
      windowBounds: current.windowBounds,
      systemMonitor: imported.systemMonitor.copyWith(
        networkAdapterId: current.systemMonitor.networkAdapterId,
        gpuAdapterId: current.systemMonitor.gpuAdapterId,
        diskId: current.systemMonitor.diskId,
      ),
      taskbar: imported.taskbar.copyWith(
        profile: imported.taskbar.profile.copyWith(
          headerImagePath: current.taskbar.profile.headerImagePath,
        ),
      ),
    );
  }
  return (config: imported, skipped: List.unmodifiable(skipped));
}

/// A shareable export deliberately omits sources with headers or credentials,
/// and any selected fields/rows depending on those sources. Public sources and
/// independent display content remain intact on both surfaces.
({Map<String, dynamic> json, List<String> omitted}) exportSettings(
  AppConfig config,
) {
  final json = jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>;
  final omitted = <String>[];
  final sources = <Map<String, dynamic>>[];
  final excluded = <String>{};
  for (final source in config.customSources) {
    // Arbitrary header names can carry credentials (e.g. X-Key). A blacklist
    // cannot establish that their values are safe to share.
    var safe = source.headers.isEmpty && source.secretHeaderRefs.isEmpty;
    try {
      validateSource(source);
    } on FormatException {
      safe = false;
    }
    if (!safe) {
      excluded.add(source.id);
      omitted.add('customSources[${config.customSources.indexOf(source)}]');
      continue;
    }
    sources.add(
      Map<String, dynamic>.from(source.toJson())..remove('secretHeaderRefs'),
    );
  }
  json['customSources'] = sources;
  _removeSourceReferences(json, excluded, '', omitted);
  final profile =
      (json['taskbar'] as Map<String, dynamic>)['profile']
          as Map<String, dynamic>;
  _removeSourceReferences(profile, excluded, 'taskbar.profile.', omitted);
  _removeDeviceSettings(json, omitted);
  // Apply the same structural/dependency contract as the receiving side.
  importSettings(json);
  return (json: json, omitted: List.unmodifiable(omitted));
}

void _removeDeviceSettings(Map<String, dynamic> json, List<String> omitted) {
  void remove(Map<String, dynamic>? object, String key, String path) {
    if (object == null || !object.containsKey(key)) return;
    final value = object.remove(key);
    if (value != null && value != '') omitted.add(path);
  }

  remove(json, 'windowBounds', 'windowBounds');
  remove(json, 'network', 'network');
  remove(
    json['appearance'] as Map<String, dynamic>?,
    'headerImagePath',
    'appearance.headerImagePath',
  );
  final taskbar = json['taskbar'] as Map<String, dynamic>?;
  remove(
    taskbar?['profile'] as Map<String, dynamic>?,
    'headerImagePath',
    'taskbar.profile.headerImagePath',
  );
  final monitor = json['systemMonitor'] as Map<String, dynamic>?;
  for (final key in ['networkAdapterId', 'gpuAdapterId', 'diskId']) {
    remove(monitor, key, 'systemMonitor.$key');
  }
}

void _removeSourceReferences(
  Map<String, dynamic> json,
  Set<String> excluded,
  String prefix,
  List<String> omitted,
) {
  bool excludedField(String value) =>
      excluded.any((id) => value.startsWith('custom:$id|'));
  final fields = (json['selectedCustomFieldIds'] as List).cast<String>();
  json['selectedCustomFieldIds'] = fields
      .where((key) => !excludedField(key))
      .toList();
  if ((json['selectedCustomFieldIds'] as List).length != fields.length) {
    omitted.add('${prefix}selectedCustomFieldIds');
  }
  final removedRows = <String>{};
  json['displayRows'] = (json['displayRows'] as List).where((value) {
    final row = value as Map;
    final remove = (row['segments'] as List).any(
      (segment) => excluded.contains(
        (segment as Map)['assetId']?.toString().replaceFirst('custom:', ''),
      ),
    );
    if (remove) removedRows.add(row['id'] as String);
    return !remove;
  }).toList();
  if (removedRows.isNotEmpty) omitted.add('${prefix}displayRows');
  json['displayOrder'] = (json['displayOrder'] as List)
      .where(
        (key) =>
            !(key is String &&
                ((key.startsWith('field:') &&
                        excludedField(key.substring(6))) ||
                    removedRows.contains(key.replaceFirst('row:', '')))),
      )
      .toList();
}

void _validateProfile(
  DisplayProfile profile,
  List<CustomApiSource> sources,
  String path,
) {
  final fields = {
    for (final source in sources)
      for (final field in source.fields) customFieldKey(source.id, field.id),
  };
  for (final key in profile.selectedCustomFieldIds) {
    if (!fields.contains(key)) {
      throw SettingsTransferException('$path.selectedCustomFieldIds');
    }
  }
  final rowIds = <String>{};
  for (final row in profile.displayRows) {
    if (row.id.isEmpty || !rowIds.add(row.id)) {
      throw SettingsTransferException('$path.displayRows.id');
    }
    for (final segment in row.segments) {
      if (segment.isField &&
          (segment.assetId!.isEmpty ||
              segment.fieldId!.isEmpty ||
              (segment.assetId!.startsWith('custom:') &&
                  !fields.contains('${segment.assetId}|${segment.fieldId}')))) {
        throw SettingsTransferException('$path.displayRows.segments');
      }
    }
  }
  for (final rule in profile.unitRules) {
    if (rule.sourceUnit.trim().isEmpty ||
        rule.targetUnit.trim().isEmpty ||
        rule.multiplier <= 0) {
      throw SettingsTransferException('$path.unitRules');
    }
  }
  for (final themeId in [profile.lightTheme, profile.darkTheme]) {
    if (!const {
          'fluent',
          'catppuccin',
          'nord',
          'solarized',
          'custom',
        }.contains(themeId) &&
        !profile.customThemes.any((theme) => theme.id == themeId)) {
      throw SettingsTransferException('$path.customThemes');
    }
  }
}

void _uniqueIds(Object? value, String path) {
  if (value is! List) return;
  final ids = <String>{};
  for (final entry in value.cast<Map<String, dynamic>>()) {
    final id = entry['id'];
    if (id != null && (id is! String || id.isEmpty || !ids.add(id))) {
      throw SettingsTransferException('$path.id');
    }
  }
}

void _validateRawThemes(Map<String, dynamic>? value, String path) {
  if (value == null) return;
  final known = {'fluent', 'catppuccin', 'nord', 'solarized', 'custom'};
  for (final theme in (value['customThemes'] as List? ?? const [])) {
    final id = (theme as Map)['id'];
    if (id is! String || id.isEmpty || !known.add(id)) {
      throw SettingsTransferException('$path.customThemes.id');
    }
  }
  for (final key in ['lightTheme', 'darkTheme']) {
    if (value.containsKey(key) && !known.contains(value[key])) {
      throw SettingsTransferException('$path.$key');
    }
  }
}

final _rootShape = <String, Object?>{
  ...AppConfig.defaults.toJson(),
  'windowBounds': {
    'x': 0.0,
    'y': 0.0,
    'width': 0.0,
    'height': 0.0,
    'dpiScale': 1.0,
  },
  'selected_assets': <String>[],
  'custom_assets': <Object>[],
  'custom_sources': <Object>[],
  'always_on_top': true,
  'alpha': 1.0,
  'font_size': 15.0,
  'row_spacing': 8.0,
  'font_family': '',
  'number_font_family': '',
  'bg': 0,
};

final _listShapes = <String, Map<String, Object?>>{
  'customAssets': {
    ...Asset.popular.first.toJson(),
    'exchange': '',
    'market': '',
  },
  'customSources': {
    ...const CustomApiSource(id: '', name: '', url: '').toJson(),
    'interval': 60,
  },
  'fields': {
    ...const CustomField(id: '', label: '', path: '').toJson(),
    'name': '',
    'json_path': '',
  },
  'displayRows': const DisplayRow(id: '', segments: []).toJson(),
  'segments': const DisplaySegment.field(assetId: null, fieldId: null).toJson(),
  'unitRules': const UnitConversionRule(
    sourceUnit: '',
    targetUnit: '',
    multiplier: 1,
  ).toJson(),
  'customThemes': const UserThemePreset(
    id: '',
    name: '',
    light: ThemePaletteData.lightDefaults,
    dark: ThemePaletteData.darkDefaults,
  ).toJson(),
};

const _ranges = <String, (num, num)>{
  'fontSize': (10, 32),
  'font_size': (10, 32),
  'rowSpacing': (0, 32),
  'row_spacing': (0, 32),
  'opacity': (0.4, 1),
  'alpha': (0.4, 1),
  'proxyPort': (1, 65535),
  'panelColumnCount': (1, 8),
  'panelLabelValueGap': (0, 48),
  'panelColumnGap': (0, 48),
  'refreshSeconds': (15, 3600),
  'interval': (15, 3600),
  'intervalSeconds': (1, 60),
  'lineCount': (1, 2),
  'itemGap': (0, 24),
  'labelValueGap': (0, 24),
  'carouselIntervalSeconds': (2, 60),
  'decimalPlaces': (0, 8),
};
const _choices = <String, Set<String>>{
  'language': {'system', 'zh', 'en'},
  'themeMode': {'system', 'light', 'dark'},
  'priceColorMode': {'plain', 'theme', 'greenUp', 'redUp'},
  'marketColorStyle': {'theme', 'greenUp', 'redUp'},
  'panelItemLayout': {'horizontal', 'vertical'},
  'unitLabelMode': {'full', 'compact', 'custom'},
  'labelMode': {'short', 'full'},
  'overflowMode': {'auto', 'manual'},
  'kind': {'crypto', 'equity'},
};
const _colorKeys = {
  'backgroundColor',
  'lightBackgroundColor',
  'bg',
  'background',
  'surface',
  'foreground',
  'secondary',
  'border',
  'accent',
  'positive',
  'negative',
};

Map<String, dynamic> _object(
  Map<String, dynamic> value,
  Map<String, Object?> shape,
  String path,
  List<String> skipped,
) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final field = path.isEmpty ? entry.key : '$path.${entry.key}';
    if (!shape.containsKey(entry.key)) {
      skipped.add(field);
      continue;
    }
    result[entry.key] = _value(
      entry.value,
      shape[entry.key],
      entry.key,
      field,
      skipped,
    );
  }
  return result;
}

Object? _value(
  Object? value,
  Object? example,
  String key,
  String path,
  List<String> skipped,
) {
  Never invalid() => throw SettingsTransferException(path);
  if (_colorKeys.contains(key)) {
    if ((value is int && value >= 0 && value <= 0xFFFFFFFF) ||
        (value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value))) {
      return value;
    }
    invalid();
  }
  if (key == 'decimalPlaces') {
    if (value == null) return null;
    if (value is! int || value < 0 || value > 8) invalid();
    return value;
  }
  if (example == null) {
    if (value != null && value is! String) invalid();
    return value;
  }
  if (example is bool) {
    if (value is! bool) invalid();
    return value;
  }
  if (example is num) {
    if (value is! num || !value.isFinite || (example is int && value is! int)) {
      invalid();
    }
    final range = path == 'taskbar.width' ? (120, 1200) : _ranges[key];
    if (range != null && (value < range.$1 || value > range.$2)) invalid();
    return value;
  }
  if (example is String) {
    if (value is! String) invalid();
    if (_choices[key] case final choices?) {
      if (!choices.contains(value)) invalid();
    }
    return value;
  }
  if (example is List) {
    if (value is! List) invalid();
    final canonical = switch (key) {
      'custom_assets' => 'customAssets',
      'custom_sources' => 'customSources',
      _ => key,
    };
    final shape = _listShapes[canonical];
    if (shape == null) {
      if (value.any((item) => item is! String) ||
          value.toSet().length != value.length) {
        invalid();
      }
      return List<String>.from(value);
    }
    return [
      for (final item in value.indexed)
        if (item.$2 is Map<String, dynamic>)
          _object(
            item.$2 as Map<String, dynamic>,
            shape,
            '$path[${item.$1}]',
            skipped,
          )
        else
          invalid(),
    ];
  }
  if (example is Map) {
    if (value is! Map<String, dynamic>) invalid();
    if (const {
      'headers',
      'secretHeaderRefs',
      'unitLabels',
      'labelAliases',
    }.contains(key)) {
      if (value.values.any((item) => item is! String)) invalid();
      return Map<String, dynamic>.of(value);
    }
    if (key == 'priceFormats') {
      return {
        for (final entry in value.entries)
          entry.key: entry.value is Map<String, dynamic>
              ? _object(
                  entry.value as Map<String, dynamic>,
                  const {'compact': false, 'decimalPlaces': null},
                  '$path.${entry.key}',
                  skipped,
                )
              : invalid(),
      };
    }
    return _object(value, Map<String, Object?>.from(example), path, skipped);
  }
  invalid();
}
