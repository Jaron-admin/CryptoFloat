import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/l10n.dart';
import 'fluent_controls.dart';
import '../panel/display_row_view.dart';

Map<String, String> _builtinFields(AppLocalizations l10n) => {
  'symbol': l10n.editFieldSymbol,
  'name': l10n.editFieldLabel,
  'price': l10n.editFieldPrice,
  'currency': l10n.editFieldCurrency,
  'change': l10n.editFieldChange,
  'provider': l10n.editFieldProvider,
  'updatedAt': l10n.editFieldUpdatedAt,
};

String fieldLabel(
  DisplaySegment segment,
  AppConfig config,
  AppLocalizations l10n,
) {
  final asset = [
    ...config.customAssets,
    ...Asset.popular,
  ].where((asset) => asset.id == segment.assetId).firstOrNull;
  if (asset != null) {
    return '${localizedAssetName(asset, l10n)} · ${_builtinFields(l10n)[segment.fieldId] ?? segment.fieldId}';
  }
  final source = config.customSources
      .where((source) => 'custom:${source.id}' == segment.assetId)
      .firstOrNull;
  final field = source?.fields
      .where((field) => field.id == segment.fieldId)
      .firstOrNull;
  return '${source?.name ?? l10n.editSourceMissing} · ${field?.label ?? segment.fieldId}';
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
    final result = await showEditorDialog<String>(
      context: context,
      builder: (context) => FAlertDialog(
        title: Text(context.l10n.editDisplayText),
        content: SizedBox(
          width: 450,
          child: FTextField(
            controller: input,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.editWantedText,
              hintText: context.l10n.editWantedTextHint,
            ),
          ),
        ),
        actions: [
          FTextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.editCancel),
          ),
          FFilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: Text(context.l10n.editAddToDisplay),
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
    final result = await showDialog<DisplaySegment>(
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
                Expanded(
                  child: Text(
                    context.l10n.editComposeRow,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                FIconButton(
                  tooltip: context.l10n.editCloseEditor,
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
                  context.l10n.editComposeRowHelp,
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
                      label: Text(context.l10n.editAddText),
                    ),
                    FFilledButton.icon(
                      onPressed: _field,
                      icon: const Icon(Icons.add_chart),
                      label: Text(context.l10n.editAddDataField),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_segments.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(context.l10n.editEmptyRow)),
                  ),
                for (var i = 0; i < _segments.length; i++) _segmentCard(i),
                const SizedBox(height: 16),
                Text(
                  context.l10n.editDisplayPreview,
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FTextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.editCancel),
                ),
                const SizedBox(width: 10),
                FFilledButton(
                  onPressed: _segments.isEmpty
                      ? null
                      : () => Navigator.pop(context, _row),
                  child: Text(context.l10n.editSaveRow),
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
    child: Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 440;
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FIconButton(
                tooltip: context.l10n.editMoveLeft,
                onPressed: index == 0 ? null : () => _move(index, -1),
                icon: const Icon(Icons.arrow_back, size: 17),
              ),
              FIconButton(
                tooltip: context.l10n.editMoveRight,
                onPressed: index == _segments.length - 1
                    ? null
                    : () => _move(index, 1),
                icon: const Icon(Icons.arrow_forward, size: 17),
              ),
              FIconButton(
                tooltip: context.l10n.editRemove,
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
                      ? fieldLabel(
                          _segments[index],
                          widget.config,
                          context.l10n,
                        )
                      : _segments[index].text.isEmpty
                      ? context.l10n.editEmptyText
                      : _segments[index].text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: _segments[index].isField
                    ? Text(
                        context.l10n.editRowFormat(
                          _segments[index].format.isEmpty
                              ? context.l10n.editAutomatic
                              : _segments[index].format,
                        ),
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
  Map<String, String> get _sources => {
    for (final asset in widget.config.assets)
      asset.id:
          '${localizedAssetName(asset, context.l10n)} · ${asset.provider}',
    for (final source in widget.config.customSources)
      'custom:${source.id}': source.name,
  };

  bool _initialized = false;
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
      : _builtinFields(context.l10n);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
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
    title: Text(context.l10n.editSelectField),
    content: SizedBox(
      width: 460,
      child: _sources.isEmpty
          ? Text(context.l10n.editSelectSourceFirst)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FDropdown<String>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.editFieldSource,
                  ),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.editFieldSelection,
                  ),
                  items: [
                    for (final field in _fields.entries)
                      FDropdownItem(value: field.key, child: Text(field.value)),
                  ],
                  onChanged: (value) => setState(() => _field = value),
                ),
                const SizedBox(height: 14),
                FDropdown<String>(
                  initialValue: _format,
                  decoration: InputDecoration(
                    labelText: context.l10n.editNumberFormat,
                  ),
                  items: [
                    FDropdownItem(
                      value: '',
                      child: Text(context.l10n.editAutomatic),
                    ),
                    FDropdownItem(
                      value: '.2f',
                      child: Text(context.l10n.editDecimalsTwo),
                    ),
                    FDropdownItem(
                      value: '.4f',
                      child: Text(context.l10n.editDecimalsFour),
                    ),
                    FDropdownItem(
                      value: '+.2f',
                      child: Text(context.l10n.editDecimalsSigned),
                    ),
                    FDropdownItem(
                      value: 'raw',
                      child: Text(context.l10n.editRawValue),
                    ),
                  ],
                  onChanged: (value) => setState(() => _format = value!),
                ),
              ],
            ),
    ),
    actions: [
      FTextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.editCancel),
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
        child: Text(context.l10n.editAddToDisplay),
      ),
    ],
  );
}
