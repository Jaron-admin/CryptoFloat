import 'dart:convert';

enum MarketKind { crypto, equity }

class Asset {
  const Asset({
    required this.id,
    required this.provider,
    required this.symbol,
    required this.name,
    required this.kind,
    required this.currency,
  });

  final String id;
  final String provider;
  final String symbol;
  final String name;
  final MarketKind kind;
  final String currency;

  Map<String, Object?> toJson() => {
    'id': id,
    'provider': provider,
    'symbol': symbol,
    'name': name,
    'kind': kind.name,
    'currency': currency,
  };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: normalizeAssetId(
      _string(
        json['id'],
        '${normalizeProvider(json['provider'] ?? json['exchange'])}:${_string(json['symbol'], '')}',
      ),
    ),
    provider: normalizeProvider(json['provider'] ?? json['exchange']),
    symbol: _string(json['symbol'], '').trim().toUpperCase(),
    name: _string(json['name'], _string(json['symbol'], '')),
    kind:
        json['kind'] == 'equity' ||
            json['market'] == 'stock' ||
            normalizeProvider(json['provider'] ?? json['exchange']) == 'YAHOO'
        ? MarketKind.equity
        : MarketKind.crypto,
    currency: _string(
      json['currency'],
      _string(
        json['quote_currency'],
        inferCurrency(
          normalizeProvider(json['provider'] ?? json['exchange']),
          _string(json['symbol'], '').toUpperCase(),
        ),
      ),
    ),
  );

  static const popular = <Asset>[
    Asset(
      id: 'OKX:BTC-USDT',
      provider: 'OKX',
      symbol: 'BTC-USDT',
      name: 'Bitcoin',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'OKX:ETH-USDT',
      provider: 'OKX',
      symbol: 'ETH-USDT',
      name: 'Ethereum',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'OKX:SOL-USDT',
      provider: 'OKX',
      symbol: 'SOL-USDT',
      name: 'Solana',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'OKX:XRP-USDT',
      provider: 'OKX',
      symbol: 'XRP-USDT',
      name: 'XRP',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'OKX:DOGE-USDT',
      provider: 'OKX',
      symbol: 'DOGE-USDT',
      name: 'Dogecoin',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'OKX:ADA-USDT',
      provider: 'OKX',
      symbol: 'ADA-USDT',
      name: 'Cardano',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'OKX:AVAX-USDT',
      provider: 'OKX',
      symbol: 'AVAX-USDT',
      name: 'Avalanche',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'BINANCE:BTCUSDT',
      provider: 'BINANCE',
      symbol: 'BTCUSDT',
      name: 'Bitcoin',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'BINANCE:ETHUSDT',
      provider: 'BINANCE',
      symbol: 'ETHUSDT',
      name: 'Ethereum',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'KUCOIN:BTC-USDT',
      provider: 'KUCOIN',
      symbol: 'BTC-USDT',
      name: 'Bitcoin',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'KUCOIN:KCS-USDT',
      provider: 'KUCOIN',
      symbol: 'KCS-USDT',
      name: 'KuCoin Token',
      kind: MarketKind.crypto,
      currency: 'USDT',
    ),
    Asset(
      id: 'YAHOO:AAPL',
      provider: 'YAHOO',
      symbol: 'AAPL',
      name: 'Apple',
      kind: MarketKind.equity,
      currency: 'USD',
    ),
    Asset(
      id: 'YAHOO:MSFT',
      provider: 'YAHOO',
      symbol: 'MSFT',
      name: 'Microsoft',
      kind: MarketKind.equity,
      currency: 'USD',
    ),
    Asset(
      id: 'YAHOO:NVDA',
      provider: 'YAHOO',
      symbol: 'NVDA',
      name: 'NVIDIA',
      kind: MarketKind.equity,
      currency: 'USD',
    ),
    Asset(
      id: 'YAHOO:SPY',
      provider: 'YAHOO',
      symbol: 'SPY',
      name: 'S&P 500 ETF',
      kind: MarketKind.equity,
      currency: 'USD',
    ),
    Asset(
      id: 'YAHOO:TSLA',
      provider: 'YAHOO',
      symbol: 'TSLA',
      name: 'Tesla',
      kind: MarketKind.equity,
      currency: 'USD',
    ),
    Asset(
      id: 'YAHOO:600519.SS',
      provider: 'YAHOO',
      symbol: '600519.SS',
      name: '贵州茅台',
      kind: MarketKind.equity,
      currency: 'CNY',
    ),
    Asset(
      id: 'YAHOO:000001.SZ',
      provider: 'YAHOO',
      symbol: '000001.SZ',
      name: '平安银行',
      kind: MarketKind.equity,
      currency: 'CNY',
    ),
    Asset(
      id: 'YAHOO:300750.SZ',
      provider: 'YAHOO',
      symbol: '300750.SZ',
      name: '宁德时代',
      kind: MarketKind.equity,
      currency: 'CNY',
    ),
  ];
}

