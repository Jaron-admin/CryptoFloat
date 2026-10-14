import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/metrics_strings.dart';
import '../panel/panel_page.dart';
import 'taskbar_settings.dart';

/// A fixed viewport into the same renderers used by the two display surfaces.
class SettingsLivePreview extends StatelessWidget {
  const SettingsLivePreview({
    super.key,
    required this.controller,
    required this.config,
    required this.target,
  });
  final AppController controller;
  final AppConfig config;
  final DisplayTarget target;

  @override
  Widget build(BuildContext context) {
    final chinese = context.metrics.chinese;
    final floating = target == DisplayTarget.floating;
    final brightness = switch (config.themeMode) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => MediaQuery.platformBrightnessOf(context),
    };
    final theme = buildAppTheme(config, brightness: brightness);
    return Container(
      key: const ValueKey('settings-live-preview'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chinese
                ? '实时预览 · ${floating ? '悬浮窗' : '任务栏'}'
                : 'Live preview · ${floating ? 'Floating panel' : 'Taskbar'}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRect(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Theme(
                  data: theme,
                  child: RepaintBoundary(
                    key: const ValueKey('settings-preview-render'),
                    child: floating
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: (config.windowBounds?.width ?? 360)
                                  .clamp(160, 1920)
                                  .toDouble(),
                              child: Opacity(
                                opacity: config.opacity,
                                child: LayoutBuilder(
                                  builder: (context, viewport) => Material(
                                    color: theme.colorScheme.surface,
                                    child: PanelContent(
                                      controller: controller,
                                      config: viewport.maxHeight < 70
                                          ? config.copyWith(
                                              showHeaderName: false,
                                              showHeaderIcon: false,
                                            )
                                          : config,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _TaskbarPreviewViewport(
                            child: TaskbarPreview(
                              config: config,
                              snapshot: controller.metrics.snapshot,
                              quotes: controller.displayQuotes,
                              rates: controller.data.exchangeRates,
                              priceTicks: {
                                for (final quote
                                    in controller.displayQuotes.values)
                                  quote.assetId: controller.priceTickFor(
                                    quote.assetId,
                                  ),
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskbarPreviewViewport extends StatefulWidget {
  const _TaskbarPreviewViewport({required this.child});
  final Widget child;

  @override
  State<_TaskbarPreviewViewport> createState() =>
      _TaskbarPreviewViewportState();
}

class _TaskbarPreviewViewportState extends State<_TaskbarPreviewViewport> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollbarTheme(
    data: ScrollbarTheme.of(context).copyWith(minThumbLength: 12),
    child: Scrollbar(
      key: const ValueKey('settings-taskbar-preview-scrollbar'),
      controller: _scrollController,
      thumbVisibility: true,
      interactive: true,
      thickness: 6,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: widget.child,
      ),
    ),
  );
}
