import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'fluent_controls.dart';
import '../panel/display_row_view.dart';

const _builtinFields = <String, String>{
  'symbol': '代码',
  'name': '名称',
  'price': '价格',
  'currency': '货币单位',
  'change': '涨跌幅',
  'provider': '数据源',
  'updatedAt': '更新时间',
};

String fieldLabel(DisplaySegment segment, AppConfig config) {
  final asset = [
    ...Asset.popular,
    ...config.customAssets,
  ].where((asset) => asset.id == segment.assetId).firstOrNull;
  if (asset != null) {
    return '${asset.name} · ${_builtinFields[segment.fieldId] ?? segment.fieldId}';
  }
  final source = config.customSources
      .where((source) => 'custom:${source.id}' == segment.assetId)
      .firstOrNull;
  final field = source?.fields
      .where((field) => field.id == segment.fieldId)
      .firstOrNull;
  return '${source?.name ?? '未找到的数据源'} · ${field?.label ?? segment.fieldId}';
}

class RowEditor extends StatefulWidget {
  const RowEditor({
    super.key,
    required this.config,
    required this.quotes,
    this.rates = const {},
    this.row,
  });
  final AppConfig config;
  final Map<String, MarketQuote> quotes;
  final Map<String, double> rates;
  final DisplayRow? row;
  @override
  State<RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<RowEditor> {
  late List<DisplaySegment> _segments;
  @override
  void initState() {
    super.initState();
    _segments = [...?widget.row?.segments];
  }

  DisplayRow get _row => DisplayRow(
    id: widget.row?.id ?? 'row_${DateTime.now().microsecondsSinceEpoch}',
    segments: _segments,
  );

  Future<void> _text([int? index]) async {
    final input = TextEditingController(
      text: index == null ? '' : _segments[index].text,
    );
    final result = await f.showDialog<String>(
      context: context,
      builder: (context) => FAlertDialog(
        title: const Text('显示文字'),
        content: SizedBox(
          width: 450,
          child: FTextField(
            controller: input,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '想显示的文字',
              hintText: '例如：今天的价格：  或  我的余额 ',
            ),
          ),
        ),
        actions: [
          FTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FFilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('加入显示'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _segments.add(DisplaySegment.literal(result));
      } else {
        _segments[index] = DisplaySegment.literal(result);
      }
    });
  }

  Future<void> _field([int? index]) async {
    final result = await f.showDialog<DisplaySegment>(
      context: context,
      builder: (context) => _FieldDialog(
        config: widget.config,
        segment: index == null ? null : _segments[index],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _segments.add(result);
        if (result.fieldId == 'change') {
          _segments.add(const DisplaySegment.literal('%'));
        }
      } else {
        _segments[index] = result;
      }
    });
  }

