import 'display_formatter.dart';
import 'models.dart';
import 'refresh_status.dart';
import 'system_metric.dart';
import 'unit_conversion.dart';

class DisplayText {
  const DisplayText(
    this.label,
    this.value, {
    this.id = '',
    this.unit = '',
    this.stale = false,
    this.change,
  });
  final String id, label, value, unit;
  final bool stale;
  final double? change;
  String get text =>
      '${label.isEmpty ? '' : '$label '}$value${unit.isEmpty
          ? ''
          : unit == '%'
          ? unit
          : ' $unit'}';
}

/// Reserve a cell for the undisplayed count instead of rejecting a whole frame.
List<DisplayText> taskbarVisibleCells(
  List<DisplayText> cells, {
  required bool chinese,
}) => cells.length <= 32
    ? cells
    : [
        ...cells.take(31),
        DisplayText(
          '',
          chinese ? '+${cells.length - 31} 项' : '+${cells.length - 31} more',
        ),
      ];

/// Bound by UTF-16 units; never split a surrogate pair sent to the native host.
String boundedTaskbarText(String text, int limit) {
  final result = StringBuffer();
  var length = 0;
  final normalized = text.runes
      .map(
        (rune) => rune < 32 || rune == 127
            ? 32
            : rune >= 0xd800 && rune <= 0xdfff
            ? 0xfffd
            : rune,
      )
      .toList();
  for (var index = 0; index < normalized.length; index++) {
    final rune = normalized[index];
    final size = rune > 0xffff ? 2 : 1;
    final reserve = index < normalized.length - 1 ? 1 : 0;
    if (length + size + reserve > limit) {
      result.write('…');
      break;
    }
    result.writeCharCode(rune);
    length += size;
  }
  return result.toString();
}

MetricText metricTextFor(String id, MetricReading? reading, AppConfig view) {
  if (reading == null || !reading.valid) return const MetricText('—', '');
  final converted = convertUnitValue(
    reading.value!,
    reading.unit,
    view,
    const {},
  );
  if (converted.converted) {
    return MetricText(
      formatValue(converted.value),
      displayUnitLabel(converted.unit, view),
    );
  }
  final formatted = formatSystemMetric(id, reading);
  return MetricText(formatted.value, displayUnitLabel(formatted.unit, view));
}

Map<String, MarketQuote> withSystemQuote(
  Map<String, MarketQuote> quotes,
  SystemMetricSnapshot snapshot,
  int intervalSeconds, {
  DateTime? now,
}) => {
  ...quotes,
  'system': MarketQuote(
    assetId: 'system',
    price: null,
    currency: '',
    updatedAt: snapshot.sampledAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    extra: {
      for (final metric in systemMetricCatalog)
        metric.id:
            snapshot
                    .reading(
                      metric.id,
                      intervalSeconds: intervalSeconds,
                      now: now,
                    )
                    ?.valid ==
                true
            ? snapshot.values[metric.id]?.value
            : null,
    },
  ),
};

