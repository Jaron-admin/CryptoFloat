import 'package:flutter/material.dart';

import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import '../../platform/system_fonts.dart';
import '../../app/theme_presets.dart';

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

  String _name(String id) {
    final asset = [
      ...Asset.popular,
      ...config.customAssets,
    ].where((asset) => asset.id == id).firstOrNull;
    if (asset != null) return '${asset.name} · ${asset.provider}';
    return config.customSources
            .where((source) => 'custom:${source.id}' == id)
            .firstOrNull
            ?.name ??
        '已移除的内容';
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
          return '${_name(id)}\n${quote == null ? '暂无数据，请检查关注内容或数据源' : '更新于 ${formatValue(quote.updatedAt)}'}${quote?.error == null ? '' : '\n${quote!.error}'}';
        })
        .join('\n\n');
    final line = Text.rich(
      TextSpan(
        children: [
          for (final segment in row.segments)
            TextSpan(
              text: renderSegment(segment, config, quotes, rates: rates),
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
                                '${_name(id)} · ${quotes[id]!.updatedAt.millisecondsSinceEpoch > 0 ? '过期数据 ${formatValue(quotes[id]!.updatedAt)}' : '连接异常'}',
                          )
                          .join('；'),
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
