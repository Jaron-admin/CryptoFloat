import 'models.dart';
import 'unit_conversion.dart';
import 'system_metric.dart';

String formatAssetPrice(Object? value, String assetId, AppConfig config) =>
    formatPriceValue(
      value,
      format: config.priceFormats[assetId] ?? const PriceDisplayFormat(),
    );

/// Display formatting only; quote storage, conversions and tick comparisons
/// always keep their original values.
String formatPriceValue(
  Object? value, {
  PriceDisplayFormat format = const PriceDisplayFormat(),
}) {
  final number = value is num ? value : num.tryParse('$value');
  if (value == null || number == null || !number.isFinite) return '—';
  final requested = format.decimalPlaces?.clamp(0, 8);
  if (!format.compact || number.abs() < 1000) {
    return formatValue(number, requested == null ? '' : '.${requested}f');
  }
  const divisors = [1.0, 1000.0, 1000000.0, 1000000000.0];
  const suffixes = ['', 'K', 'M', 'B'];
  var index = number.abs() >= divisors[3]
      ? 3
      : number.abs() >= divisors[2]
      ? 2
      : 1;
  final digits = requested ?? 1;
  // Carry rounded 999.95K into 1.0M rather than displaying 1,000.0K.
  if (index < 3 &&
      double.parse((number / divisors[index]).abs().toStringAsFixed(digits)) >=
          1000) {
    index++;
  }
  return '${formatValue(number / divisors[index], '.${digits}f')}${suffixes[index]}';
}

String formatValue(Object? value, [String format = '']) {
  if (value == null) return '—';
  if (format == 'raw') return '$value';
  if (value is String && format.isEmpty) return value;
  if (value is DateTime) {
    if (value.millisecondsSinceEpoch <= 0) return '未更新';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return '$value';
  if (!number.isFinite) return '—';
  final match = RegExp(r'^([+]?)[.](\d{1,2})f$').firstMatch(format);
  final digits = match == null
      ? (number.abs() >= 1 ? 2 : 5)
      : int.parse(match.group(2)!).clamp(0, 10);
  final pieces = number.toStringAsFixed(digits).split('.');
  final whole = pieces[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final result = pieces.length == 2 ? '$whole.${pieces[1]}' : whole;
  return match?.group(1) == '+' && number > 0 ? '+$result' : result;
}

Object? segmentValue(
  DisplaySegment segment,
  AppConfig config,
  Map<String, MarketQuote> quotes,
) {
  if (!segment.isField) return segment.text;
  final quote = quotes[segment.assetId];
  final asset = [
    ...Asset.popular,
    ...config.customAssets,
  ].where((asset) => asset.id == segment.assetId).firstOrNull;
  return switch (segment.fieldId) {
    'symbol' => asset?.symbol ?? quote?.extra['symbol'],
    'name' => asset?.name ?? quote?.extra['name'],
    'provider' => asset?.provider ?? quote?.extra['provider'],
    _ => quote?.field(segment.fieldId ?? ''),
  };
}

String renderSegment(
  DisplaySegment segment,
  AppConfig config,
  Map<String, MarketQuote> quotes, {
  Map<String, double> rates = const {},
}) {
  if (!segment.isField) return segment.text;
  final raw = segmentValue(segment, config, quotes);
  if (segment.assetId == 'system') {
    final definition = systemMetricCatalog
        .where((metric) => metric.id == segment.fieldId)
        .firstOrNull;
    if (raw is! num || definition == null) return '—';
    final reading = MetricReading(raw.toDouble(), definition.unit, 'valid');
    if (!reading.valid) return '—';
    final converted = convertUnitValue(raw, definition.unit, config, rates);
    final formatted = converted.converted || segment.format.isNotEmpty
        ? MetricText(
            formatValue(converted.value, segment.format),
            converted.unit,
          )
        : formatSystemMetric(definition.id, reading);
    return MetricText(
      formatted.value,
      displayUnitLabel(formatted.unit, config),
    ).text;
  }
  Object? value = raw;
  String unit = '';
  if (segment.assetId!.startsWith('custom:')) {
    final source = config.customSources
        .where((source) => 'custom:${source.id}' == segment.assetId)
        .firstOrNull;
    final field = source?.fields
        .where((field) => field.id == segment.fieldId)
        .firstOrNull;
    unit = field?.unit ?? '';
    final number = raw is num ? raw : num.tryParse('$raw');
    if (number != null && unit.isNotEmpty) {
      final converted = convertUnitValue(number, unit, config, rates);
      if (converted.converted) value = converted.value;
      unit = converted.unit;
    }
  } else if (['price', 'currency', 'unit'].contains(segment.fieldId)) {
    final quote = quotes[segment.assetId];
    final asset = [
      ...Asset.popular,
      ...config.customAssets,
    ].where((asset) => asset.id == segment.assetId).firstOrNull;
    final sourceUnit = quote?.currency.isNotEmpty == true
        ? quote!.currency
        : asset?.currency ?? '';
    final converted = convertUnitValue(
      quote?.price ?? 0,
      sourceUnit,
      config,
      rates,
    );
    if (segment.fieldId == 'price') {
      if (quote?.price != null && converted.converted) value = converted.value;
    } else {
      return displayUnitLabel(converted.unit, config);
    }
  }
  final text =
      segment.fieldId == 'price' &&
          segment.format.isEmpty &&
          !segment.assetId!.startsWith('custom:')
      ? formatAssetPrice(value, segment.assetId!, config)
      : formatValue(value, segment.format);
  return unit.isEmpty ? text : '$text ${displayUnitLabel(unit, config)}';
}

String renderRow(
  DisplayRow row,
  AppConfig config,
  Map<String, MarketQuote> quotes, {
  Map<String, double> rates = const {},
}) => row.segments
    .map((segment) => renderSegment(segment, config, quotes, rates: rates))
    .join();
