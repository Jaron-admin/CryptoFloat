import 'package:flutter/material.dart';

import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import '../../platform/system_fonts.dart';
import '../../app/theme_presets.dart';
import '../../l10n/l10n.dart';

/// Used by the panel and editors so previews use the same field styles.
class DisplayRowView extends StatelessWidget {
  const DisplayRowView({
    super.key,
    required this.row,
    required this.config,
    required this.quotes,
    this.rates = const {},
    this.showFreshness = true,
  });
  final DisplayRow row;
  final AppConfig config;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;
  final bool showFreshness;

  String _name(String id, AppLocalizations l10n) {
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
      color: segment.fieldId == 'change' && value is num
          ? (value >= 0
                ? marketColorsOf(context).positive
                : marketColorsOf(context).negative)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = row.segments
        .where((segment) => segment.isField)
        .map((segment) => segment.assetId!)
        .toSet();
    final stale = ids.where((id) => quotes[id]?.isStale == true).toList();
    final details = ids
        .map((id) {
          final quote = quotes[id];
          return '${_name(id, context.l10n)}\n${quote == null ? context.l10n.panelNoData : context.l10n.panelUpdated(localizedValue(quote.updatedAt, context.l10n))}${quote?.error == null ? '' : '\n${localizeAppError(context, quote!.error)}'}';
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
                                '${_name(id, context.l10n)} · ${quotes[id]!.updatedAt.millisecondsSinceEpoch > 0 ? context.l10n.panelStale(localizedValue(quotes[id]!.updatedAt, context.l10n)) : context.l10n.panelConnectionError}',
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