class CustomField {
  const CustomField({
    required this.id,
    required this.label,
    required this.path,
    this.unit = '',
  });

  final String id;
  final String label;
  final String path;
  final String unit;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'path': path,
    'unit': unit,
  };

  factory CustomField.fromJson(Map<String, dynamic> json) => CustomField(
    id: _string(json['id'], 'field'),
    label: _string(json['label'], _string(json['name'], '字段')),
    path: _string(json['path'], _string(json['json_path'], '')),
    unit: _string(json['unit'], ''),
  );
}

class CustomApiSource {
  const CustomApiSource({
    required this.id,
    required this.name,
    required this.url,
    this.headers = const {},
    this.secretHeaderRefs = const {},
    this.refreshSeconds = 60,
    this.fields = const [],
    this.enabled = true,
  });

  final String id;
  final String name;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> secretHeaderRefs;
  final int refreshSeconds;
  final List<CustomField> fields;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'headers': headers,
    'secretHeaderRefs': secretHeaderRefs,
    'refreshSeconds': refreshSeconds,
    'fields': fields.map((field) => field.toJson()).toList(),
    'enabled': enabled,
  };

  factory CustomApiSource.fromJson(Map<String, dynamic> json) =>
      CustomApiSource(
        id: _string(json['id'], 'custom'),
        name: _string(json['name'], '自定义数据源'),
        url: _string(json['url'], ''),
        headers: _stringMap(json['headers']),
        secretHeaderRefs: _stringMap(json['secretHeaderRefs']),
        refreshSeconds: _int(
          json['refreshSeconds'] ?? json['interval'],
          60,
        ).clamp(15, 3600),
        fields: _maps(json['fields']).map(CustomField.fromJson).toList(),
        enabled: _bool(json['enabled'], true),
      );
}

class DisplaySegment {
  const DisplaySegment.literal(String value)
    : text = value,
      assetId = null,
      fieldId = null,
      format = '';

  const DisplaySegment.field({
    required this.assetId,
    required this.fieldId,
    this.format = '',
  }) : text = '';

  final String text;
  final String? assetId;
  final String? fieldId;
  final String format;

  bool get isField => assetId != null && fieldId != null;

  Map<String, Object?> toJson() => {
    'text': text,
    'assetId': assetId,
    'fieldId': fieldId,
    'format': format,
  };

  factory DisplaySegment.fromJson(Map<String, dynamic> json) =>
      json['fieldId'] == null
      ? DisplaySegment.literal(_string(json['text'], ''))
      : DisplaySegment.field(
          assetId: _string(json['assetId'], ''),
          fieldId: _string(json['fieldId'], ''),
          format: _string(json['format'], ''),
        );
}

class DisplayRow {
  const DisplayRow({required this.id, required this.segments});

  final String id;
  final List<DisplaySegment> segments;

  Map<String, Object?> toJson() => {
    'id': id,
    'segments': segments.map((segment) => segment.toJson()).toList(),
  };

  factory DisplayRow.fromJson(Map<String, dynamic> json) => DisplayRow(
    id: _string(json['id'], 'row'),
    segments: _maps(json['segments']).map(DisplaySegment.fromJson).toList(),
  );
}

class MarketQuote {
  const MarketQuote({
    required this.assetId,
    required this.price,
    required this.currency,
    required this.updatedAt,
    this.changePercent,
    this.extra = const {},
    this.error,
  });

  final String assetId;
  final double? price;
  final String currency;
  final DateTime updatedAt;
  final double? changePercent;
  final Map<String, Object?> extra;
  final String? error;

  bool get isStale => error != null;

  Object? field(String name) => extra.containsKey(name)
      ? extra[name]
      : switch (name) {
          'price' => price,
          'currency' || 'unit' => currency,
          'change' || 'changePercent' => changePercent,
          'updatedAt' => updatedAt,
          _ => extra[name],
        };

