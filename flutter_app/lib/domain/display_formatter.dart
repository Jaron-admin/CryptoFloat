import 'models.dart';
import 'unit_conversion.dart';

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
  final text = formatValue(value, segment.format);
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
