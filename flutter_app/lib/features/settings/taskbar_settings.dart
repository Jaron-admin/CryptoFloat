import 'package:flutter/material.dart';

import '../../app/theme_presets.dart';
import '../../app/market_change_colors.dart';
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
  });
  final AppConfig config;
  final SystemMetricSnapshot snapshot;
  final String status;
  final ValueChanged<AppConfig> onChanged;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;
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
    final changeColors = resolveMarketChangeColors(
      config,
      brightness: brightness,
      themeColors: MarketColors(
        positive: palette.positive,
        negative: palette.negative,
      ),
    );
    Color cellColor(DisplayText cell) {
      if (cell.stale) return palette.secondary;
      final change = cell.change;
      if (config.showChangePercent ||
          change == null ||
          !change.isFinite ||
          change == 0) {
        return palette.foreground;
      }
      return change > 0 ? changeColors.positive : changeColors.negative;
    }

    final cells = taskbarVisibleCells(
      buildDisplayTexts(config, quotes, snapshot, rates: rates),
      chinese: strings.chinese,
    );
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
        Text('${strings.width} · ${taskbar.width.round()} px'),
        Slider(
          value: taskbar.width.clamp(120, 1200),
          min: 120,
          max: 1200,
          divisions: 108,
          onChanged: (value) => onChanged(
            config.copyWith(taskbar: taskbar.copyWith(width: value)),
          ),
        ),
        const SizedBox(height: 16),
        Text(strings.preview, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: taskbar.width,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: palette.background,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < taskbar.lineCount; row++)
                    Row(
                      children: [
                        for (
                          var i = row;
                          i < cells.length;
                          i += taskbar.lineCount
                        )
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    for (final match
                                        in RegExp(r'[0-9.,%−]+|[^0-9.,%−]+')
                                            .allMatches(
                                              boundedTaskbarText(
                                                taskbarCellText(
                                                  cells[i],
                                                  showChangePercent:
                                                      config.showChangePercent,
                                                ),
                                                200,
                                              ),
                                            ))
                                      TextSpan(
                                        text: match.group(0),
                                        style: TextStyle(
                                          fontFamily: SystemFonts.family(
                                            RegExp(r'^[0-9.,%−]')
                                                    .hasMatch(match.group(0)!)
                                                ? config.numberFontFamily
                                                : config.fontFamily,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cellColor(cells[i]),
                                  fontSize: config.fontSize,
                                ),
                              ),
                            ),
                          ),
                        if (cells.length % taskbar.lineCount != 0 && row == 1)
                          const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  if (cells.isEmpty)
                    Text('—', style: TextStyle(color: palette.foreground)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
