import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme_presets.dart';
import '../../app/market_change_colors.dart';
import '../../domain/refresh_price.dart';
import '../../domain/models.dart';
import '../../domain/system_metric.dart';
import '../../domain/display_snapshot.dart';
import '../../l10n/metrics_strings.dart';
import '../../platform/system_fonts.dart';

class TaskbarSettingsView extends StatelessWidget {
  const TaskbarSettingsView({
    super.key,
    required this.config,
    required this.snapshot,
    required this.status,
    required this.onChanged,
    this.quotes = const {},
    this.rates = const {},
    this.priceTicks = const {},
  });
  final AppConfig config;
  final SystemMetricSnapshot snapshot;
  final String status;
  final ValueChanged<AppConfig> onChanged;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;
  final Map<String, PriceTick> priceTicks;
  @override
  Widget build(BuildContext context) {
    final strings = context.metrics;
    final taskbar = config.taskbar;
    final brightness = switch (config.themeMode) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => MediaQuery.platformBrightnessOf(context),
    };
    final palette = resolveAppPalette(config, brightness: brightness);
    Color cellColor(DisplayText cell) {
      final assetId = cell.id.startsWith('asset:')
          ? cell.id.substring('asset:'.length)
          : '';
      return taskbarPriceColor(
        cellId: cell.id,
        stale: cell.stale,
        priceColorMode: config.priceColorMode,
        tick: priceTicks[assetId] ?? PriceTick.neutral,
        foreground: palette.foreground,
        secondary: palette.secondary,
        brightness: brightness,
        themeColors: MarketColors(
          positive: palette.positive,
          negative: palette.negative,
        ),
      );
    }