List<DisplayText> buildDisplayTexts(
  AppConfig view,
  Map<String, MarketQuote> quotes,
  SystemMetricSnapshot snapshot, {
  Map<String, double> rates = const {},
  DateTime? now,
}) {
  final combined = withSystemQuote(
    quotes,
    snapshot,
    view.systemMonitor.intervalSeconds,
    now: now,
  );
  final result = <DisplayText>[];
  if (view.showDefaultRows) {
    for (final asset in view.assets) {
      final quote = quotes[asset.id];
      final currency = quote?.currency.isNotEmpty == true
          ? quote!.currency
          : asset.currency;
      final converted = quote?.price == null
          ? null
          : convertUnitValue(quote!.price!, currency, view, rates);
      result.add(
        DisplayText(
          asset.symbol,
          formatValue(converted?.value),
          id: 'asset:${asset.id}',
          unit: displayUnitLabel(converted?.unit ?? currency, view),
          stale: quote == null || quote.isStale || converted?.error != null,
          change: quote?.changePercent,
        ),
      );
    }
  }
  for (final id in view.selectedMetricIds) {
    final metric = systemMetricCatalog
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (metric == null) continue;
    final reading = snapshot.reading(
      id,
      intervalSeconds: view.systemMonitor.intervalSeconds,
      now: now,
    );
    final formatted = metricTextFor(id, reading, view);
    result.add(
      DisplayText(
        metric.shortLabel,
        formatted.value,
        id: 'metric:$id',
        unit: formatted.unit,
        stale: reading?.valid != true,
      ),
    );
  }
  final referenced = {
    for (final row in view.displayRows)
      for (final segment in row.segments)
        if (segment.isField) '${segment.assetId}|${segment.fieldId}',
  };
  for (final key in view.selectedCustomFieldIds) {
    if (referenced.contains(key)) continue;
    for (final source in view.customSources.where((source) => source.enabled)) {
      for (final field in source.fields) {
        if (customFieldKey(source.id, field.id) != key) continue;
        final segment = DisplaySegment.field(
          assetId: 'custom:${source.id}',
          fieldId: field.id,
        );
        final quote = quotes[segment.assetId];
        result.add(
          DisplayText(
            field.label,
            renderSegment(segment, view, quotes, rates: rates),
            id: 'field:$key',
            stale: quote == null || quote.isFieldStale(field.id),
          ),
        );
      }
    }
  }
  for (final row in view.displayRows) {
    final dependencies = DisplayDependencies.forProfile(
      DisplayProfile(displayRows: [row]),
    );
    final stale =
        dependencies.assetIds.any(
          (id) => combined[id] == null || combined[id]!.isStale,
        ) ||
        dependencies.customFieldIds.any((key) {
          final split = key.lastIndexOf('|');
          final quote = combined[key.substring(0, split)];
          return quote == null || quote.isFieldStale(key.substring(split + 1));
        }) ||
        dependencies.metricIds.any(
          (id) =>
              snapshot
                  .reading(
                    id,
                    intervalSeconds: view.systemMonitor.intervalSeconds,
                    now: now,
                  )
                  ?.valid !=
              true,
        );
    result.add(
      DisplayText(
        '',
        renderRow(row, view, combined, rates: rates),
        id: 'row:${row.id}',
        stale: stale,
      ),
    );
  }
  final indexed = {for (final item in result) item.id: item};
  return [
    for (final id in orderedDisplayKeys(indexed.keys, view.displayOrder))
      indexed[id]!,
  ];
}

List<String> orderedDisplayKeys(
  Iterable<String> available,
  List<String> order,
) {
  final keys = available.toSet();
  return {...order.where(keys.contains), ...keys}.toList();
}

/// Reorder within a content group while retaining the other groups' positions.
List<String> reorderDisplayGroup(
  List<String> order,
  String prefix,
  List<String> group,
) {
  var index = 0;
  return [
    for (final key in order)
      if (!key.startsWith(prefix))
        key
      else if (index < group.length)
        group[index++],
    ...group.skip(index),
  ];
}

RefreshStatus displayRefreshStatus(
  AppConfig view,
  Map<String, DateTime> successfulFetches,
  SystemMetricSnapshot metrics, {
  DateTime? now,
}) {
  final dependencies = DisplayDependencies.forProfile(
    DisplayProfile.fromConfig(view),
  );
  final intervals = <String, int>{};
  final successful = Map<String, DateTime>.of(successfulFetches);
  for (final id in dependencies.assetIds) {
    intervals[id] = id.startsWith('YAHOO:') ? 60 : 15;
  }
  for (final field in dependencies.customFieldIds) {
    final id = field.substring(7, field.lastIndexOf('|'));
    final source = view.customSources
        .where((entry) => entry.id == id)
        .firstOrNull;
    intervals['field:$field'] = source?.refreshSeconds ?? 60;
    if (source?.enabled != true) successful.remove('field:$field');
  }
  for (final id in dependencies.metricIds) {
    final key = 'metric:$id';
    intervals[key] = view.systemMonitor.intervalSeconds * 2 + 1;
    if (metrics.values[id]?.valid == true && metrics.sampledAt != null) {
      successful[key] = metrics.sampledAt!;
    }
  }
  final status = calculateRefreshStatus(
    now: now ?? DateTime.now(),
    sourceIntervals: intervals,
    lastSuccessfulFetchAt: successful,
  );
  return RefreshStatus(
    state: status.state,
    lastUpdatedAt: status.lastUpdatedAt,
    intervalsSeconds: {
      for (final entry in intervals.entries)
        entry.key.startsWith('metric:')
            ? view.systemMonitor.intervalSeconds
            : entry.value,
    }.toList()..sort(),
    staleSourceCount: status.staleSourceCount,
    waitingSourceCount: status.waitingSourceCount,
  );
}
