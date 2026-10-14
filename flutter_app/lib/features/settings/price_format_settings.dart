import 'package:flutter/material.dart';

import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import '../../domain/unit_conversion.dart';
import '../../l10n/metrics_strings.dart';
import 'fluent_controls.dart';

class PriceFormatSettings extends StatelessWidget {
  const PriceFormatSettings({
    super.key,
    required this.config,
    required this.onChanged,
    this.quotes = const {},
    this.rates = const {},
  });

  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;

  void _change(String id, PriceDisplayFormat format) {
    final formats = Map<String, PriceDisplayFormat>.of(config.priceFormats);
    if (!format.compact && format.decimalPlaces == null) {
      formats.remove(id);
    } else {
      formats[id] = format;
    }
    onChanged(config.copyWith(priceFormats: formats));
  }

  @override
  Widget build(BuildContext context) {
    final zh = context.metrics.chinese;
    return ExpansionTile(
      key: const ValueKey('price-format-settings'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(zh ? '价格显示精度' : 'Price display precision'),
      subtitle: Text(
        zh
            ? '按币种设置小数位与 K / M / B 缩写'
            : 'Decimals and K / M / B notation per asset',
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            zh ? 'K = 千，M = 百万，B = 十亿。只改变显示，涨跌仍按原始价格判断。' : 'K = thousand, M = million, B = billion. Only display changes; price comparisons use original values.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (config.assets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              zh ? '先为当前显示添加行情项目。' : 'Add an asset to this display first.',
            ),
          ),
        for (final asset in config.assets) _asset(context, asset, zh),
      ],
    );
  }

  Widget _asset(BuildContext context, Asset asset, bool zh) {
    final current = config.priceFormats[asset.id] ?? const PriceDisplayFormat();
    final quote = quotes[asset.id];
    final value = quote?.price == null
        ? null
        : convertUnitValue(
            quote!.price!,
            quote.currency.isNotEmpty ? quote.currency : asset.currency,
            config,
            rates,
          ).value;
    final example = formatPriceValue(value ?? 81678.42, format: current);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${asset.symbol} · ${asset.provider}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final notation = FDropdown<bool>(
                key: ValueKey('price-format-compact-${asset.id}'),
                initialValue: current.compact,
                decoration: InputDecoration(
                  labelText: zh ? '数字格式' : 'Notation',
                ),
                items: [
                  FDropdownItem(
                    value: false,
                    child: Text(zh ? '普通数字' : 'Standard'),
                  ),
                  FDropdownItem(
                    value: true,
                    child: Text(zh ? '缩写 K / M / B' : 'Compact K / M / B'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _change(
                      asset.id,
                      PriceDisplayFormat(
                        compact: value,
                        decimalPlaces: current.decimalPlaces,
                      ),
                    );
                  }
                },
              );
              final decimals = FDropdown<int>(
                key: ValueKey('price-format-decimals-${asset.id}'),
                initialValue: current.decimalPlaces ?? -1,
                decoration: InputDecoration(
                  labelText: zh ? '小数位数' : 'Decimal places',
                ),
                items: [
                  FDropdownItem(value: -1, child: Text(zh ? '自动' : 'Auto')),
                  for (var i = 0; i <= 8; i++)
                    FDropdownItem(
                      value: i,
                      child: Text(
                        zh
                            ? (i == 0 ? '整数（0 位）' : '$i 位小数')
                            : (i == 1 ? '1 decimal' : '$i decimals'),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _change(
                      asset.id,
                      PriceDisplayFormat(
                        compact: current.compact,
                        decimalPlaces: value < 0 ? null : value,
                      ),
                    );
                  }
                },
              );
              return constraints.maxWidth < 380
                  ? Column(
                      children: [notation, const SizedBox(height: 8), decimals],
                    )
                  : Row(
                      children: [
                        Expanded(child: notation),
                        const SizedBox(width: 12),
                        Expanded(child: decimals),
                      ],
                    );
            },
          ),
          const SizedBox(height: 6),
          Text(
            '${value == null ? (zh ? '格式示例' : 'Format example') : (zh ? '当前显示' : 'Current display')}: $example',
            key: ValueKey('price-format-example-${asset.id}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
