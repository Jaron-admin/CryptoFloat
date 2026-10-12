import 'package:flutter/widgets.dart';

import '../domain/models.dart';
import '../domain/display_formatter.dart';
import 'generated/app_localizations.dart';
export 'generated/app_localizations.dart';
export 'app_errors.dart';

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String localizedValue(
  Object? value,
  AppLocalizations l10n, [
  String format = '',
]) => value is DateTime && value.millisecondsSinceEpoch <= 0
    ? l10n.panelNeverUpdated
    : formatValue(value, format);

String localizedSegment(
  DisplaySegment segment,
  AppConfig config,
  Map<String, MarketQuote> quotes,
  AppLocalizations l10n, {
  Map<String, double> rates = const {},
}) {
  if (segment.isField) {
    final value = segmentValue(segment, config, quotes);
    if (value is DateTime && value.millisecondsSinceEpoch <= 0) {
      return l10n.panelNeverUpdated;
    }
    if (segment.fieldId == 'name' && !segment.assetId!.startsWith('custom:')) {
      final asset = [
        ...config.customAssets,
        ...Asset.popular,
      ].where((asset) => asset.id == segment.assetId).firstOrNull;
      if (asset != null) return localizedAssetName(asset, l10n);
    }
  }
  return renderSegment(segment, config, quotes, rates: rates);
}

/// Only built-in names are translated. User labels and API text stay intact.
String localizedAssetName(Asset asset, AppLocalizations l10n) {
  final original = Asset.popular
      .where((item) => item.id == asset.id)
      .firstOrNull;
  if (original == null || original.name != asset.name) return asset.name;
  return switch (asset.id) {
    'YAHOO:600519.SS' => l10n.appMoutai,
    'YAHOO:000001.SZ' => l10n.appPingAn,
    'YAHOO:300750.SZ' => l10n.appCatl,
    _ => asset.name,
  };
}
