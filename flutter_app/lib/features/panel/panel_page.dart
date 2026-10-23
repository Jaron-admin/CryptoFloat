import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import '../../domain/system_metric.dart';
import '../../domain/display_snapshot.dart';
import '../../l10n/metrics_strings.dart';
import '../../domain/unit_conversion.dart';
import '../../platform/system_fonts.dart';
import 'display_row_view.dart';
import '../../app/market_change_colors.dart';
import '../../app/theme_presets.dart';
import '../../domain/refresh_price.dart';
import '../../l10n/l10n.dart';

class PanelPage extends StatelessWidget {
  const PanelPage({
    super.key,
    required this.controller,
    required this.onSettings,
  });
  final AppController controller;
  final ValueChanged<int> onSettings;

  Future<void> _menu(BuildContext context, Offset point) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final native = await controller.menus.show(
      point,
      alwaysOnTop: controller.config.alwaysOnTop,
      theme: Theme.of(context),
      l10n: context.l10n,
    );
    if (!context.mounted) return;
    if (native.handled) {
      await _act(native.action);
      return;
    }
    if (!context.mounted) return;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(point.dx, point.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    final value = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(value: 'hide', child: Text(context.l10n.editMenuHide)),
        PopupMenuItem(
          value: 'refresh',
          child: Text(context.l10n.editMenuRefresh),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'topmost',
          child: Text(
            controller.config.alwaysOnTop
                ? context.l10n.panelUnpin
                : context.l10n.panelPin,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Text(context.l10n.panelSettings),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'exit', child: Text(context.l10n.editMenuExit)),
      ],
    );
    if (!context.mounted || value == null) return;
    await _act(value);
  }

  Future<void> _act(String? value) async {
    switch (value) {
      case 'hide':
        await controller.hideToTray();
      case 'settings':
        onSettings(0);
      case 'topmost':
        await controller.apply(
          controller.config.copyWith(
            alwaysOnTop: !controller.config.alwaysOnTop,
          ),
        );
      case 'refresh':
        await controller.metrics.refresh();
        await controller.data.refresh(force: true);
      case 'exit':
        await controller.close();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onSecondaryTapUp: (event) => _menu(context, event.globalPosition),
    onDoubleTap: controller.hideToTray,
    onHorizontalDragStart: (_) => controller.host.beginDrag(),
    child: Scaffold(
      body: PanelContent(
        controller: controller,
        config: controller.config,
        onSettings: onSettings,
        interactive: true,
      ),
    ),
  );
}

