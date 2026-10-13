import '../domain/models.dart';

/// Converts legacy text templates and provider|symbol IDs without changing input.
AppConfig importLegacyConfig(Map<String, dynamic> legacy) {
  final parsed = AppConfig.fromJson(legacy);
  final catalog = <String, Asset>{
    for (final asset in Asset.popular) asset.id: asset,
    for (final asset in parsed.customAssets) asset.id: asset,
  };
  final selected = [...parsed.selectedAssetIds];
  final importedSources = parsed.customSources.map((source) {
    final raw = _listMaps(legacy['custom_sources'])
        .where((item) => item['id'] == source.id)
        .firstOrNull;
    // Python stores only header names here; encrypted values are separate.
    // Keep placeholders so the Flutter editor can ask the user to re-enter them.
    final names = raw?['headers'];
    final refs = {...source.secretHeaderRefs};
    if (names is List) {
      for (final name in names.whereType<String>()) {
        refs.putIfAbsent(name, () => 'legacy:${source.id}:$name');
      }
    }
    return CustomApiSource(
      id: source.id,
      name: source.name,
      url: source.url,
      headers: {
        for (final header in source.headers.entries)
          if (!isSensitiveHeader(header.key)) header.key: header.value,
      },
      secretHeaderRefs: refs,
      refreshSeconds: source.refreshSeconds,
      fields: source.fields,
      enabled: source.enabled,
    );
  }).toList();

  Asset? ensureAsset(String id) {
    final normalized = normalizeAssetId(id);
    if (catalog.containsKey(normalized)) return catalog[normalized];
    final separator = normalized.indexOf(':');
    if (separator < 1) return null;
    final provider = normalized.substring(0, separator);
    final symbol = normalized.substring(separator + 1);
    if (!{'OKX', 'KUCOIN', 'BINANCE', 'YAHOO'}.contains(provider) ||
        symbol.isEmpty) {
      return null;
    }
    final asset = Asset(
      id: normalized,
      provider: provider,
      symbol: symbol,
      name: symbol.split('-').first,
      kind: provider == 'YAHOO' ? MarketKind.equity : MarketKind.crypto,
      currency: inferCurrency(provider, symbol),
    );
    catalog[asset.id] = asset;
    return asset;
  }

  for (final id in selected) {
    ensureAsset(id);
  }

  final rows = <DisplayRow>[];
  final legacyRows = legacy['display_rows'];
  if (legacyRows is List) {
    for (final template in legacyRows.whereType<String>()) {
      final segments = <DisplaySegment>[];
      var cursor = 0;
      for (final match in RegExp(
        r'\{\{([^{};]*?)(?:;([^{}]*))?\}\}',
      ).allMatches(template)) {
        if (match.start > cursor) {
          segments.add(
            DisplaySegment.literal(template.substring(cursor, match.start)),
          );
        }
        final token = match.group(1)!.trim();
        String? assetId;
        String? fieldId;
        // Match custom source IDs first; units may themselves have a dot.
        for (final source in importedSources) {
          if (token.startsWith('${source.id}.')) {
            assetId = 'custom:${source.id}';
            fieldId = token.substring(source.id.length + 1);
            break;
          }
        }
        if (assetId == null) {
          final dot = token.lastIndexOf('.');
          if (dot > 0) {
            final asset = ensureAsset(token.substring(0, dot));
            if (asset != null) {
              assetId = asset.id;
              fieldId = token.substring(dot + 1);
              if (fieldId == 'updated_at') fieldId = 'updatedAt';
              if (!selected.contains(asset.id)) selected.add(asset.id);
            }
          }
        }
        segments.add(
          assetId == null || fieldId == null
              ? DisplaySegment.literal(match.group(0)!)
              : DisplaySegment.field(
                  assetId: assetId,
                  fieldId: fieldId,
                  format: match.group(2)?.trim() ?? '',
                ),
        );
        cursor = match.end;
      }
      if (cursor < template.length) {
        segments.add(DisplaySegment.literal(template.substring(cursor)));
      }
      rows.add(
        DisplayRow(id: 'imported_row_${rows.length + 1}', segments: segments),
      );
    }
  }
  final existingPopular = Asset.popular.map((asset) => asset.id).toSet();
  WindowBounds? bounds = parsed.windowBounds;
  if (bounds == null && (legacy['width'] is num || legacy['height'] is num)) {
    double number(Object? value, double fallback) =>
        value is num && value.isFinite ? value.toDouble() : fallback;
    bounds = WindowBounds(
      x: number(legacy['x'], 40),
      y: number(legacy['y'], 40),
      width: number(legacy['width'], 420).clamp(160, 2400),
      height: number(legacy['height'], 280).clamp(80, 2400),
    );
  }
  return parsed.copyWith(
    selectedAssetIds: selected.toSet().toList(),
    customAssets: catalog.values
        .where(
          (asset) =>
              !existingPopular.contains(asset.id) ||
              parsed.customAssets.any((custom) => custom.id == asset.id),
        )
        .toList(),
    customSources: importedSources,
    displayRows: legacyRows is List ? rows : parsed.displayRows,
    selectedCustomFieldIds: legacyCustomFieldSelection(
      importedSources,
      legacyRows is List ? rows : parsed.displayRows,
      showDefaultRows: parsed.showDefaultRows,
    ),
    windowBounds: bounds,
  );
}

List<Map<String, dynamic>> _listMaps(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