    final allCells = buildDisplayTexts(config, quotes, snapshot, rates: rates);
    final cells = taskbarVisibleCells(allCells, chinese: strings.chinese);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.taskbarLayout,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.showTaskbar),
          subtitle: Text(strings.status(status)),
          value: taskbar.enabled,
          onChanged: (value) => onChanged(
            config.copyWith(taskbar: taskbar.copyWith(enabled: value)),
          ),
        ),
        const SizedBox(height: 16),
        Text(strings.layout),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 1, label: Text(strings.oneLine)),
            ButtonSegment(value: 2, label: Text(strings.twoLines)),
          ],
          selected: {taskbar.lineCount},
          onSelectionChanged: (values) => onChanged(
            config.copyWith(
              taskbar: taskbar.copyWith(lineCount: values.single),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('${strings.maximumWidth} · ${taskbar.width.round()} px'),
        Slider(
          value: taskbar.width.clamp(120, 1200),
          min: 120,
          max: 1200,
          divisions: 108,
          onChanged: (value) => onChanged(
            config.copyWith(taskbar: taskbar.copyWith(width: value)),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('taskbar-transparent'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.transparentBackground),
          value: taskbar.transparentBackground,
          onChanged: (value) => onChanged(
            config.copyWith(
              taskbar: taskbar.copyWith(transparentBackground: value),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('${strings.itemGap} · ${taskbar.itemGap} px'),
        Slider(
          key: const ValueKey('taskbar-item-gap'),
          value: taskbar.itemGap.toDouble(),
          min: 0,
          max: 24,
          divisions: 24,
          onChanged: (value) => onChanged(
            config.copyWith(taskbar: taskbar.copyWith(itemGap: value.round())),
          ),
        ),
        Text(strings.labelStyle),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'short', label: Text(strings.shortLabels)),
            ButtonSegment(value: 'full', label: Text(strings.fullLabels)),
          ],
          selected: {taskbar.labelMode},
          onSelectionChanged: (values) => onChanged(
            config.copyWith(
              taskbar: taskbar.copyWith(labelMode: values.single),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(strings.preview, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _TaskbarPreview(
          config: config,
          cells: cells,
          chinese: strings.chinese,
          background: palette.background,
          foreground: palette.foreground,
          cellColor: cellColor,
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          key: const ValueKey('taskbar-aliases'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(strings.aliases),
          children: [
            for (final cell in allCells)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: ValueKey('taskbar-alias-${cell.id}'),
                  initialValue: taskbar.labelAliases[cell.id] ?? '',
                  maxLength: 64,
                  decoration: InputDecoration(
                    labelText: boundedTaskbarText(
                      cell.label.isEmpty ? cell.value : cell.label,
                      80,
                    ),
                    hintText: strings.aliasHint,
                    counterText: '',
                    isDense: true,
                  ),
                  onChanged: (value) => onChanged(
                    config.copyWith(
                      taskbar: taskbar.copyWith(
                        labelAliases: {...taskbar.labelAliases, cell.id: value},
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TaskbarPreview extends StatelessWidget {
  const _TaskbarPreview({
    required this.config,
    required this.cells,
    required this.chinese,
    required this.background,
    required this.foreground,
    required this.cellColor,
  });

  final AppConfig config;
  final List<DisplayText> cells;
  final bool chinese;
  final Color background, foreground;
  final Color Function(DisplayText) cellColor;

  @override
  Widget build(BuildContext context) {
    final taskbar = config.taskbar;
    final rows = taskbar.lineCount == 1 ? 1 : 2;
    final gap = taskbar.itemGap.clamp(0, 24);
    final maxWidth = taskbar.width.isFinite
        ? taskbar.width.clamp(120, 1200).round()
        : 360;
    final fontSize = config.fontSize.isFinite
        ? config.fontSize.clamp(6, 32).toDouble()
        : 12.0;
    final style = DefaultTextStyle.of(context).style.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontFamily: SystemFonts.family(config.fontFamily),
      color: foreground,
    );
    final direction = Directionality.of(context);

    TextSpan span(String text, Color color) => TextSpan(
      style: style.copyWith(color: color),
      children: [
        for (final match in RegExp(r'[0-9.,%−]+|[^0-9.,%−]+').allMatches(text))
          TextSpan(
            text: match.group(0),
            style: TextStyle(
              fontFamily: SystemFonts.family(
                RegExp(r'^[0-9.,%−]').hasMatch(match.group(0)!)
                    ? config.numberFontFamily
                    : config.fontFamily,
              ),
            ),
          ),
      ],
    );
    int measure(TextSpan text) {
      final painter = TextPainter(
        text: text,
        textDirection: direction,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      final width = math.max(1, painter.width.ceil());
      painter.dispose();
      return width;
    }

    final texts = [
      for (final cell in cells)
        boundedTaskbarText(
          taskbarCellText(
            cell,
            config: taskbar,
            assets: config.assets,
            showChangePercent: config.showChangePercent,
          ),
          200,
        ),
    ];
    final spans = [
      for (var i = 0; i < cells.length; i++)
        span(texts[i], cellColor(cells[i])),
    ];
    final desired = List<int>.filled((cells.length + rows - 1) ~/ rows, 1);
    for (var i = 0; i < cells.length; i++) {
      desired[i ~/ rows] = math.max(desired[i ~/ rows], measure(spans[i]));
    }
    // Match the native host: width is a cap, and paired rows share a column.
    final naturalWidth =
        8 +
        desired.fold<int>(0, (sum, width) => sum + width) +
        math.max(0, desired.length - 1) * gap;
    final width = naturalWidth.clamp(64, maxWidth);
    final columns = _compactPreviewColumns(
      desired,
      width - 8,
      gap,
      measure(span('…', foreground)),
    );
    final omitted = columns.length < desired.length;

    Widget cell(int column, int row) {
      final index = column * rows + row;
      if (index >= cells.length) {
        return SizedBox(width: columns[column].toDouble());
      }
      final text = omitted && column == columns.length - 1
          ? span('${texts[index]} …', cellColor(cells[index]))
          : spans[index];
      return SizedBox(
        key: ValueKey('taskbar-preview-cell-${cells[index].id}'),
        width: columns[column].toDouble(),
        child: Tooltip(
          message: boundedTaskbarText(
            taskbarCellTooltip(cells[index], chinese: chinese),
            600,
          ),
          child: Text.rich(
            text,
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          key: const ValueKey('taskbar-preview'),
          width: width.toDouble(),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          color: taskbar.transparentBackground ? null : background,
          child: cells.isEmpty
              ? Text('—', style: style)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var row = 0; row < rows; row++)
                      Row(
                        children: [
                          for (
                            var column = 0;
                            column < columns.length;
                            column++
                          ) ...[
                            if (column > 0) SizedBox(width: gap.toDouble()),
                            cell(column, row),
                          ],
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// The same fair cap used by native CompactColumns: retain short columns at
// natural width and share the remaining room among longer columns.
List<int> _compactPreviewColumns(
  List<int> desired,
  int available,
  int gap,
  int minimum,
) {
  if (desired.isEmpty || available <= 0) return [];
  var count = desired.length;
  while (count > 1 && count * minimum + (count - 1) * gap > available) {
    count--;
  }
  final room = math.max(0, available - (count - 1) * gap);
  final widths = desired.take(count).toList();
  if (widths.fold<int>(0, (sum, width) => sum + width) <= room) return widths;
  var low = 0;
  var high = widths.reduce(math.max);
  while (low < high) {
    final cap = low + (high - low + 1) ~/ 2;
    final used = widths.fold<int>(
      0,
      (sum, width) => sum + math.min(width, cap),
    );
    if (used <= room) {
      low = cap;
    } else {
      high = cap - 1;
    }
  }
  var used = 0;
  for (var i = 0; i < count; i++) {
    widths[i] = math.min(widths[i], low);
    used += widths[i];
  }
  for (var i = 0; i < count && used < room; i++) {
    if (widths[i] < desired[i]) {
      widths[i]++;
      used++;
    }
  }
  return widths;
}
