import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme_presets.dart';
import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import '../../domain/refresh_status.dart';
import '../../domain/system_metric.dart';
import '../../domain/display_snapshot.dart';
import '../../l10n/metrics_strings.dart';
import '../../domain/unit_conversion.dart';
import '../../platform/system_fonts.dart';
import 'display_row_view.dart';
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
  Widget build(BuildContext context) {
    final config = controller.config;
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
    final status = controller.refreshStatusFor(config);
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
          ),
        ),
    };
    final l10n = context.l10n;
    final intervalText = status.intervalsSeconds.isEmpty
        ? ''
        : l10n.panelAutoRefresh(
            status.intervalsSeconds
                .map(
                  (value) => value >= 60 && value % 60 == 0
                      ? l10n.panelMinutes(value ~/ 60)
                      : l10n.panelSeconds(value),
                )
                .join('/'),
          );
    final last = status.lastUpdatedAt;
    final now = DateTime.now();
    final updatedText = last == null
        ? ''
        : '${last.year != now.year || last.month != now.month || last.day != now.day ? '${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')} ' : ''}${formatValue(last)}';
    final statusText = switch (status.state) {
      RefreshState.noSources => l10n.panelNoSources,
      RefreshState.live => l10n.panelLive,
      RefreshState.waiting =>
        last == null
            ? l10n.panelWaiting
            : l10n.panelPending(updatedText, status.waitingSourceCount),
      RefreshState.stale => l10n.panelLastUpdate(updatedText),
    };
    final rateNote = config.displayCurrency.isNotEmpty && rates.isEmpty
        ? l10n.panelRatesPending
        : '';
    String fetchTime(String id) =>
        controller.data.lastSuccessfulFetchAt[id] == null
        ? l10n.panelWaiting
        : l10n.panelLastFetch(
            formatValue(controller.data.lastSuccessfulFetchAt[id]),
          );
    final details = [
      for (final asset in config.assets)
        '${localizedAssetName(asset, l10n)} · ${l10n.panelSourceInterval(asset.provider == 'YAHOO' ? 60 : 15)} · ${fetchTime(asset.id)}${quotes[asset.id]?.error == null ? '' : '\n${localizeAppError(context, quotes[asset.id]!.error)}'}',
      for (final source in config.customSources.where(
        (source) => source.enabled,
      ))
        '${source.name} · ${l10n.panelSourceInterval(source.refreshSeconds)} · ${fetchTime('custom:${source.id}')}',
      if (config.displayCurrency.isNotEmpty)
        '${l10n.panelRatesInterval}${controller.data.ratesFetchedAt == null ? '' : ' · ${l10n.panelLastFetch(formatValue(controller.data.ratesFetchedAt))}'}${controller.data.ratesError == null ? '' : '\n${localizeAppError(context, controller.data.ratesError)}'}',
      l10n.panelLiveNote,
    ].join('\n\n');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (event) => _menu(context, event.globalPosition),
      onDoubleTap: controller.hideToTray,
      onHorizontalDragStart: (_) => controller.host.beginDrag(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (config.showHeaderName || config.showHeaderIcon)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => controller.host.beginDrag(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    localizeAppError(context, controller.startupMessage),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
                  children: [
                    for (final id in buildDisplayTexts(
                      config,
                      quotes,
                      controller.metrics.snapshot,
                      rates: rates,
                    ).map((entry) => entry.id))
                      KeyedSubtree(
                        key: ValueKey('panel-$id'),
                        child: content[id]!,
                      ),
                    if (content.isEmpty)
                      _EmptyPanel(onSettings: () => onSettings(0)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: details,
                        child: Text(
                          '$statusText$intervalText$rateNote',
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 10,
                            color: status.isLive
                                ? marketColorsOf(context).positive
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onPanStart: (_) =>
                          controller.host.beginResize('bottomRight'),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.south_east,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        child: Row(
          children: [
            Expanded(
              child: Text(
                metric.name(context.metrics.chinese),
                style: TextStyle(
                  fontFamily: SystemFonts.family(config.fontFamily),
                  fontSize: config.fontSize,
                ),
              ),
            ),
            Flexible(
              child: Text(text.text, style: style, textAlign: TextAlign.right),
            ),
          ],
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

Color _changeColor(BuildContext context, Object? value) => value is num
    ? (value >= 0
          ? marketColorsOf(context).positive
          : marketColorsOf(context).negative)
    : Theme.of(context).colorScheme.onSurfaceVariant;

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.quote,
    required this.style,
    required this.spacing,
    required this.config,
    required this.rates,
  });
  final Asset asset;
  final MarketQuote? quote;
  final TextStyle style;
  final double spacing;
  final AppConfig config;
  final Map<String, double> rates;
  @override
  Widget build(BuildContext context) {
    final currency = quote?.currency.isNotEmpty == true
        ? quote!.currency
        : asset.currency;
    final converted = quote?.price == null
        ? null
        : convertUnitValue(quote!.price!, currency, config, rates);
    final symbol = asset.kind == MarketKind.crypto
        ? asset.symbol.split('-').first.replaceFirst(RegExp(r'USDT$'), '')
        : asset.symbol;
    return Tooltip(
      message:
          '${localizedAssetName(asset, context.l10n)} · ${asset.provider}\n${quote == null ? context.l10n.panelWaiting : context.l10n.panelQuoteTime(localizedValue(quote!.updatedAt, context.l10n))}${quote?.error == null ? '' : '\n${localizeAppError(context, quote!.error)}'}${converted?.error == null ? '' : '\n${localizeAppError(context, converted!.error)}'}${converted?.converted == true ? '\n${context.l10n.panelOriginal(formatValue(quote?.price), currency)}' : ''}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing / 2 + 3),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Column(
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
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatValue(converted?.value ?? quote?.price),
                    style: style,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: Text(
                displayUnitLabel(converted?.unit ?? currency, config),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: 66,
              child: Text(
                quote?.changePercent == null
                    ? '—'
                    : '${formatValue(quote!.changePercent, '+.2f')}%',
                textAlign: TextAlign.right,
                style: style.copyWith(
                  fontSize: (style.fontSize ?? 15) - 2,
                  color: _changeColor(context, quote?.changePercent),
                ),
              ),
            ),
            if (quote?.isStale == true || converted?.error != null)
              Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.error_outline,
                  size: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
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
        : (field.unit.isNotEmpty ? num.tryParse('$value') : null);
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
        child: Row(
          children: [
            Expanded(
              child: Text(
                field.label,
                style: TextStyle(fontSize: style.fontSize),
              ),
            ),
            Flexible(
              child: Text(
                formatValue(
                  converted?.converted == true ? converted!.value : value,
                ),
                style: number == null
                    ? style.copyWith(
                        fontFamily: SystemFonts.family(config.fontFamily),
                      )
                    : style,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            if (quote?.isFieldStale(field.id) == true ||
                converted?.error != null)
              Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.error_outline,
                  size: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
