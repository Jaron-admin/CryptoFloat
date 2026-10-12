const currencyRateCacheDuration = Duration(seconds: 300);

Map<String, double> parseUsdExchangeRates(Object? response) {
  final data = response is Map ? response['data'] : null;
  final rawRates = data is Map ? data['rates'] : null;
  if (data is! Map || data['currency'] != 'USD' || rawRates is! Map) {
    throw const FormatException('汇率响应无效，保留原值和单位。');
  }
  final rates = <String, double>{};
  for (final entry in rawRates.entries) {
    final code = '${entry.key}'.trim().toUpperCase();
    final raw = entry.value;
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (code.isNotEmpty && value != null && value.isFinite && value > 0) {
      rates[code] = value;
    }
  }
  if (rates['USD'] != 1) {
    throw const FormatException('汇率基准无效，保留原值和单位。');
  }
  return Map.unmodifiable(rates);
}

Map<String, double> usableExchangeRates({
  required Map<String, double> rates,
  required DateTime? fetchedAt,
  required DateTime now,
}) {
  if (fetchedAt == null ||
      fetchedAt.isAfter(now) ||
      now.difference(fetchedAt) > currencyRateCacheDuration) {
    return const {};
  }
  return Map.unmodifiable(rates);
}
