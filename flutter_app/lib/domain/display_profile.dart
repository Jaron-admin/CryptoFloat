import 'models.dart';

enum DisplayTarget { floating, taskbar }

/// Content and appearance of one display, without credentials.
class DisplayProfile {
  const DisplayProfile({
    this.selectedAssetIds = const [],
    this.selectedCustomFieldIds = const [],
    this.displayOrder = const [],
    this.selectedMetricIds = const [],
    this.displayRows = const [],
    this.showDefaultRows = true,
    this.panelColumnCount = 1,
    this.panelItemLayout = 'horizontal',
    this.panelLabelValueGap = 8,
    this.panelColumnGap = 12,
    this.priceFormats = const {},
    this.showChangePercent = true,
    this.marketColorStyle = 'theme',
    this.fontSize = 15,
    this.rowSpacing = 8,
    this.fontFamily = 'Segoe UI',
    this.numberFontFamily = 'Segoe UI',
    this.backgroundColor = 0xFF10151D,
    this.lightBackgroundColor = 0xFFF3F3F3,
    this.themeMode = 'system',
    this.lightTheme = 'fluent',
    this.darkTheme = 'fluent',
    this.customThemes = const [],
    this.unitLabelMode = 'full',
    this.unitLabels = const {},
    this.displayCurrency = '',
    this.unitRules = const [],
    this.headerName = 'DuoMonitor',
    this.headerIcon = 'chart',
    this.headerImagePath = '',
    this.showHeaderName = true,
    this.showHeaderIcon = true,
  });

  final List<String> selectedAssetIds;
  final List<String> selectedCustomFieldIds;
  final List<String> displayOrder;
  final List<String> selectedMetricIds;
  final List<DisplayRow> displayRows;
  final bool showDefaultRows;
  final int panelColumnCount;
  final String panelItemLayout;
  final double panelLabelValueGap;
  final double panelColumnGap;
  final Map<String, PriceDisplayFormat> priceFormats;
  final bool showChangePercent;
  final String marketColorStyle;
  final double fontSize;
  final double rowSpacing;
  final String fontFamily;
  final String numberFontFamily;
  final int backgroundColor;
  final int lightBackgroundColor;
  final String themeMode;
  final String lightTheme;
  final String darkTheme;
  final List<UserThemePreset> customThemes;
  final String unitLabelMode;
  final Map<String, String> unitLabels;
  final String displayCurrency;
  final List<UnitConversionRule> unitRules;
  final String headerName;
  final String headerIcon;
  final String headerImagePath;
  final bool showHeaderName;
  final bool showHeaderIcon;

