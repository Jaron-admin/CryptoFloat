import 'models.dart';

/// Dependencies are selections and template references, never the source catalog.
class DisplayDependencies {
  const DisplayDependencies({
    this.assetIds = const {},
    this.customSourceIds = const {},
    this.customFieldIds = const {},
    this.metricIds = const {},
  });
  final Set<String> assetIds, customSourceIds, customFieldIds, metricIds;
  Set<String> get sourceKeys => {
    ...assetIds,
    for (final id in customSourceIds) 'custom:$id',
  };

  factory DisplayDependencies.forProfile(DisplayProfile profile) {
    final assets = <String>{
      if (profile.showDefaultRows)
        ...profile.selectedAssetIds.map(normalizeAssetId),
    };
    final fields = <String>{...profile.selectedCustomFieldIds};
    final metrics = <String>{...profile.selectedMetricIds};
    final sources = <String>{};
    for (final key in fields) {
      final separator = key.indexOf('|');
      if (key.startsWith('custom:') && separator > 7) {
        sources.add(key.substring(7, separator));
      }
    }
    for (final row in profile.displayRows) {
      for (final segment in row.segments.where((segment) => segment.isField)) {
        final id = segment.assetId!;
        if (id.startsWith('custom:')) {
          sources.add(id.substring(7));
          fields.add('$id|${segment.fieldId}');
        } else if (id == 'system' || id.startsWith('system:')) {
          metrics.add(id == 'system' ? segment.fieldId! : id.substring(7));
        } else {
          assets.add(normalizeAssetId(id));
        }
      }
    }
    return DisplayDependencies(
      assetIds: assets,
      customSourceIds: sources,
      customFieldIds: fields,
      metricIds: metrics,
    );
  }

  factory DisplayDependencies.forConfig(
    AppConfig config, {
    bool includeDisabled = false,
  }) {
    final profiles = [
      if (config.floatingEnabled || includeDisabled)
        DisplayProfile.fromConfig(config),
      if (config.taskbar.enabled || includeDisabled) config.taskbar.profile,
    ];
    final dependencies = profiles.map(DisplayDependencies.forProfile).toList();
    return DisplayDependencies(
      assetIds: {for (final value in dependencies) ...value.assetIds},
      customSourceIds: {
        for (final value in dependencies) ...value.customSourceIds,
      },
      customFieldIds: {
        for (final value in dependencies) ...value.customFieldIds,
      },
      metricIds: {for (final value in dependencies) ...value.metricIds},
    );
  }
}

String customFieldKey(String sourceId, String fieldId) =>
    'custom:$sourceId|$fieldId';

/// Old custom defaults omitted any field already represented by a template.
List<String> legacyCustomFieldSelection(
  List<CustomApiSource> sources,
  List<DisplayRow> rows, {
  bool showDefaultRows = true,
}) {
  final referenced = {
    for (final row in rows)
      for (final segment in row.segments)
        if (segment.isField) '${segment.assetId}|${segment.fieldId}',
  };
  return [
    for (final source in sources)
      for (final field in source.fields)
        if (!referenced.contains(customFieldKey(source.id, field.id)))
          customFieldKey(source.id, field.id),
  ];
}