  MarketQuote withError(String message) => MarketQuote(
    assetId: assetId,
    price: price,
    currency: currency,
    updatedAt: updatedAt,
    changePercent: changePercent,
    extra: extra,
    error: message,
  );
}

class WindowBounds {
  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.displayId = '',
    this.scale = 1,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final String displayId;
  final double scale;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'displayId': displayId,
    'scale': scale,
  };

  factory WindowBounds.fromJson(Map<String, dynamic> json) => WindowBounds(
    x: _double(json['x'], 40),
    y: _double(json['y'], 40),
    width: _double(json['width'], 420),
    height: _double(json['height'], 280),
    displayId: _string(json['displayId'], ''),
    scale: _double(json['scale'], 1),
  );
}

class UnitConversionRule {
  const UnitConversionRule({
    required this.sourceUnit,
    required this.targetUnit,
    required this.multiplier,
  });
  final String sourceUnit;
  final String targetUnit;
  final double multiplier;
  Map<String, Object?> toJson() => {
    'sourceUnit': sourceUnit,
    'targetUnit': targetUnit,
    'multiplier': multiplier,
  };
  factory UnitConversionRule.fromJson(Map<String, dynamic> json) =>
      UnitConversionRule(
        sourceUnit: _string(json['sourceUnit'], ''),
        targetUnit: _string(json['targetUnit'], ''),
        multiplier: _double(json['multiplier'], 0),
      );
}

/// Serializable semantic colors; kept independent of a particular UI toolkit.
class ThemePaletteData {
  const ThemePaletteData({
    required this.background,
    required this.surface,
    required this.foreground,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.positive,
    required this.negative,
  });

  final int background,
      surface,
      foreground,
      secondary,
      border,
      accent,
      positive,
      negative;

  static const lightDefaults = ThemePaletteData(
    background: 0xFFF3F3F3,
    surface: 0xFFFFFFFF,
    foreground: 0xFF242424,
    secondary: 0xFF616161,
    border: 0xFFD1D1D1,
    accent: 0xFF0F6CBD,
    positive: 0xFF107C10,
    negative: 0xFFC50F1F,
  );
  static const darkDefaults = ThemePaletteData(
    background: 0xFF202020,
    surface: 0xFF292929,
    foreground: 0xFFFFFFFF,
    secondary: 0xFFD6D6D6,
    border: 0xFF525252,
    accent: 0xFF479EF5,
    positive: 0xFF65D9AA,
    negative: 0xFFFF8391,
  );

  ThemePaletteData copyWith({
    int? background,
    int? surface,
    int? foreground,
    int? secondary,
    int? border,
    int? accent,
    int? positive,
    int? negative,
  }) => ThemePaletteData(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    foreground: foreground ?? this.foreground,
    secondary: secondary ?? this.secondary,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
  );

  Map<String, Object?> toJson() => {
    'background': background,
    'surface': surface,
    'foreground': foreground,
    'secondary': secondary,
    'border': border,
    'accent': accent,
    'positive': positive,
    'negative': negative,
  };

  factory ThemePaletteData.fromJson(
    Map<String, dynamic> json, {
    required ThemePaletteData fallback,
  }) => ThemePaletteData(
    background: _color(json['background'], fallback.background),
    surface: _color(json['surface'], fallback.surface),
    foreground: _color(json['foreground'], fallback.foreground),
    secondary: _color(json['secondary'], fallback.secondary),
    border: _color(json['border'], fallback.border),
    accent: _color(json['accent'], fallback.accent),
    positive: _color(json['positive'], fallback.positive),
    negative: _color(json['negative'], fallback.negative),
  );
}

class UserThemePreset {
  const UserThemePreset({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });
  final String id, name;
  final ThemePaletteData light, dark;

  UserThemePreset copyWith({
    String? name,
    ThemePaletteData? light,
    ThemePaletteData? dark,
  }) => UserThemePreset(
    id: id,
    name: name ?? this.name,
    light: light ?? this.light,
    dark: dark ?? this.dark,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'light': light.toJson(),
    'dark': dark.toJson(),
  };

  factory UserThemePreset.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) => UserThemePreset(
    id: _string(json['id'], fallbackId),
    name: _string(json['name'], '我的主题'),
    light: ThemePaletteData.fromJson(
      _map(json['light']),
      fallback: ThemePaletteData.lightDefaults,
    ),
    dark: ThemePaletteData.fromJson(
      _map(json['dark']),
      fallback: ThemePaletteData.darkDefaults,
    ),
  );
}

