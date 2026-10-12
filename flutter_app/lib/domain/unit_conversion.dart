import 'models.dart';

const supportedDisplayCurrencies = [
  'USD',
  'CNY',
  'EUR',
  'GBP',
  'HKD',
  'JPY',
  'USDT',
  'USDC',
];

class UnitConversionResult {
  const UnitConversionResult({
    required this.value,
    required this.unit,
    this.converted = false,
    this.error,
  });
  final num value;
  final String unit;
  final bool converted;
  final String? error;
}

UnitConversionResult convertUnitValue(
  num value,
  String unit,
  AppConfig config,
  Map<String, double> usdRates,
) {
  UnitConversionResult unchanged([String? error]) =>
      UnitConversionResult(value: value, unit: unit, error: error);
  if (!value.isFinite) return unchanged('数值无效，保留原值和单位。');
  final source = unit.trim().toUpperCase();
  final rule = config.unitRules
      .where((rule) => rule.sourceUnit.trim().toUpperCase() == source)
      .firstOrNull;
  if (rule != null) {
    final target = rule.targetUnit.trim();
    if (source.isEmpty ||
        target.isEmpty ||
        !rule.multiplier.isFinite ||
        rule.multiplier <= 0) {
      return unchanged('自定义倍率无效，保留原值和单位。');
    }
    final converted = value * rule.multiplier;
    if (!converted.isFinite) return unchanged('换算结果超出范围。');
    return UnitConversionResult(
      value: converted,
      unit: target,
      converted: converted != value || target != unit,
    );
  }
  final target = config.displayCurrency.trim().toUpperCase();
  if (target.isEmpty || target == source) return unchanged();
  if (!supportedDisplayCurrencies.contains(source) ||
      !supportedDisplayCurrencies.contains(target)) {
    return unchanged();
  }
  // USD is the response's base; stablecoins must have their own supplied rate.
  final sourceRate = source == 'USD' ? 1.0 : usdRates[source];
  final targetRate = target == 'USD' ? 1.0 : usdRates[target];
  if (sourceRate == null ||
      targetRate == null ||
      !sourceRate.isFinite ||
      !targetRate.isFinite ||
      sourceRate <= 0 ||
      targetRate <= 0) {
    return unchanged('汇率未获取、已过期或无效，保留原值和单位。');
  }
  final converted = value / sourceRate * targetRate;
  if (!converted.isFinite) return unchanged('换算结果超出范围。');
  return UnitConversionResult(value: converted, unit: target, converted: true);
}

String displayUnitLabel(String unit, AppConfig config) {
  final normalized = unit.trim().toUpperCase();
  if (config.unitLabelMode == 'custom') {
    final label = config.unitLabels.entries
        .where((entry) => entry.key.trim().toUpperCase() == normalized)
        .firstOrNull
        ?.value;
    return label != null && label.isNotEmpty ? label : unit;
  }
  if (config.unitLabelMode == 'compact') {
    return const {
          'USD': r'$',
          'CNY': '¥',
          'EUR': '€',
          'GBP': '£',
          'HKD': r'HK$',
          'JPY': 'JP¥',
          'USDT': 'U',
          'USDC': 'USDC',
        }[normalized] ??
        unit;
  }
  return supportedDisplayCurrencies.contains(normalized) ? normalized : unit;
}
