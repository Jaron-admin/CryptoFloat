import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/display_formatter.dart';
import '../../domain/models.dart';
import 'fluent_controls.dart';

class SourceEditResult {
  const SourceEditResult(this.source, this.createdSecretKeys);
  final CustomApiSource source;
  final Set<String> createdSecretKeys;
}

class SourceEditor extends StatefulWidget {
  const SourceEditor({super.key, required this.controller, this.source});
  final AppController controller;
  final CustomApiSource? source;
  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  late final String _id;
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _interval;
  late List<CustomField> _fields;
  final List<_HeaderDraft> _headers = [];
  final Set<String> _createdKeys = {};
  Map<String, Object?> _preview = {};
  bool _busy = false;
  String? _error;
  bool _advanced = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _enabled = source?.enabled ?? true;
    _id = source?.id ?? 'api_${DateTime.now().microsecondsSinceEpoch}';
    _name = TextEditingController(text: source?.name ?? '');
    _url = TextEditingController(text: source?.url ?? '');
    _interval = TextEditingController(text: '${source?.refreshSeconds ?? 60}');
    _fields = [...?source?.fields];
    for (final header
        in source?.headers.entries ?? <MapEntry<String, String>>[]) {
      _headers.add(_HeaderDraft(header.key, header.value, false));
    }
    for (final header
        in source?.secretHeaderRefs.entries ?? <MapEntry<String, String>>[]) {
      _headers.add(_HeaderDraft(header.key, '', true, ref: header.value));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _interval.dispose();
    for (final header in _headers) {
      header.dispose();
    }
    super.dispose();
  }