  void _move(int index, int offset) => setState(() {
    final segment = _segments.removeAt(index);
    _segments.insert(index + offset, segment);
  });
  @override
  Widget build(BuildContext context) => FDialog(
    child: SizedBox(
      width: 720,
      height: max(160, min(650, MediaQuery.sizeOf(context).height - 64)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '组合显示行',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                FIconButton(
                  tooltip: '关闭编辑器',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                Text(
                  '文字与字段从左到右显示，可加入空格和标点。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FButton.icon(
                      onPressed: _text,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('添加文字'),
                    ),
                    FFilledButton.icon(
                      onPressed: _field,
                      icon: const Icon(Icons.add_chart),
                      label: const Text('添加数据字段'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_segments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('尚未添加文字或字段')),
                  ),
                for (var i = 0; i < _segments.length; i++) _segmentCard(i),
                const SizedBox(height: 16),
                Text(
                  '最终显示预览',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DisplayRowView(
                    row: _row,
                    config: widget.config,
                    quotes: widget.quotes,
                    rates: widget.rates,
                    showFreshness: false,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const f.Divider(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FTextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                FFilledButton(
                  onPressed: _segments.isEmpty
                      ? null
                      : () => Navigator.pop(context, _row),
                  child: const Text('保存这一行'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _segmentCard(int index) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: f.Card(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 440;
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FIconButton(
                tooltip: '左移',
                onPressed: index == 0 ? null : () => _move(index, -1),
                icon: const Icon(Icons.arrow_back, size: 17),
              ),
              FIconButton(
                tooltip: '右移',
                onPressed: index == _segments.length - 1
                    ? null
                    : () => _move(index, 1),
                icon: const Icon(Icons.arrow_forward, size: 17),
              ),
              FIconButton(
                tooltip: '移除',
                onPressed: () => setState(() => _segments.removeAt(index)),
                icon: const Icon(Icons.close, size: 17),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FListTile(
                leading: Icon(
                  _segments[index].isField
                      ? Icons.data_object
                      : Icons.text_fields,
                ),
                title: Text(
                  _segments[index].isField
                      ? fieldLabel(_segments[index], widget.config)
                      : _segments[index].text.isEmpty
                      ? '空文字'
                      : _segments[index].text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: _segments[index].isField
                    ? Text(
                        '格式：${_segments[index].format.isEmpty ? '自动' : _segments[index].format}',
                      )
                    : null,
                onTap: () =>
                    _segments[index].isField ? _field(index) : _text(index),
                trailing: narrow ? null : actions,
              ),
              if (narrow)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _FieldDialog extends StatefulWidget {
  const _FieldDialog({required this.config, this.segment});
  final AppConfig config;
  final DisplaySegment? segment;
  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  late final Map<String, String> _sources;
  String? _source;
  String? _field;
  String _format = '';
  Map<String, String> get _fields => _source?.startsWith('custom:') == true
      ? {
          for (final source in widget.config.customSources.where(
            (source) => 'custom:${source.id}' == _source,
          ))
            for (final field in source.fields) field.id: field.label,
        }
      : _builtinFields;
  @override
  void initState() {
    super.initState();
    _sources = {
      for (final asset in widget.config.assets)
        asset.id: '${asset.name} · ${asset.provider}',
      for (final source in widget.config.customSources)
        'custom:${source.id}': source.name,
    };
    _source = _sources.containsKey(widget.segment?.assetId)
        ? widget.segment!.assetId
        : _sources.keys.firstOrNull;
    _field = _fields.containsKey(widget.segment?.fieldId)
        ? widget.segment!.fieldId
        : _fields.keys.firstOrNull;
    _format = ['', '.2f', '.4f', '+.2f', 'raw'].contains(widget.segment?.format)
        ? widget.segment!.format
        : '';
  }

  @override
  Widget build(BuildContext context) => FAlertDialog(
    title: const Text('选择显示字段'),
    content: SizedBox(
      width: 460,
      child: _sources.isEmpty
          ? const Text('请先在“关注内容”中选择行情，或添加自定义 API。')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FDropdown<String>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '来自哪个内容？'),
                  items: [
                    for (final source in _sources.entries)
                      FDropdownItem(
                        value: source.key,
                        child: Text(
                          source.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _source = value;
                    _field = _fields.keys.firstOrNull;
                  }),
                ),
                const SizedBox(height: 14),
                FDropdown<String>(
                  key: ValueKey(_source),
                  initialValue: _field,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '显示什么？'),
                  items: [
                    for (final field in _fields.entries)
                      FDropdownItem(value: field.key, child: Text(field.value)),
                  ],
                  onChanged: (value) => setState(() => _field = value),
                ),
                const SizedBox(height: 14),
                FDropdown<String>(
                  initialValue: _format,
                  decoration: const InputDecoration(labelText: '数字格式'),
                  items: const [
                    FDropdownItem(value: '', child: Text('自动')),
                    FDropdownItem(value: '.2f', child: Text('2 位小数')),
                    FDropdownItem(value: '.4f', child: Text('4 位小数')),
                    FDropdownItem(value: '+.2f', child: Text('正负号 + 2 位小数')),
                    FDropdownItem(value: 'raw', child: Text('保留接口原值')),
                  ],
                  onChanged: (value) => setState(() => _format = value!),
                ),
              ],
            ),
    ),
    actions: [
      FTextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FFilledButton(
        onPressed: _source == null || _field == null
            ? null
            : () => Navigator.pop(
                context,
                DisplaySegment.field(
                  assetId: _source,
                  fieldId: _field,
                  format: _format,
                ),
              ),
        child: const Text('加入显示'),
      ),
    ],
  );
}
