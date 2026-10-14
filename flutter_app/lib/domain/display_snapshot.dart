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

String taskbarCellLabel(
  DisplayText cell, {
  TaskbarConfig config = const TaskbarConfig(),
  Iterable<Asset> assets = Asset.popular,
}) {
  final alias = normalizeTaskbarAlias(config.labelAliases[cell.id] ?? '');
  if (alias.isNotEmpty) return alias;
  if (config.labelMode == 'full' || !cell.id.startsWith('asset:')) {
    return cell.label;
  }
  final asset = assets
      .where((asset) => 'asset:${asset.id}' == cell.id)
      .firstOrNull;
  if (asset == null || asset.kind != MarketKind.crypto) return cell.label;
  final symbol = asset.symbol.trim();
  final quote = asset.currency.trim();
  if (quote.isEmpty ||
      symbol.length <= quote.length ||
      !symbol.toUpperCase().endsWith(quote.toUpperCase())) {
    return cell.label;
  }
  final base = symbol
      .substring(0, symbol.length - quote.length)
      .replaceFirst(RegExp(r'[-/_]+$'), '');
  return base.isEmpty ? cell.label : base;
}

String taskbarCellTooltip(DisplayText cell, {required bool chinese}) {
  final change = cell.change;
  final percentage = change != null && change.isFinite
      ? ' ${formatValue(change, '+.2f')}%'
      : '';
  final freshness = cell.stale
      ? (chinese ? ' · 等待更新' : ' · Awaiting update')
      : '';
  return '${cell.text}$percentage$freshness';
}

/// Only bounded rendered text and display preferences cross the native boundary.
Map<String, Object?> buildTaskbarFrame({
  required TaskbarConfig config,
  required bool chinese,
  required List<DisplayText> cells,
  required int background,
  required int foreground,
  Iterable<Asset> assets = Asset.popular,
  int Function(DisplayText)? colorFor,
  int Function(DisplayText)? suffixColorFor,
}) {
  final profile = config.profile;
  final frame = <String, Object?>{
    'enabled': config.enabled,
    'chinese': chinese,
    'width': config.width.isFinite
        ? config.width.clamp(120, 1200).round()
        : 360,
    'lineCount': config.lineCount == 1 ? 1 : 2,
    'itemGap': config.itemGap.clamp(0, 24),
    'labelValueGap': config.labelValueGap.clamp(0, 24),
    'overflowMode': config.overflowMode == 'manual' ? 'manual' : 'auto',
    'carouselIntervalSeconds': config.carouselIntervalSeconds.clamp(2, 60),
    'transparentBackground': config.transparentBackground,
    'fontSize': profile.fontSize.isFinite ? profile.fontSize.clamp(6, 32) : 12,
    'fontFamily': boundedTaskbarText(
      profile.fontFamily.isEmpty ? 'Segoe UI' : profile.fontFamily,
      128,
    ),
    'numberFontFamily': boundedTaskbarText(
      profile.numberFontFamily.isEmpty ? 'Segoe UI' : profile.numberFontFamily,
      128,
    ),
    'background': background,
    'foreground': foreground,
    'cells': [
      for (final cell in taskbarVisibleCells(cells, chinese: chinese))
        <String, Object?>{
          'text': boundedTaskbarText(
            taskbarCellText(
              cell,
              showChangePercent: profile.showChangePercent,
              config: config,
              assets: assets,
            ),
            200,
          ),
          'tooltip': boundedTaskbarText(
            taskbarCellTooltip(cell, chinese: chinese),
            600,
          ),
          'color': colorFor?.call(cell) ?? foreground,
          'label': boundedTaskbarText(
            taskbarCellLabel(cell, config: config, assets: assets),
            160,
          ),
          'value': boundedTaskbarText(taskbarCellValue(cell), 200),
          'suffix': boundedTaskbarText(
            taskbarCellSuffix(
              cell,
              showChangePercent: profile.showChangePercent,
            ),
            64,
          ),
          'suffixColor': suffixColorFor?.call(cell) ?? foreground,
        },
    ],
  };
  _boundTaskbarPacket(frame);
  return frame;
}

String taskbarCellValue(DisplayText cell) => DisplayText(
  '',
  cell.value,
  unit: cell.unit,
).text.replaceAll(RegExp(r'\s+'), ' ').trim();

String taskbarCellSuffix(DisplayText cell, {required bool showChangePercent}) {
  final change = cell.change;
  return !showChangePercent || change == null || !change.isFinite
      ? ''
      : '${formatValue(change, '+.2f')}%';
}

// Keep a large carousel within the native 64 KiB packet, including UTF-16
// strings and field overhead. Trim duplicate/hover text before visible fields.
void _boundTaskbarPacket(Map<String, Object?> frame) {
  final cells = frame['cells'] as List<Map<String, Object?>>;
  int size() =>
      68 +
      2 *
          ((frame['fontFamily'] as String).length +
              (frame['numberFontFamily'] as String).length) +
      cells.fold<int>(
        0,
        (sum, cell) =>
            sum +
            32 +
            2 *
                ['text', 'tooltip', 'label', 'value', 'suffix'].fold<int>(
                  0,
                  (length, field) => length + (cell[field] as String).length,
                ),
      );
  for (final (field, limit) in const [
    ('tooltip', 160),
    ('tooltip', 80),
    ('tooltip', 0),
    ('text', 100),
    ('text', 0),
    ('label', 64),
    ('value', 128),
    ('label', 32),
    ('value', 64),
    ('suffix', 32),
    ('label', 16),
    ('value', 32),
    ('suffix', 20),
  ]) {
    if (size() <= 65520) return;
    for (final cell in cells) {
      cell[field] = limit == 0
          ? ''
          : boundedTaskbarText(cell[field] as String, limit);
    }
  }
}

String taskbarCellText(
  DisplayText cell, {
  required bool showChangePercent,
  TaskbarConfig config = const TaskbarConfig(),
  Iterable<Asset> assets = Asset.popular,
}) {
  final label = taskbarCellLabel(cell, config: config, assets: assets);
  final text = DisplayText(
    label,
    cell.value,
    unit: cell.unit,
  ).text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final change = cell.change;
  if (!showChangePercent || change == null || !change.isFinite) {
    return text;
  }
  return '$text ${formatValue(change, '+.2f')}%';
}

/// All normal rows reach the native pager. Extremely large configurations keep
/// a bounded packet and an explicit undisplayed count without altering settings.
List<DisplayText> taskbarVisibleCells(
  List<DisplayText> cells, {
  required bool chinese,
}) => cells.length <= 256
    ? cells
    : [
        ...cells.take(255),
        DisplayText(
          '',
          chinese ? '+${cells.length - 255} 项' : '+${cells.length - 255} more',
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
          formatAssetPrice(converted?.value, asset.id, view),
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