class AppConfig {
  const AppConfig({
    required this.selectedAssetIds,
    required this.customAssets,
    required this.customSources,
    required this.displayRows,
    required this.proxyEnabled,
    required this.proxyHost,
    required this.proxyPort,
    required this.alwaysOnTop,
    required this.opacity,
    required this.fontSize,
    required this.rowSpacing,
    this.fontFamily = 'Segoe UI',
    this.numberFontFamily = 'Segoe UI',
    this.backgroundColor = 0xFF10151D,
    this.lightBackgroundColor = 0xFFF3F3F3,
    this.themeMode = 'dark',
    this.lightTheme = 'fluent',
    this.darkTheme = 'custom',
    this.customThemes = const [],
    this.showDefaultRows = true,
    this.unitLabelMode = 'full',
    this.unitLabels = const {},
    this.displayCurrency = '',
    this.unitRules = const [],
    this.headerName = 'CryptoFloat',
    this.headerIcon = 'chart',
    this.headerImagePath = '',
    this.showHeaderName = true,
    this.showHeaderIcon = true,
    this.windowBounds,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final List<String> selectedAssetIds;
  final List<Asset> customAssets;
  final List<CustomApiSource> customSources;
  final List<DisplayRow> displayRows;

  /// Retained for old settings files. Requests now follow the system proxy.
  final bool proxyEnabled;
  final String proxyHost;
  final int proxyPort;
  final bool alwaysOnTop;
  final double opacity;
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
  final bool showDefaultRows;
  final String unitLabelMode;
  final Map<String, String> unitLabels;
  final String displayCurrency;
  final List<UnitConversionRule> unitRules;
  final String headerName;
  final String headerIcon;
  final String headerImagePath;
  final bool showHeaderName;
  final bool showHeaderIcon;
  final WindowBounds? windowBounds;

  static const defaults = AppConfig(
    selectedAssetIds: [
      'OKX:BTC-USDT',
      'OKX:ETH-USDT',
      'YAHOO:AAPL',
      'YAHOO:600519.SS',
    ],
    customAssets: [],
    customSources: [],
    displayRows: [],
    proxyEnabled: true,
    proxyHost: '127.0.0.1',
    proxyPort: 7890,
    alwaysOnTop: true,
    opacity: 0.96,
    fontSize: 15,
    rowSpacing: 8,
    themeMode: 'system',
    darkTheme: 'fluent',
  );

  List<Asset> get assets {
    final catalog = <String, Asset>{
      for (final asset in Asset.popular) asset.id: asset,
      for (final asset in customAssets) asset.id: asset,
    };
    return selectedAssetIds
        .map(normalizeAssetId)
        .toSet()
        .map((id) => catalog[id])
        .whereType<Asset>()
        .toList();
  }

  AppConfig copyWith({
    List<String>? selectedAssetIds,
    List<Asset>? customAssets,
    List<CustomApiSource>? customSources,
    List<DisplayRow>? displayRows,
    bool? proxyEnabled,
    String? proxyHost,
    int? proxyPort,
    bool? alwaysOnTop,
    double? opacity,
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
    bool? showDefaultRows,
    String? unitLabelMode,
    Map<String, String>? unitLabels,
    String? displayCurrency,
    List<UnitConversionRule>? unitRules,
    String? headerName,
    String? headerIcon,
    String? headerImagePath,
    bool? showHeaderName,
    bool? showHeaderIcon,
    WindowBounds? windowBounds,
    bool clearWindowBounds = false,
  }) => AppConfig(
    schemaVersion: schemaVersion,
    selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
    customAssets: customAssets ?? this.customAssets,
    customSources: customSources ?? this.customSources,
    displayRows: displayRows ?? this.displayRows,
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    proxyHost: proxyHost ?? this.proxyHost,
    proxyPort: proxyPort ?? this.proxyPort,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    opacity: opacity ?? this.opacity,
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
    showDefaultRows: showDefaultRows ?? this.showDefaultRows,
    unitLabelMode: unitLabelMode ?? this.unitLabelMode,
    unitLabels: unitLabels ?? this.unitLabels,
    displayCurrency: displayCurrency ?? this.displayCurrency,
    unitRules: unitRules ?? this.unitRules,
    headerName: headerName ?? this.headerName,
    headerIcon: headerIcon ?? this.headerIcon,
    headerImagePath: headerImagePath ?? this.headerImagePath,
    showHeaderName: showHeaderName ?? this.showHeaderName,
    showHeaderIcon: showHeaderIcon ?? this.showHeaderIcon,
    windowBounds: clearWindowBounds ? null : windowBounds ?? this.windowBounds,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'selectedAssetIds': selectedAssetIds,
    'customAssets': customAssets.map((asset) => asset.toJson()).toList(),
    'customSources': customSources.map((source) => source.toJson()).toList(),
    'displayRows': displayRows.map((row) => row.toJson()).toList(),
    'network': {
      'proxyEnabled': proxyEnabled,
      'proxyHost': proxyHost,
      'proxyPort': proxyPort,
    },
    'display': {
      'showDefaultRows': showDefaultRows,
      'unitLabelMode': unitLabelMode,
      'unitLabels': unitLabels,
      'displayCurrency': displayCurrency,
      'unitRules': unitRules.map((rule) => rule.toJson()).toList(),
    },
    'appearance': {
      'headerName': headerName,
      'headerIcon': headerIcon,
      'headerImagePath': headerImagePath,
      'showHeaderName': showHeaderName,
      'showHeaderIcon': showHeaderIcon,
      'alwaysOnTop': alwaysOnTop,
      'opacity': opacity,
      'fontSize': fontSize,
      'rowSpacing': rowSpacing,
      'fontFamily': fontFamily,
      'numberFontFamily': numberFontFamily,
      'backgroundColor': backgroundColor,
      'lightBackgroundColor': lightBackgroundColor,
      'themeMode': themeMode,
      'lightTheme': lightTheme,
      'darkTheme': darkTheme,
      'customThemes': customThemes.map((theme) => theme.toJson()).toList(),
    },
    if (windowBounds != null) 'windowBounds': windowBounds!.toJson(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final network = _map(json['network']);
    final appearance = _map(json['appearance']);
    final display = _map(json['display']);
    final legacySelected = json['selected_assets'];
    final customThemes = <UserThemePreset>[];
    final usedThemeIds = {
      'fluent',
      'catppuccin',
      'nord',
      'solarized',
      'custom',
    };
    for (final entry in _maps(appearance['customThemes']).indexed) {
      final theme = UserThemePreset.fromJson(
        entry.$2,
        fallbackId: 'user:imported-${entry.$1}',
      );
      var id = theme.id;
      var suffix = 0;
      while (usedThemeIds.contains(id)) {
        id = 'user:imported-${entry.$1}-${suffix++}';
      }
      usedThemeIds.add(id);
      // Repair conflicting IDs without dropping any saved palette.
      customThemes.add(
        UserThemePreset(
          id: id,
          name: theme.name,
          light: theme.light,
          dark: theme.dark,
        ),
      );
    }
    final selectedIds = json['selectedAssetIds'] is List
        ? (json['selectedAssetIds'] as List).whereType<String>().toList()
        : legacySelected is List
        ? legacySelected.whereType<String>().toList()
        : defaults.selectedAssetIds;
    return AppConfig(
      schemaVersion: _int(json['schemaVersion'], 1),
      selectedAssetIds: selectedIds.map(normalizeAssetId).toSet().toList(),
      customAssets: _unique(
        _maps(json['customAssets'] ?? json['custom_assets'])
            .map(Asset.fromJson),
        (asset) => asset.id,
      ),
      customSources: _unique(
        _maps(json['customSources'] ?? json['custom_sources'])
            .map(CustomApiSource.fromJson),
        (source) => source.id,
      ),
      displayRows: _maps(json['displayRows']).map(DisplayRow.fromJson).toList(),
      proxyEnabled: _bool(network['proxyEnabled'], true),
      proxyHost: _string(network['proxyHost'], '127.0.0.1'),
      proxyPort: _int(network['proxyPort'], 7890).clamp(1, 65535),
      alwaysOnTop: _bool(
        appearance['alwaysOnTop'] ?? json['always_on_top'],
        true,
      ),
      opacity: _double(
        appearance['opacity'] ?? json['alpha'],
        defaults.opacity,
      ).clamp(0.4, 1),
      fontSize: _double(
        appearance['fontSize'] ?? json['font_size'],
        defaults.fontSize,
      ).clamp(10, 32),
      rowSpacing: _double(
        appearance['rowSpacing'] ?? json['row_spacing'],
        defaults.rowSpacing,
      ).clamp(0, 32),
      fontFamily: _string(
        appearance['fontFamily'] ?? json['font_family'],
        defaults.fontFamily,
      ),
      numberFontFamily: _string(
        appearance['numberFontFamily'] ??
            json['number_font_family'] ??
            json['font_family'],
        defaults.numberFontFamily,
      ),
      backgroundColor: _color(
        appearance['backgroundColor'] ?? json['bg'],
        defaults.backgroundColor,
      ),
      showDefaultRows: _bool(display['showDefaultRows'], true),
      // Existing installations retain their saved dark custom background.
      lightBackgroundColor: _color(
        appearance['lightBackgroundColor'],
        0xFFF3F3F3,
      ),
      themeMode: ['system', 'light', 'dark'].contains(appearance['themeMode'])
          ? appearance['themeMode'] as String
          : 'dark',
      lightTheme: _themeId(appearance['lightTheme'], 'fluent', customThemes),
      darkTheme: _themeId(appearance['darkTheme'], 'custom', customThemes),
      customThemes: customThemes,
      unitLabelMode:
          ['full', 'compact', 'custom'].contains(display['unitLabelMode'])
          ? display['unitLabelMode'] as String
          : 'full',
      unitLabels: _stringMap(display['unitLabels']),
      displayCurrency: _string(display['displayCurrency'], '').toUpperCase(),
      unitRules: _maps(display['unitRules'])
          .map(UnitConversionRule.fromJson)
          .toList(),
      headerName: _string(appearance['headerName'], 'CryptoFloat'),
      headerIcon: _string(appearance['headerIcon'], 'chart'),
      headerImagePath: _string(appearance['headerImagePath'], ''),
      showHeaderName: _bool(appearance['showHeaderName'], true),
      showHeaderIcon: _bool(appearance['showHeaderIcon'], true),
      windowBounds: json['windowBounds'] is Map<String, dynamic>
          ? WindowBounds.fromJson(json['windowBounds'] as Map<String, dynamic>)
          : null,
    );
  }
}

String encodeJson(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);

String _themeId(Object? value, String fallback, List<UserThemePreset> themes) =>
    (['fluent', 'catppuccin', 'nord', 'solarized', 'custom'].contains(value) ||
        themes.any((theme) => theme.id == value))
    ? value as String
    : fallback;

String normalizeProvider(Object? value) {
  final name = _string(value, 'OKX').toUpperCase().replaceAll(' ', '');
  return switch (name) {
    'YAHOOFINANCE' => 'YAHOO',
    'KUCOINEXCHANGE' => 'KUCOIN',
    _ => name,
  };
}

String normalizeAssetId(String value) {
  final separator = value.indexOf(RegExp(r'[|:]'));
  if (separator < 0 || value.startsWith('custom:')) return value;
  return '${normalizeProvider(value.substring(0, separator))}:${value.substring(separator + 1).toUpperCase()}';
}

String inferCurrency(String provider, String symbol) {
  if (provider == 'YAHOO') {
    return RegExp(r'\.(SS|SZ|BJ)$').hasMatch(symbol) ? 'CNY' : 'USD';
  }
  if (symbol.contains('-')) return symbol.split('-').last;
  for (final currency in [
    'FDUSD',
    'USDT',
    'USDC',
    'TUSD',
    'BUSD',
    'USDP',
    'BTC',
    'ETH',
    'BNB',
    'EUR',
    'GBP',
    'JPY',
    'DAI',
    'USD',
  ]) {
    if (symbol.endsWith(currency) && symbol.length > currency.length) {
      return currency;
    }
  }
  return '';
}

bool isSensitiveHeader(String name) => RegExp(
  r'authorization|cookie|token|secret|password|api[-_]?key',
  caseSensitive: false,
).hasMatch(name);

List<T> _unique<T>(Iterable<T> values, String Function(T) key) {
  final entries = <String, T>{};
  for (final value in values) {
    entries[key(value)] = value;
  }
  return entries.values.toList();
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;
int _color(Object? value, int fallback) {
  if (value is int && value >= 0 && value <= 0xFFFFFFFF) return value;
  if (value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    return 0xFF000000 | int.parse(value.substring(1), radix: 16);
  }
  return fallback;
}

String _string(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;
int _int(Object? value, int fallback) => value is num && value.isFinite
    ? value.toInt()
    : int.tryParse('$value') ?? fallback;
double _double(Object? value, double fallback) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite ? number : fallback;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};
Map<String, String> _stringMap(Object? value) => value is Map
    ? value.map((key, val) => MapEntry('$key', '$val'))
    : <String, String>{};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList()
    : <Map<String, dynamic>>[];
