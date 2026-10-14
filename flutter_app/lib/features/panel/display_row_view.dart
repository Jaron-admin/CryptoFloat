import 'package:flutter/material.dart';

import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import '../../platform/system_fonts.dart';
import '../../app/market_change_colors.dart';
import '../../app/theme_presets.dart';
import '../../domain/refresh_price.dart';
import '../../l10n/l10n.dart';
import '../../l10n/metrics_strings.dart';

/// Used by the panel and editors so previews use the same field styles.
class DisplayRowView extends StatelessWidget {
  const DisplayRowView({
    super.key,
    required this.row,
    required this.config,
    required this.quotes,
    this.rates = const {},
    this.showFreshness = true,
    this.priceTicks = const {},
  });
  final DisplayRow row;
  final AppConfig config;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;
  final bool showFreshness;
  final Map<String, PriceTick> priceTicks;

  String _name(String id, AppLocalizations l10n) {
    if (id == 'system') {
      return MetricsStrings(l10n.localeName.startsWith('zh')).system;
    }
    final asset = [
      ...config.customAssets,
      ...Asset.popular,
    ].where((asset) => asset.id == id).firstOrNull;
    if (asset != null) {
      return '${localizedAssetName(asset, l10n)} · ${asset.provider}';
    }
    return config.customSources
            .where((source) => 'custom:${source.id}' == id)
            .firstOrNull
            ?.name ??
        l10n.panelRemoved;
  }

  TextStyle _style(BuildContext context, DisplaySegment segment) {
    final value = segmentValue(segment, config, quotes);
    final metadata = [
      'name',
      'symbol',
      'provider',
      'currency',
      'unit',
    ].contains(segment.fieldId);
    final numeric =
        segment.isField &&
        !metadata &&
        (value is num ||
            value is DateTime ||
            ['price', 'change', 'updatedAt'].contains(segment.fieldId) ||
            (value is String && num.tryParse(value) != null));
    return TextStyle(
      fontSize: config.fontSize,
      fontFamily: SystemFonts.family(
        numeric ? config.numberFontFamily : config.fontFamily,
      ),
      fontFeatures: numeric ? const [FontFeature.tabularFigures()] : null,
      color: _segmentColor(context, segment),
    );
  }

  Color? _segmentColor(BuildContext context, DisplaySegment segment) {
    if (segment.fieldId != 'price' && segment.fieldId != 'change') return null;
    if (config.priceColorMode == 'plain') return null;
    return priceTickColor(
      priceColorMode: config.priceColorMode,
      tick: priceTicks[segment.assetId] ?? PriceTick.neutral,
      neutral: Theme.of(context).colorScheme.onSurface,
      brightness: Theme.of(context).brightness,
      themeColors: marketColorsOf(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime? updateTime(String id) {
      final quote = quotes[id];
      if (!id.startsWith('custom:')) return quote?.updatedAt;
      final times = [
        for (final segment in row.segments.where(
          (segment) => segment.assetId == id,
        ))
          if (quote?.fieldUpdatedAt[segment.fieldId] != null)
            quote!.fieldUpdatedAt[segment.fieldId]!,
      ]..sort();
      return times.firstOrNull;
    }

    String? errorFor(String id) {
      final quote = quotes[id];
      final errors = <String>{
        if (quote?.error != null) quote!.error!,
        for (final segment in row.segments.where(
          (segment) => segment.assetId == id,
        ))
          if (quote?.fieldErrors[segment.fieldId] != null)
            quote!.fieldErrors[segment.fieldId]!,
      };
      return errors.isEmpty
          ? null
          : errors.map((error) => localizeAppError(context, error)).join('\n');
    }

    final ids = row.segments
        .where((segment) => segment.isField)
        .map((segment) => segment.assetId!)
        .toSet();
    final stale = ids
        .where(
          (id) =>
              quotes[id] != null &&
              row.segments
                  .where((segment) => segment.assetId == id)
                  .any((segment) => quotes[id]!.isFieldStale(segment.fieldId!)),
        )
        .toList();
    final details = ids
        .map((id) {
          final time = updateTime(id);
          final error = errorFor(id);
          return '${_name(id, context.l10n)}\n${time == null ? context.l10n.panelNoData : context.l10n.panelUpdated(localizedValue(time, context.l10n))}${error == null ? '' : '\n$error'}';
        })
        .join('\n\n');
    final line = Text.rich(
      TextSpan(
        children: [
          for (final segment in row.segments)
            TextSpan(
              text: localizedSegment(
                segment,
                config,
                quotes,
                context.l10n,
                rates: rates,
              ),
              style: _style(context, segment),
            ),
        ],
      ),
    );
    return Tooltip(
      message: details,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line,
          if (showFreshness && stale.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      stale
                          .map(
                            (id) =>
                                '${_name(id, context.l10n)} · ${updateTime(id) != null && updateTime(id)!.millisecondsSinceEpoch > 0 ? context.l10n.panelStale(localizedValue(updateTime(id), context.l10n)) : context.l10n.panelConnectionError}',
                          )
                          .join('; '),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
