import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

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
    final allCells = buildDisplayTexts(config, quotes, snapshot, rates: rates);
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
        Text(strings.adaptiveWidth),
        const SizedBox(height: 16),
        Text(strings.overflowBehavior),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const ValueKey('taskbar-overflow-mode'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'auto', label: Text(strings.autoCarousel)),
            ButtonSegment(value: 'manual', label: Text(strings.manualWheel)),
          ],
          selected: {taskbar.overflowMode},
          onSelectionChanged: (values) => onChanged(
            config.copyWith(
              taskbar: taskbar.copyWith(overflowMode: values.single),
            ),
          ),
        ),
        if (taskbar.overflowMode == 'auto') ...[
          const SizedBox(height: 12),
          Text(
            '${strings.carouselInterval} · ${strings.seconds(taskbar.carouselIntervalSeconds)}',
          ),
          Slider(
            key: const ValueKey('taskbar-carousel-interval'),
            value: taskbar.carouselIntervalSeconds.toDouble(),
            min: 2,
            max: 60,
            divisions: 58,
            onChanged: (value) => onChanged(
              config.copyWith(
                taskbar: taskbar.copyWith(
                  carouselIntervalSeconds: value.round(),
                ),
              ),
            ),
          ),
        ],
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
        Text('${strings.labelValueGap} · ${taskbar.labelValueGap} px'),
        Slider(
          key: const ValueKey('taskbar-label-value-gap'),
          value: taskbar.labelValueGap.toDouble(),
          min: 0,
          max: 24,
          divisions: 24,
          onChanged: (value) => onChanged(
            config.copyWith(
              taskbar: taskbar.copyWith(labelValueGap: value.round()),
            ),
          ),
        ),
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

class TaskbarPreview extends StatefulWidget {
  const TaskbarPreview({
    super.key,
    required this.config,
    required this.snapshot,
    this.quotes = const {},
    this.rates = const {},
    this.priceTicks = const {},
  });

  final AppConfig config;
  final SystemMetricSnapshot snapshot;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;
  final Map<String, PriceTick> priceTicks;

  @override
  State<TaskbarPreview> createState() => _TaskbarPreviewState();
}

