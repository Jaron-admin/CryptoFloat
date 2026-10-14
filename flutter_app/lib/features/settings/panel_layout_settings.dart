import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'fluent_controls.dart';
import 'layout_strings.dart';

class PanelLayoutSettings extends StatelessWidget {
  const PanelLayoutSettings({
    super.key,
    required this.config,
    required this.onChanged,
    required this.target,
  });
  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;
  final DisplayTarget target;

  @override
  Widget build(BuildContext context) {
    final strings = LayoutStrings(
      Localizations.localeOf(context).languageCode == 'zh',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target == DisplayTarget.floating) ...[
          FDropdown<int>(
            key: const ValueKey('panel-column-count'),
            initialValue: config.panelColumnCount.clamp(1, 8),
            decoration: InputDecoration(labelText: strings.columns),
            items: [
              for (var count = 1; count <= 8; count++)
                FDropdownItem(
                  value: count,
                  child: Text(strings.columnCount(count)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(panelColumnCount: value));
              }
            },
          ),
          const SizedBox(height: 16),
          FDropdown<String>(
            key: const ValueKey('panel-item-layout'),
            initialValue: config.panelItemLayout,
            decoration: InputDecoration(labelText: strings.entryLayout),
            items: [
              FDropdownItem(
                value: 'horizontal',
                child: Text(strings.horizontal),
              ),
              FDropdownItem(value: 'vertical', child: Text(strings.vertical)),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(config.copyWith(panelItemLayout: value));
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            strings.narrowPanelHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        FSwitchListTile(
          key: const ValueKey('show-change-percent'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.showChangePercent),
          subtitle: Text(strings.hiddenPercentHint),
          value: config.showChangePercent,
          onChanged: (value) =>
              onChanged(config.copyWith(showChangePercent: value)),
        ),
        const SizedBox(height: 16),
        FDropdown<String>(
          key: const ValueKey('market-color-style'),
          initialValue: config.marketColorStyle,
          decoration: InputDecoration(labelText: strings.changeColors),
          items: [
            FDropdownItem(value: 'theme', child: Text(strings.themeColors)),
            FDropdownItem(value: 'greenUp', child: Text(strings.greenUp)),
            FDropdownItem(value: 'redUp', child: Text(strings.redUp)),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(config.copyWith(marketColorStyle: value));
            }
          },
        ),
        const SizedBox(height: 8),
        Text(strings.colorHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