  static const taskbarDefaults = DisplayProfile(
    selectedMetricIds: [
      'cpu.usage',
      'memory.usage',
      'network.upload',
      'network.download',
    ],
    fontSize: 12,
    rowSpacing: 0,
    showHeaderName: false,
    showHeaderIcon: false,
  );
  factory DisplayProfile.fromConfig(AppConfig config) => DisplayProfile(
    selectedAssetIds: config.selectedAssetIds,
    selectedCustomFieldIds: config.selectedCustomFieldIds,
    displayOrder: config.displayOrder,
    selectedMetricIds: config.selectedMetricIds,
    displayRows: config.displayRows,
    showDefaultRows: config.showDefaultRows,
    panelColumnCount: config.panelColumnCount,
    panelItemLayout: config.panelItemLayout,
    panelLabelValueGap: config.panelLabelValueGap,
    panelColumnGap: config.panelColumnGap,
    priceFormats: config.priceFormats,
    showChangePercent: config.showChangePercent,
    marketColorStyle: config.marketColorStyle,
    fontSize: config.fontSize,
    rowSpacing: config.rowSpacing,
    fontFamily: config.fontFamily,
    numberFontFamily: config.numberFontFamily,
    backgroundColor: config.backgroundColor,
    lightBackgroundColor: config.lightBackgroundColor,
    themeMode: config.themeMode,
    lightTheme: config.lightTheme,
    darkTheme: config.darkTheme,
    customThemes: config.customThemes,
    unitLabelMode: config.unitLabelMode,
    unitLabels: config.unitLabels,
    displayCurrency: config.displayCurrency,
    unitRules: config.unitRules,
    headerName: config.headerName,
    headerIcon: config.headerIcon,
    headerImagePath: config.headerImagePath,
    showHeaderName: config.showHeaderName,
    showHeaderIcon: config.showHeaderIcon,
  );
  AppConfig applyTo(AppConfig config) => config.copyWith(
    selectedAssetIds: selectedAssetIds,
    selectedCustomFieldIds: selectedCustomFieldIds,
    displayOrder: displayOrder,
    selectedMetricIds: selectedMetricIds,
    displayRows: displayRows,
    showDefaultRows: showDefaultRows,
    panelColumnCount: panelColumnCount,
    panelItemLayout: panelItemLayout,
    panelLabelValueGap: panelLabelValueGap,
    panelColumnGap: panelColumnGap,
    priceFormats: priceFormats,
    showChangePercent: showChangePercent,
    marketColorStyle: marketColorStyle,
    fontSize: fontSize,
    rowSpacing: rowSpacing,
    fontFamily: fontFamily,
    numberFontFamily: numberFontFamily,
    backgroundColor: backgroundColor,
    lightBackgroundColor: lightBackgroundColor,
    themeMode: themeMode,
    lightTheme: lightTheme,
    darkTheme: darkTheme,
    customThemes: customThemes,
    unitLabelMode: unitLabelMode,
    unitLabels: unitLabels,
    displayCurrency: displayCurrency,
    unitRules: unitRules,
    headerName: headerName,
    headerIcon: headerIcon,
    headerImagePath: headerImagePath,
    showHeaderName: showHeaderName,
    showHeaderIcon: showHeaderIcon,
  );
  DisplayProfile copyWith({
    List<String>? selectedAssetIds,
    List<String>? selectedCustomFieldIds,
    List<String>? displayOrder,
    List<String>? selectedMetricIds,
    List<DisplayRow>? displayRows,
    bool? showDefaultRows,
    int? panelColumnCount,
    String? panelItemLayout,
    double? panelLabelValueGap,
    double? panelColumnGap,
    Map<String, PriceDisplayFormat>? priceFormats,
    bool? showChangePercent,
    String? marketColorStyle,
    double? fontSize,
    double? rowSpacing,
    String? fontFamily,
    String? numberFontFamily,
    int? backgroundColor,
    int? lightBackgroundColor,
    String? themeMode,
    String? lightTheme,
    String? darkTheme,
    List<UserThemePreset>? customThemes,
    String? unitLabelMode,
    Map<String, String>? unitLabels,
    String? displayCurrency,
    List<UnitConversionRule>? unitRules,
    String? headerName,
    String? headerIcon,
    String? headerImagePath,
    bool? showHeaderName,
    bool? showHeaderIcon,
  }) => DisplayProfile(
    selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
    selectedCustomFieldIds:
        selectedCustomFieldIds ?? this.selectedCustomFieldIds,
    selectedMetricIds: selectedMetricIds ?? this.selectedMetricIds,
    displayOrder: displayOrder ?? this.displayOrder,
    displayRows: displayRows ?? this.displayRows,
    showDefaultRows: showDefaultRows ?? this.showDefaultRows,
    panelColumnCount: panelColumnCount ?? this.panelColumnCount,
    panelItemLayout: panelItemLayout ?? this.panelItemLayout,
    panelLabelValueGap: _spacing(
      panelLabelValueGap ?? this.panelLabelValueGap,
      8,
    ),
    panelColumnGap: _spacing(panelColumnGap ?? this.panelColumnGap, 12),
    priceFormats: priceFormats ?? this.priceFormats,
    showChangePercent: showChangePercent ?? this.showChangePercent,
    marketColorStyle: marketColorStyle ?? this.marketColorStyle,
    fontSize: fontSize ?? this.fontSize,
    rowSpacing: rowSpacing ?? this.rowSpacing,
    fontFamily: fontFamily ?? this.fontFamily,
    numberFontFamily: numberFontFamily ?? this.numberFontFamily,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    lightBackgroundColor: lightBackgroundColor ?? this.lightBackgroundColor,
    themeMode: themeMode ?? this.themeMode,
    lightTheme: lightTheme ?? this.lightTheme,
    darkTheme: darkTheme ?? this.darkTheme,
    customThemes: customThemes ?? this.customThemes,
    unitLabelMode: unitLabelMode ?? this.unitLabelMode,
    unitLabels: unitLabels ?? this.unitLabels,
    displayCurrency: displayCurrency ?? this.displayCurrency,
    unitRules: unitRules ?? this.unitRules,
    headerName: headerName ?? this.headerName,
    headerIcon: headerIcon ?? this.headerIcon,
    headerImagePath: headerImagePath ?? this.headerImagePath,
    showHeaderName: showHeaderName ?? this.showHeaderName,
    showHeaderIcon: showHeaderIcon ?? this.showHeaderIcon,
  );
  Map<String, Object?> toJson() => {
    'selectedAssetIds': selectedAssetIds,
    'selectedCustomFieldIds': selectedCustomFieldIds,
    'displayOrder': displayOrder,
    'selectedMetricIds': selectedMetricIds,
    'displayRows': displayRows.map((value) => value.toJson()).toList(),
    'showDefaultRows': showDefaultRows,
    'panelColumnCount': panelColumnCount,
    'panelItemLayout': panelItemLayout,
    'panelLabelValueGap': panelLabelValueGap,
    'panelColumnGap': panelColumnGap,
    'priceFormats': priceFormats.map(
      (id, value) => MapEntry(id, value.toJson()),
    ),
    'showChangePercent': showChangePercent,
    'marketColorStyle': marketColorStyle,
    'fontSize': fontSize,
    'rowSpacing': rowSpacing,
    'fontFamily': fontFamily,
    'numberFontFamily': numberFontFamily,
    'backgroundColor': backgroundColor,
    'lightBackgroundColor': lightBackgroundColor,
    'themeMode': themeMode,
    'lightTheme': lightTheme,
    'darkTheme': darkTheme,
    'customThemes': customThemes.map((value) => value.toJson()).toList(),
    'unitLabelMode': unitLabelMode,
    'unitLabels': unitLabels,
    'displayCurrency': displayCurrency,
    'unitRules': unitRules.map((value) => value.toJson()).toList(),
    'headerName': headerName,
    'headerIcon': headerIcon,
    'headerImagePath': headerImagePath,
    'showHeaderName': showHeaderName,
    'showHeaderIcon': showHeaderIcon,
  };
  factory DisplayProfile.fromJson(Map<String, dynamic> json) {
    final parsed = AppConfig.fromJson({
      'schemaVersion': 2,
      'selectedAssetIds': json['selectedAssetIds'] ?? [],
      'selectedMetricIds': json['selectedMetricIds'] ?? [],
      'selectedCustomFieldIds': json['selectedCustomFieldIds'] ?? [],
      'displayOrder': json['displayOrder'] ?? [],
      'displayRows': json['displayRows'] ?? [],
      'display': {
        for (final key in [
          'showDefaultRows',
          'panelColumnCount',
          'panelItemLayout',
          'panelLabelValueGap',
          'panelColumnGap',
          'priceFormats',
          'showChangePercent',
          'marketColorStyle',
          'unitLabelMode',
          'unitLabels',
          'displayCurrency',
          'unitRules',
        ])
          key: json[key],
      },
      'appearance': {
        for (final key in [
          'fontSize',
          'rowSpacing',
          'fontFamily',
          'numberFontFamily',
          'backgroundColor',
          'lightBackgroundColor',
          'themeMode',
          'lightTheme',
          'darkTheme',
          'customThemes',
          'headerName',
          'headerIcon',
          'headerImagePath',
          'showHeaderName',
          'showHeaderIcon',
        ])
          key: json[key],
      },
    });
    return DisplayProfile.fromConfig(parsed);
  }
}

