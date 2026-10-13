import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/system_metric.dart';
import '../../domain/display_snapshot.dart';
import '../../l10n/metrics_strings.dart';

class SystemMonitorSettingsView extends StatelessWidget {
  const SystemMonitorSettingsView({
    super.key,
    required this.config,
    required this.snapshot,
    required this.onChanged,
  });
  final AppConfig config;
  final SystemMetricSnapshot snapshot;
  final ValueChanged<AppConfig> onChanged;

  void _toggle(String id, bool enabled) => onChanged(
    config.copyWith(
      selectedMetricIds: [
        ...config.selectedMetricIds.where((item) => item != id),
        if (enabled) id,
      ],
    ),
  );
  void _move(int from, int to) {
    final ids = [...config.selectedMetricIds];
    ids.insert(to, ids.removeAt(from));
    onChanged(config.copyWith(selectedMetricIds: ids));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.metrics;
    final options = config.systemMonitor;
    Widget devices(
      String label,
      String selected,
      String defaultId,
      String defaultLabel,
      List<MetricDevice> values,
      ValueChanged<String> change,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$selected'),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          DropdownMenuItem(value: defaultId, child: Text(defaultLabel)),
          if (selected != defaultId &&
              !values.any((entry) => entry.id == selected))
            DropdownMenuItem(
              value: selected,
              child: Text(strings.missingDevice),
            ),
          for (final value in {
            for (final value in values) value.id: value,
          }.values)
            DropdownMenuItem(
              value: value.id,
              child: Text(value.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) change(value);
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.system, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(strings.monitorDescription),
        const SizedBox(height: 16),
        if (config.selectedMetricIds.isNotEmpty) ...[
          Text(
            strings.selectedMetrics,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: config.selectedMetricIds.length,
            onReorderItem: _move,
            itemBuilder: (context, index) {
              final id = config.selectedMetricIds[index];
              final definition = systemMetricCatalog
                  .where((metric) => metric.id == id)
                  .firstOrNull;
              final value = metricTextFor(
                id,
                snapshot.reading(id, intervalSeconds: options.intervalSeconds),
                config,
              );
              return Material(
                key: ValueKey('metric-order-$id'),
                color: Colors.transparent,
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.drag_indicator, size: 18),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        definition?.name(strings.chinese) ?? id,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      value.text,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      tooltip: strings.up,
                      visualDensity: VisualDensity.compact,
                      onPressed: index == 0
                          ? null
                          : () => _move(index, index - 1),
                      icon: const Icon(Icons.arrow_upward, size: 17),
                    ),
                    IconButton(
                      tooltip: strings.down,
                      visualDensity: VisualDensity.compact,
                      onPressed: index == config.selectedMetricIds.length - 1
                          ? null
                          : () => _move(index, index + 1),
                      icon: const Icon(Icons.arrow_downward, size: 17),
                    ),
                    IconButton(
                      tooltip: strings.remove,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggle(id, false),
                      icon: const Icon(Icons.close, size: 17),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        Text(
          strings.metricLibrary,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final metric in systemMetricCatalog)
          CheckboxListTile(
            key: ValueKey('metric-select-${metric.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(metric.name(strings.chinese)),
            secondary: Text(
              metric.unit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: config.selectedMetricIds.contains(metric.id),
            onChanged: (value) => _toggle(metric.id, value == true),
          ),
        const Divider(height: 32),
        Text(
          strings.deviceSettings,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          strings.sharedDevices,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(
          children: [
            Text(strings.interval),
            Expanded(
              child: Slider(
                value: options.intervalSeconds.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                label: strings.seconds(options.intervalSeconds),
                onChanged: (value) => onChanged(
                  config.copyWith(
                    systemMonitor: options.copyWith(
                      intervalSeconds: value.round(),
                    ),
                  ),
                ),
              ),
            ),
            Text(strings.seconds(options.intervalSeconds)),
          ],
        ),
        devices(
          strings.adapter,
          options.networkAdapterId,
          'auto',
          strings.physicalAdapters,
          snapshot.networkAdapters,
          (id) => onChanged(
            config.copyWith(
              systemMonitor: options.copyWith(networkAdapterId: id),
            ),
          ),
        ),
        devices(
          strings.gpu,
          options.gpuAdapterId,
          'auto',
          strings.automatic,
          snapshot.gpuAdapters,
          (id) => onChanged(
            config.copyWith(systemMonitor: options.copyWith(gpuAdapterId: id)),
          ),
        ),
        devices(
          strings.disk,
          options.diskId,
          'all',
          strings.allDisks,
          snapshot.disks,
          (id) => onChanged(
            config.copyWith(systemMonitor: options.copyWith(diskId: id)),
          ),
        ),
      ],
    );
  }
}