  Future<CustomApiSource> _source() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (_name.text.trim().isEmpty) throw const FormatException('请为这个数据源起个名字。');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('请输入 HTTPS 数据接口地址，密钥请放在请求头中。');
    }
    final interval = int.tryParse(_interval.text);
    if (interval == null || interval < 15 || interval > 3600) {
      throw const FormatException('刷新间隔应在 15 到 3600 秒之间。');
    }
    final headers = <String, String>{};
    final refs = <String, String>{};
    final names = <String>{};
    for (final header in _headers) {
      final name = header.name.text.trim();
      if (name.isEmpty) continue;
      if (!names.add(name.toLowerCase())) {
        throw const FormatException('请求头名称重复，请保留一项。');
      }
      if (header.secret) {
        final value = header.value.text;
        if (value.isNotEmpty) {
          if (header.ref == null || !_createdKeys.contains(header.ref)) {
            header.ref =
                'secret_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
            _createdKeys.add(header.ref!);
          }
          await widget.controller.secrets.write(header.ref!, value);
        }
        if (header.ref == null) throw FormatException('请填写 $name 的密钥。');
        refs[name] = header.ref!;
      } else {
        headers[name] = header.value.text;
      }
    }
    return CustomApiSource(
      id: _id,
      name: _name.text.trim(),
      url: uri.toString(),
      refreshSeconds: interval,
      headers: headers,
      secretHeaderRefs: refs,
      fields: _fields,
      enabled: _enabled,
    );
  }

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final source = await _source();
      final preview = await widget.controller.data.previewSource(source);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_fields.isEmpty) throw const FormatException('请至少选择一个显示字段。');
      final source = await _source();
      if (mounted) {
        Navigator.pop(context, SourceEditResult(source, {..._createdKeys}));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    for (final key in _createdKeys) {
      try {
        await widget.controller.secrets.delete(key);
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editField({CustomField? field, String? path}) async {
    final chosenPath = path ?? field?.path ?? '';
    final label = TextEditingController(
      text:
          field?.label ??
          chosenPath.split('.').last.replaceAll(RegExp(r'\[\d+\]'), ''),
    );
    final unit = TextEditingController(text: field?.unit ?? '');
    final fieldPath = TextEditingController(text: chosenPath);
    final result = await f.showDialog<CustomField>(
      context: context,
      builder: (context) => FAlertDialog(
        title: Text(field == null ? '设置显示字段' : '编辑显示字段'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FTextField(
                controller: label,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '显示名称',
                  hintText: '例如：账户余额、室外温度',
                ),
              ),
              const SizedBox(height: 14),
              FTextField(
                controller: unit,
                decoration: const InputDecoration(
                  labelText: '单位（可选）',
                  hintText: '例如：USD、°C、人',
                ),
              ),
              const SizedBox(height: 14),
              FTextField(
                controller: fieldPath,
                readOnly: path != null,
                decoration: const InputDecoration(
                  labelText: '返回数据中的位置',
                  hintText: '例如：data.balance 或 items[0].price',
                ),
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
            onPressed: () {
              if (label.text.trim().isEmpty || fieldPath.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                CustomField(
                  id:
                      field?.id ??
                      'field_${DateTime.now().microsecondsSinceEpoch}',
                  label: label.text.trim(),
                  path: fieldPath.text.trim(),
                  unit: unit.text.trim(),
                ),
              );
            },
            child: const Text('加入显示'),
          ),
        ],
      ),
    );
    label.dispose();
    unit.dispose();
    fieldPath.dispose();
    if (result != null && mounted) {
      setState(() {
        final index = _fields.indexWhere((item) => item.id == result.id);
        if (index < 0) {
          _fields.add(result);
        } else {
          _fields[index] = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (_) {
          if (!_busy) _cancel();
          return null;
        },
      ),
    },
    child: FDialog(
      child: SizedBox(
        width: 780,
        height: max(160, min(800, MediaQuery.sizeOf(context).height - 64)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.source == null ? '添加自定义 API' : '编辑自定义 API',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FIconButton(
                    onPressed: _busy ? null : _cancel,
                    tooltip: '取消',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  FSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用这个数据源'),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  Text(
                    '连接数据源',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FTextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '数据源名称',
                      hintText: '例如：我的账户、天气',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FTextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'HTTPS 接口地址',
                      hintText: 'https://example.com/api/status',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FTextField(
                    controller: _interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '刷新间隔（秒）',
                      helperText: '15–3600 秒，请遵循接口的调用频率限制。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('请求头 / API 密钥（需要时填写）'),
                    subtitle: Text(
                      _headers.isEmpty
                          ? '免密钥接口可以跳过'
                          : '${_headers.length} 个请求头',
                    ),
                    children: [
                      for (final header in _headers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FTextField(
                                      controller: header.name,
                                      decoration: const InputDecoration(
                                        labelText: '请求头名称',
                                        hintText: 'Authorization',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FIconButton(
                                    onPressed: () => setState(() {
                                      _headers.remove(header);
                                      header.dispose();
                                    }),
                                    tooltip: '移除',
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FTextField(
                                controller: header.value,
                                obscureText: header.secret,
                                decoration: InputDecoration(
                                  labelText: header.secret ? '密钥内容' : '请求头值',
                                  hintText: header.ref != null
                                      ? '已保存，留空保留原值'
                                      : header.secret
                                      ? '例如：Bearer your-token'
                                      : 'application/json',
                                ),
                              ),
                              FCheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('作为密钥，由系统保护存储'),
                                value: header.secret,
                                onChanged: (value) =>
                                    setState(() => header.secret = value!),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FTextButton.icon(
                          onPressed: () => setState(
                            () => _headers.add(_HeaderDraft('', '', true)),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('添加请求头'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FFilledButton.icon(
                    onPressed: _busy ? null : _read,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: f.ProgressRing(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('读取返回字段'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    '显示字段',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_preview.isEmpty)
                    Text(
                      '读取成功后，点击某个返回值，为它起显示名称并填写单位。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_preview.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final entry in _preview.entries)
                            FListTile(
                              dense: true,
                              title: Text(
                                entry.key,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                formatValue(entry.value),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                _fields.any((field) => field.path == entry.key)
                                    ? Icons.check_circle_outline
                                    : Icons.add_circle_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onTap: () => _editField(
                                field: _fields
                                    .where((field) => field.path == entry.key)
                                    .firstOrNull,
                                path: entry.key,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    '已选择的显示字段',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final field in _fields)
                    FListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${field.label}${field.unit.isEmpty ? '' : ' · ${field.unit}'}',
                      ),
                      subtitle: Text(
                        field.path,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => _editField(field: field),
                      trailing: FIconButton(
                        onPressed: () => setState(() => _fields.remove(field)),
                        tooltip: '移除字段',
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  FExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: _advanced,
                    onExpansionChanged: (value) => _advanced = value,
                    title: const Text('高级：手动指定字段位置'),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FTextButton.icon(
                          onPressed: () => _editField(),
                          icon: const Icon(Icons.add),
                          label: const Text('添加字段位置'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                    onPressed: _busy ? null : _cancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FFilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(widget.source == null ? '添加' : '保存'),
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

class _HeaderDraft {
  _HeaderDraft(String name, String value, this.secret, {this.ref})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);
  final TextEditingController name;
  final TextEditingController value;
  bool secret;
  String? ref;
  void dispose() {
    name.dispose();
    value.dispose();
  }
}