class TaskbarConfig {
  const TaskbarConfig({
    this.enabled = true,
    this.width = 360,
    this.lineCount = 2,
    this.labelMode = 'short',
    this.labelAliases = const {},
    this.itemGap = 6,
    this.labelValueGap = 4,
    this.overflowMode = 'auto',
    this.carouselIntervalSeconds = 5,
    this.transparentBackground = true,
    this.profile = DisplayProfile.taskbarDefaults,
  });
  final bool enabled;
  final double width;
  final int lineCount;
  final String labelMode;
  final Map<String, String> labelAliases;
  final int itemGap;
  final int labelValueGap;
  final String overflowMode;
  final int carouselIntervalSeconds;
  final bool transparentBackground;
  final DisplayProfile profile;
  TaskbarConfig copyWith({
    bool? enabled,
    double? width,
    int? lineCount,
    String? labelMode,
    Map<String, String>? labelAliases,
    int? itemGap,
    int? labelValueGap,
    String? overflowMode,
    int? carouselIntervalSeconds,
    bool? transparentBackground,
    DisplayProfile? profile,
  }) => TaskbarConfig(
    enabled: enabled ?? this.enabled,
    width: width ?? this.width,
    lineCount: lineCount ?? this.lineCount,
    labelMode: (labelMode ?? this.labelMode) == 'full' ? 'full' : 'short',
    labelAliases: _readTaskbarAliases(labelAliases ?? this.labelAliases),
    itemGap: (itemGap ?? this.itemGap).clamp(0, 24),
    labelValueGap: (labelValueGap ?? this.labelValueGap).clamp(0, 24),
    overflowMode: (overflowMode ?? this.overflowMode) == 'manual'
        ? 'manual'
        : 'auto',
    carouselIntervalSeconds:
        (carouselIntervalSeconds ?? this.carouselIntervalSeconds).clamp(2, 60),
    transparentBackground: transparentBackground ?? this.transparentBackground,
    profile: profile ?? this.profile,
  );
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'width': width,
    'lineCount': lineCount,
    'labelMode': labelMode == 'full' ? 'full' : 'short',
    'labelAliases': _readTaskbarAliases(labelAliases),
    'itemGap': itemGap.clamp(0, 24),
    'labelValueGap': labelValueGap.clamp(0, 24),
    'overflowMode': overflowMode == 'manual' ? 'manual' : 'auto',
    'carouselIntervalSeconds': carouselIntervalSeconds.clamp(2, 60),
    'transparentBackground': transparentBackground,
    'profile': profile.toJson(),
  };
  factory TaskbarConfig.fromJson(Map<String, dynamic> json) => TaskbarConfig(
    enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    width: json['width'] is num && (json['width'] as num).isFinite
        ? (json['width'] as num).toDouble().clamp(120, 1200)
        : 360,
    lineCount: json['lineCount'] == 1 ? 1 : 2,
    labelMode: json['labelMode'] == 'full' ? 'full' : 'short',
    labelValueGap: _taskbarInt(json['labelValueGap'], 4, 0, 24),
    overflowMode: json['overflowMode'] == 'manual' ? 'manual' : 'auto',
    carouselIntervalSeconds: _taskbarInt(
      json['carouselIntervalSeconds'],
      5,
      2,
      60,
    ),
    labelAliases: _readTaskbarAliases(json['labelAliases']),
    itemGap: json['itemGap'] is num && (json['itemGap'] as num).isFinite
        ? (json['itemGap'] as num).toInt().clamp(0, 24)
        : 6,
    transparentBackground: json['transparentBackground'] is bool
        ? json['transparentBackground'] as bool
        : true,
    profile: json['profile'] is Map<String, dynamic>
        ? DisplayProfile.fromJson(json['profile'] as Map<String, dynamic>)
        : DisplayProfile.taskbarDefaults,
  );
}