class _TaskbarPreviewState extends State<TaskbarPreview> {
  Timer? _timer;
  bool _hovered = false;
  int _page = 0;
  int _pageCount = 1;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(TaskbarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.config.taskbar;
    final after = widget.config.taskbar;
    if (before.overflowMode != after.overflowMode ||
        before.carouselIntervalSeconds != after.carouselIntervalSeconds) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_hovered && widget.config.taskbar.overflowMode != 'manual') {
      _timer = Timer.periodic(
        Duration(
          seconds: widget.config.taskbar.carouselIntervalSeconds.clamp(2, 60),
        ),
        (_) => _advance(1),
      );
    }
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    _restartTimer();
  }

  void _advance(int delta) {
    if (!mounted || _pageCount <= 1) return;
    setState(() => _page = (_page + delta) % _pageCount);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final taskbar = config.taskbar;
    final chinese = context.metrics.chinese;
    final cells = taskbarVisibleCells(
      buildDisplayTexts(
        config,
        widget.quotes,
        widget.snapshot,
        rates: widget.rates,
      ),
      chinese: chinese,
    );
    final brightness = switch (config.themeMode) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => MediaQuery.platformBrightnessOf(context),
    };
    final palette = resolveAppPalette(config, brightness: brightness);
    final marketColors = MarketColors(
      positive: palette.positive,
      negative: palette.negative,
    );
    final rows = taskbar.lineCount == 1 ? 1 : 2;
    final gap = taskbar.itemGap.clamp(0, 24).toDouble();
    final labelGap = taskbar.labelValueGap.clamp(0, 24).toDouble();
    final fontSize = config.fontSize.isFinite
        ? config.fontSize.clamp(6, 32).toDouble()
        : 12.0;
    final style = DefaultTextStyle.of(context).style.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontFamily: SystemFonts.family(config.fontFamily),
      color: palette.foreground,
    );

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

    double measure(TextSpan text) {
      final painter = TextPainter(
        text: text,
        textDirection: Directionality.of(context),
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    final rendered = [
      for (final cell in cells)
        _PreviewCell(
          cell: cell,
          label: span(
            boundedTaskbarText(
              taskbarCellLabel(cell, config: taskbar, assets: config.assets),
              200,
            ),
            palette.foreground,
          ),
          value: span(
            taskbarCellValue(cell),
            taskbarPriceColor(
              cellId: cell.id,
              stale: cell.stale,
              priceColorMode: config.priceColorMode,
              tick:
                  widget.priceTicks[cell.id.startsWith('asset:')
                      ? cell.id.substring(6)
                      : ''] ??
                  PriceTick.neutral,
              foreground: palette.foreground,
              secondary: palette.secondary,
              brightness: brightness,
              themeColors: marketColors,
            ),
          ),
          suffix: span(
            taskbarCellSuffix(
              cell,
              showChangePercent: config.showChangePercent,
            ),
            marketChangeColorValue(
              change: cell.change,
              config: config,
              neutral: palette.secondary,
              brightness: brightness,
              themeColors: marketColors,
            ),
          ),
        ),
    ];
    final desired = List<double>.filled((cells.length + rows - 1) ~/ rows, 1);
    for (var i = 0; i < rendered.length; i++) {
      final entry = rendered[i];
      entry.labelWidth = measure(entry.label);
      entry.valueWidth = measure(entry.value);
      entry.suffixWidth = measure(entry.suffix);
      entry.width =
          entry.labelWidth +
          entry.valueWidth +
          entry.suffixWidth +
          (entry.labelWidth > 0 &&
                  (entry.valueWidth > 0 || entry.suffixWidth > 0)
              ? labelGap
              : 0) +
          (entry.valueWidth > 0 && entry.suffixWidth > 0 ? 4 : 0);
      desired[i ~/ rows] = math.max(desired[i ~/ rows], entry.width);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final naturalWidth =
            8 +
            desired.fold<double>(0, (sum, width) => sum + width) +
            math.max(0, desired.length - 1) * gap;
        final available = constraints.hasBoundedWidth
            ? math.max(0.0, constraints.maxWidth - 8)
            : math.max(1.0, naturalWidth - 8);
        final pages = _previewPages(desired, available, gap);
        _pageCount = math.max(1, pages.length);
        _page %= _pageCount;
        final columns = pages.isEmpty ? <int>[] : pages[_page];
        final widths = [
          for (final column in columns) math.min(desired[column], available),
        ];
        final width = math.min(
          constraints.hasBoundedWidth ? constraints.maxWidth : naturalWidth,
          math.max(
            8.0,
            8 +
                widths.fold<double>(0, (sum, value) => sum + value) +
                math.max(0, columns.length - 1) * gap,
          ),
        );

        Widget cell(int slot, int row) {
          final index = columns[slot] * rows + row;
          if (index >= rendered.length) return SizedBox(width: widths[slot]);
          final entry = rendered[index];
          Widget part(String name, TextSpan text, double partWidth) => SizedBox(
            width: partWidth,
            child: Text.rich(
              text,
              key: ValueKey('taskbar-preview-$name-${entry.cell.id}'),
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          );
          return SizedBox(
            key: ValueKey('taskbar-preview-cell-${entry.cell.id}'),
            width: widths[slot],
            child: Tooltip(
              message: boundedTaskbarText(
                taskbarCellTooltip(entry.cell, chinese: chinese),
                600,
              ),
              child: ClipRect(
                child: OverflowBox(
                  fit: OverflowBoxFit.deferToChild,
                  alignment: Alignment.centerLeft,
                  minWidth: entry.width,
                  maxWidth: entry.width,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.labelWidth > 0)
                        part('label', entry.label, entry.labelWidth),
                      if (entry.labelWidth > 0 &&
                          (entry.valueWidth > 0 || entry.suffixWidth > 0))
                        SizedBox(width: labelGap),
                      part('value', entry.value, entry.valueWidth),
                      if (entry.suffixWidth > 0) ...[
                        if (entry.valueWidth > 0) const SizedBox(width: 4),
                        part('suffix', entry.suffix, entry.suffixWidth),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent && _pageCount > 1) {
                GestureBinding.instance.pointerSignalResolver.register(event, (
                  event,
                ) {
                  final scroll = event as PointerScrollEvent;
                  final delta = scroll.scrollDelta.dy != 0
                      ? scroll.scrollDelta.dy
                      : scroll.scrollDelta.dx;
                  if (delta != 0) {
                    _advance(delta > 0 ? 1 : -1);
                    _restartTimer();
                  }
                });
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: const ValueKey('taskbar-preview'),
                  width: width,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  color: taskbar.transparentBackground
                      ? null
                      : palette.background,
                  child: cells.isEmpty
                      ? Text('—', style: style)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var row = 0; row < rows; row++)
                              Row(
                                children: [
                                  for (
                                    var slot = 0;
                                    slot < columns.length;
                                    slot++
                                  ) ...[
                                    if (slot > 0) SizedBox(width: gap),
                                    cell(slot, row),
                                  ],
                                ],
                              ),
                          ],
                        ),
                ),
                if (_pageCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${_page + 1}/$_pageCount · ${chinese ? '滚轮翻页' : 'Scroll to change page'}',
                      key: const ValueKey('taskbar-preview-page'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewCell {
  _PreviewCell({
    required this.cell,
    required this.label,
    required this.value,
    required this.suffix,
  });
  final DisplayText cell;
  final TextSpan label, value, suffix;
  double labelWidth = 0, valueWidth = 0, suffixWidth = 0, width = 0;
}

// Keep each complete paired-row column together on one page.
List<List<int>> _previewPages(
  List<double> desired,
  double available,
  double gap,
) {
  final pages = <List<int>>[];
  var page = <int>[];
  var used = 0.0;
  for (var index = 0; index < desired.length; index++) {
    final width = math.min(desired[index], available);
    if (page.isNotEmpty && used + gap + width > available) {
      pages.add(page);
      page = [];
      used = 0;
    }
    if (page.isNotEmpty) used += gap;
    page.add(index);
    used += width;
  }
  if (page.isNotEmpty) pages.add(page);
  return pages;
}