/// The live panel and settings preview share exactly the same content renderer.
class PanelContent extends StatelessWidget {
  const PanelContent({
    super.key,
    required this.controller,
    required this.config,
    this.onSettings,
    this.interactive = false,
  });
  final AppController controller;
  final AppConfig config;
  final ValueChanged<int>? onSettings;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final quotes = controller.displayQuotes;
    final rates = controller.data.exchangeRates;
    final priceStyle = TextStyle(
      fontFamily: SystemFonts.family(config.numberFontFamily),
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: config.fontSize,
      fontWeight: FontWeight.w500,
    );
    final referenced = {
      for (final row in config.displayRows)
        for (final segment in row.segments)
          if (segment.isField) '${segment.assetId}|${segment.fieldId}',
    };
    final automaticFields = [
      for (final source in config.customSources.where(
        (source) => source.enabled,
      ))
        for (final field in source.fields)
          if (config.selectedCustomFieldIds.contains(
                customFieldKey(source.id, field.id),
              ) &&
              !referenced.contains('custom:${source.id}|${field.id}'))
            (source, field),
    ];
    final content = <String, Widget>{
      if (config.showDefaultRows)
        for (final asset in config.assets)
          'asset:${asset.id}': _AssetRow(
            asset: asset,
            quote: quotes[asset.id],
            style: priceStyle,
            spacing: config.rowSpacing,
            config: config,
            rates: rates,
            tick: controller.priceTickFor(asset.id),
          ),
      for (final id in config.selectedMetricIds)
        'metric:$id': _MetricRow(
          id: id,
          config: config,
          snapshot: controller.metrics.snapshot,
          style: priceStyle,
        ),
      for (final pair in automaticFields)
        'field:${customFieldKey(pair.$1.id, pair.$2.id)}': _CustomFieldRow(
          source: pair.$1,
          field: pair.$2,
          quote: quotes['custom:${pair.$1.id}'],
          style: priceStyle,
          spacing: config.rowSpacing,
          config: config,
          rates: rates,
        ),
      for (final row in config.displayRows)
        'row:${row.id}': Padding(
          padding: EdgeInsets.symmetric(vertical: config.rowSpacing / 2 + 3),
          child: DisplayRowView(
            row: row,
            config: config,
            quotes: quotes,
            rates: rates,
            priceTicks: {
              for (final quote in quotes.values)
                quote.assetId: controller.priceTickFor(quote.assetId),
            },
          ),
        ),
    };
    return SafeArea(
      child: Column(
        children: [
          if (config.showHeaderName || config.showHeaderIcon)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: interactive
                  ? (_) => controller.host.beginDrag()
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    if (config.showHeaderIcon) ...[
                      _HeaderIcon(
                        config: config,
                        imagePath: controller.store.resourcePath(
                          config.headerImagePath,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    if (config.showHeaderName)
                      Expanded(
                        child: Text(
                          config.headerName,
                          key: const ValueKey('panel-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (controller.startupMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                localizeAppError(context, controller.startupMessage),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 11,
                ),
              ),
            ),
          Expanded(
            child: _PanelGrid(
              config: config,
              children: [
                for (final id in buildDisplayTexts(
                  config,
                  quotes,
                  controller.metrics.snapshot,
                  rates: rates,
                ).map((entry) => entry.id))
                  KeyedSubtree(key: ValueKey('panel-$id'), child: content[id]!),
                if (content.isEmpty)
                  _EmptyPanel(onSettings: () => onSettings?.call(0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Keep the selected number of columns; scroll when cells would become unreadable.
class _PanelGrid extends StatelessWidget {
  const _PanelGrid({required this.config, required this.children});
  final AppConfig config;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final columns = config.panelColumnCount.clamp(1, 8);
    final gap = config.panelColumnGap;
    final textScale =
        MediaQuery.textScalerOf(context).scale(config.fontSize) / 15;
    final minCellWidth =
        (config.panelItemLayout == 'vertical' ? 180.0 : 290.0) * textScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (config.panelItemLayout == 'horizontal') {
          final maxCellWidth = math.max(
            240 * textScale,
            (constraints.maxWidth - 24 - (columns - 1) * gap) / columns,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    for (
                      var start = 0;
                      start < children.length;
                      start += columns
                    )
                      TableRow(
                        children: [
                          for (var column = 0; column < columns; column++) ...[
                            if (column > 0) SizedBox(width: gap),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxCellWidth,
                              ),
                              child: start + column < children.length
                                  ? children[start + column]
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        final minimumWidth = columns * minCellWidth + (columns - 1) * gap + 24;
        final width = constraints.maxWidth > minimumWidth
            ? constraints.maxWidth
            : minimumWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
              children: [
                for (var start = 0; start < children.length; start += columns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) SizedBox(width: gap),
                        Expanded(
                          child: start + column < children.length
                              ? children[start + column]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntryLayout extends StatelessWidget {
  const _EntryLayout({
    required this.config,
    required this.label,
    required this.value,
  });
  final AppConfig config;
  final Widget label, value;

  @override
  Widget build(BuildContext context) {
    // Values keep a reserved width of their own, so they are anchored to the
    // right edge here instead of stretching the label column beside them.
    final aligned = Align(alignment: Alignment.centerRight, child: value);
    return config.panelItemLayout == 'vertical'
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              SizedBox(height: config.panelLabelValueGap),
              aligned,
            ],
          )
        : Table(
            columnWidths: {
              0: const IntrinsicColumnWidth(),
              1: FixedColumnWidth(config.panelLabelValueGap),
              2: const IntrinsicColumnWidth(flex: 1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [label, const SizedBox.shrink(), aligned]),
            ],
          );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.id,
    required this.config,
    required this.snapshot,
    required this.style,
  });
  final String id;
  final AppConfig config;
  final SystemMetricSnapshot snapshot;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final metric = systemMetricCatalog
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (metric == null) return const SizedBox.shrink();
    final reading = snapshot.reading(
      id,
      intervalSeconds: config.systemMonitor.intervalSeconds,
    );
    final text = metricTextFor(id, reading, config);
    final device = id.startsWith('gpu.')
        ? snapshot.gpuName
        : id.startsWith('network.')
        ? snapshot.networkName
        : id.startsWith('disk.')
        ? snapshot.diskName
        : '';
    return Tooltip(
      message:
          '${metric.name(context.metrics.chinese)}${device.isEmpty ? '' : '\n$device'}${reading?.valid == true ? '' : '\n${context.metrics.unavailable}'}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: config.rowSpacing / 2 + 3),
        child: _EntryLayout(
          config: config,
          label: Text(
            metric.name(context.metrics.chinese),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SystemFonts.family(config.fontFamily),
              fontSize: config.fontSize,
            ),
          ),
          // One line with a reserved width: switching between "999.9 KiB/s" and
          // "1.0 MiB/s" neither wraps the row nor moves the columns beside it.
          value: _StableText(
            text.text,
            style: style,
            seeds: _metricSeeds(metric.unit),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.config, required this.imagePath});
  final AppConfig config;
  final String? imagePath;
  @override
  Widget build(BuildContext context) {
    final icon = switch (config.headerIcon) {
      'chart' => Icons.show_chart_rounded,
      'bitcoin' => Icons.currency_bitcoin,
      'star' => Icons.star_rounded,
      'bolt' => Icons.bolt_rounded,
      'heart' => Icons.favorite_rounded,
      _ => null,
    };
    final fallback = icon == null
        ? Text(
            config.headerIcon,
            maxLines: 1,
            style: const TextStyle(fontSize: 17),
          )
        : Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary);
    if (imagePath == null) {
      return SizedBox(width: 20, height: 20, child: FittedBox(child: fallback));
    }
    return Image.file(
      File(imagePath!),
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) => fallback,
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.quote,
    required this.style,
    required this.spacing,
    required this.config,
    required this.rates,
    required this.tick,
  });
  final Asset asset;
  final MarketQuote? quote;
  final TextStyle style;
  final double spacing;
  final AppConfig config;
  final Map<String, double> rates;
  final PriceTick tick;
  @override
  Widget build(BuildContext context) {
    final currency = quote?.currency.isNotEmpty == true
        ? quote!.currency
        : asset.currency;
    final converted = quote?.price == null
        ? null
        : convertUnitValue(quote!.price!, currency, config, rates);
    final tone = priceTickColor(
      priceColorMode: config.priceColorMode,
      tick: tick,
      neutral: Theme.of(context).colorScheme.onSurface,
      brightness: Theme.of(context).brightness,
      themeColors: marketColorsOf(context),
    );
    final symbol = asset.kind == MarketKind.crypto
        ? asset.symbol.split('-').first.replaceFirst(RegExp(r'USDT$'), '')
        : asset.symbol;
    final changeStyle = style.copyWith(fontSize: (style.fontSize ?? 15) - 2);
    final changeColor = marketChangeColor(
      context,
      config,
      quote?.changePercent,
    );
    final failed = quote?.isStale == true || converted?.error != null;
    return Tooltip(
      message:
          '${localizedAssetName(asset, context.l10n)} · ${asset.provider}\n${quote == null ? context.l10n.panelWaiting : context.l10n.panelQuoteTime(localizedValue(quote!.updatedAt, context.l10n))}${quote?.error == null ? '' : '\n${localizeAppError(context, quote!.error)}'}${converted?.error == null ? '' : '\n${localizeAppError(context, converted!.error)}'}${converted?.converted == true ? '\n${context.l10n.panelOriginal(formatValue(quote?.price), currency)}' : ''}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing / 2 + 3),
        child: _EntryLayout(
          config: config,
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: style.fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                localizedAssetName(asset, context.l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          value: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: _StableText(
                  formatAssetPrice(
                    converted?.value ?? quote?.price,
                    asset.id,
                    config,
                  ),
                  style: style.copyWith(color: tone),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    displayUnitLabel(converted?.unit ?? currency, config),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (config.showChangePercent)
                // A reserved slot: "—" and "+2.50%" share one width, so the
                // price and unit keep their place on every refresh.
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _StableText(
                    quote?.changePercent == null
                        ? '—'
                        : '${formatValue(quote!.changePercent, '+.2f')}%',
                    seeds: const ['+000.00%', '-000.00%'],
                    style: changeStyle.copyWith(color: changeColor),
                  ),
                ),
              // The staleness marker keeps its slot too, so a source becoming
              // stale does not shift the numbers beside it.
              SizedBox(
                width: 15,
                child: failed
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.error_outline,
                          size: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomFieldRow extends StatelessWidget {
  const _CustomFieldRow({
    required this.source,
    required this.field,
    required this.quote,
    required this.style,
    required this.spacing,
    required this.config,
    required this.rates,
  });
  final CustomApiSource source;
  final CustomField field;
  final MarketQuote? quote;
  final TextStyle style;
  final double spacing;
  final AppConfig config;
  final Map<String, double> rates;
  @override
  Widget build(BuildContext context) {
    final value = quote?.field(field.id);
    final number = value is num
        ? value
        : (value is String ? num.tryParse(value) : null);
    final converted = number == null
        ? null
        : convertUnitValue(number, field.unit, config, rates);
    final unit = displayUnitLabel(converted?.unit ?? field.unit, config);
    return Tooltip(
      message:
          '${source.name}\n${(quote?.fieldErrors[field.id] ?? quote?.error) != null
              ? localizeAppError(context, quote!.fieldErrors[field.id] ?? quote!.error)
              : quote == null
              ? context.l10n.panelWaiting
              : context.l10n.panelUpdated(localizedValue((quote!.fieldUpdatedAt[field.id] ?? quote!.updatedAt), context.l10n))}${converted?.error == null ? '' : '\n${localizeAppError(context, converted!.error)}'}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing / 2 + 3),
        child: _EntryLayout(
          config: config,
          label: Text(
            field.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: style.fontSize),
          ),
          value: Row(
            mainAxisAlignment: number == null
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              Flexible(
                // Numbers keep one line and a reserved width; free text may
                // still wrap over up to three lines.
                child: number == null
                    ? Text(
                        formatValue(value),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          fontFamily: SystemFonts.family(config.fontFamily),
                        ),
                      )
                    : _StableText(
                        formatValue(
                          converted?.converted == true
                              ? converted!.value
                              : value,
                        ),
                        style: style,
                      ),
              ),
              if (unit.isNotEmpty)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Text(
                      unit,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              // The staleness marker keeps its slot so the value and unit do
              // not shift when a field starts or stops being stale.
              SizedBox(
                width: 15,
                child:
                    quote?.isFieldStale(field.id) == true ||
                        converted?.error != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.error_outline,
                          size: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widest plausible text for a metric unit, so the value slot is already
/// reserved before the first sample arrives.
List<String> _metricSeeds(String unit) => switch (unit) {
  '%' => const ['100.0%'],
  'B/s' => const ['000.0 MiB/s'],
  'B' => const ['000.0 GiB'],
  _ => const [],
};

/// Reserves the widest width this slot has needed so far, so a live number grows
/// into space that is already reserved instead of pushing its neighbours on
/// every refresh. [seeds] describe the widest plausible texts up front, so the
/// common cases never resize at all.
class _StableText extends StatefulWidget {
  const _StableText(this.text, {required this.style, this.seeds = const []});

  final String text;
  final TextStyle style;
  final List<String> seeds;

  @override
  State<_StableText> createState() => _StableTextState();
}

class _StableTextState extends State<_StableText> {
  double _width = 0;
  String? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reserve();
  }

  @override
  void didUpdateWidget(_StableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reserve();
  }

  void _reserve() {
    // Only measurements that affect the text width reset the slot: a price
    // turning red must not shrink it back.
    final scaler = MediaQuery.textScalerOf(context);
    final key = [
      widget.style.fontSize,
      widget.style.fontFamily,
      widget.style.fontWeight,
      widget.style.fontStyle,
      widget.style.letterSpacing,
      widget.style.wordSpacing,
      widget.style.height,
      widget.style.fontFeatures?.length,
      scaler.scale(10),
      ...widget.seeds,
    ].join('\u0000');
    if (key != _key) {
      _key = key;
      _width = 0;
    }
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    );
    var width = 0.0;
    for (final text in {...widget.seeds, widget.text}) {
      painter.text = TextSpan(text: text, style: widget.style);
      painter.layout();
      width = math.max(width, painter.width);
    }
    painter.dispose();
    if (width > _width) _width = width + .5;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _width,
    // Align keeps the text at its natural size while it fits, so a reserved
    // slot never changes the row height; the box only shrinks text that is
    // wider than the space a narrow panel leaves.
    child: Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          widget.text,
          maxLines: 1,
          textAlign: TextAlign.right,
          style: widget.style,
        ),
      ),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.onSettings});
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(context.l10n.panelChoose),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.add),
          label: Text(context.l10n.panelAdd),
        ),
      ],
    ),
  );
}