double _spacing(double value, double fallback) =>
    value.isFinite ? value.clamp(0, 48) : fallback;

int _taskbarInt(Object? value, int fallback, int minimum, int maximum) =>
    value is num && value.isFinite
    ? value.toInt().clamp(minimum, maximum)
    : fallback;

/// Aliases are display-only plain text; identifiers remain byte-for-byte intact.
String normalizeTaskbarAlias(String value) => String.fromCharCodes(
  value
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .runes
      .take(64),
);

Map<String, String> _readTaskbarAliases(Object? value) {
  if (value is! Map) return const {};
  return Map.unmodifiable({
    for (final entry in value.entries)
      if (entry.key is String &&
          (entry.key as String).trim().isNotEmpty &&
          entry.value is String &&
          normalizeTaskbarAlias(entry.value as String).isNotEmpty)
        entry.key as String: normalizeTaskbarAlias(entry.value as String),
  });
}

class SystemMonitorSettings {
  const SystemMonitorSettings({
    this.intervalSeconds = 1,
    this.networkAdapterId = 'auto',
    this.gpuAdapterId = 'auto',
    this.diskId = 'all',
  });
  final int intervalSeconds;
  final String networkAdapterId, gpuAdapterId, diskId;
  SystemMonitorSettings copyWith({
    int? intervalSeconds,
    String? networkAdapterId,
    String? gpuAdapterId,
    String? diskId,
  }) => SystemMonitorSettings(
    intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    networkAdapterId: networkAdapterId ?? this.networkAdapterId,
    gpuAdapterId: gpuAdapterId ?? this.gpuAdapterId,
    diskId: diskId ?? this.diskId,
  );
  Map<String, Object?> toJson() => {
    'intervalSeconds': intervalSeconds,
    'networkAdapterId': networkAdapterId,
    'gpuAdapterId': gpuAdapterId,
    'diskId': diskId,
  };
  factory SystemMonitorSettings.fromJson(Map<String, dynamic> json) =>
      SystemMonitorSettings(
        intervalSeconds:
            json['intervalSeconds'] is num &&
                (json['intervalSeconds'] as num).isFinite
            ? (json['intervalSeconds'] as num).toInt().clamp(1, 60)
            : 1,
        networkAdapterId: _deviceId(json['networkAdapterId'], 'auto'),
        gpuAdapterId: _deviceId(json['gpuAdapterId'], 'auto'),
        diskId: _deviceId(json['diskId'], 'all'),
      );
  static String _deviceId(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;
}
