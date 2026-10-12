import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'fluent_controls.dart';
import '../../domain/template_presets.dart';

Future<AppConfig?> showTemplatePicker(
  BuildContext context, {
  required AppConfig config,
}) => f.showDialog<AppConfig>(
  context: context,
  builder: (_) => _TemplateDialog(config: config),
);

const _titles = {
  TemplateKind.weather: '城市天气',
  TemplateKind.exchangeRates: '参考汇率',
  TemplateKind.github: 'GitHub 仓库',
  TemplateKind.marketBar: '简洁行情条',
  TemplateKind.reminder: '文字提醒',
};
const _details = {
  TemplateKind.weather: '气温、体感温度和湿度；15 分钟刷新。由 Open-Meteo 提供，适合个人使用。',
  TemplateKind.exchangeRates: '美元兑人民币、欧元、USDT 的参考汇率；5 分钟刷新。',
  TemplateKind.github: '公开仓库的 Stars 和未解决议题与 PR 数量；10 分钟刷新。',
  TemplateKind.marketBar: '把关注列表的前 3 个行情组合成一行，跟随单位设置。',
  TemplateKind.reminder: '直接显示一段文字，不需要网络。也可以用显示行编辑器继续加入数据字段。',
};

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.config});
  final AppConfig config;
  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  TemplateKind _kind = TemplateKind.weather;
  String _city = '北京';
  String? _error;
  final _owner = TextEditingController(text: 'flutter');
  final _repo = TextEditingController(text: 'flutter');
  final _text = TextEditingController(text: '提醒：起来走走，喝杯水');
  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _text.dispose();
    super.dispose();
  }

  void _add() {
    try {
      final draft = appendTemplate(
        widget.config,
        _kind,
        city: _city,
        owner: _owner.text,
        repository: _repo.text,
        text: _text.text,
      );
      Navigator.pop(context, draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => FDialog(
    child: SizedBox(
      width: 560,
      height: max(160, min(480, MediaQuery.sizeOf(context).height - 48)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '添加实用模板',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                FIconButton(
                  tooltip: '关闭模板',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kind in TemplateKind.values)
                        FChoiceChip(
                          label: Text(_titles[kind]!),
                          selected: kind == _kind,
                          onSelected: (_) => setState(() {
                            _kind = kind;
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _details[_kind]!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == TemplateKind.weather)
                    FDropdown<String>(
                      initialValue: _city,
                      decoration: const InputDecoration(labelText: '城市'),
                      items: [
                        for (final city in weatherCities.keys)
                          FDropdownItem(value: city, child: Text(city)),
                      ],
                      onChanged: (value) => setState(() => _city = value!),
                    ),
                  if (_kind == TemplateKind.github) ...[
                    FTextField(
                      controller: _owner,
                      decoration: const InputDecoration(
                        labelText: '仓库拥有者',
                        hintText: '例如 flutter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FTextField(
                      controller: _repo,
                      decoration: const InputDecoration(
                        labelText: '仓库名称',
                        hintText: '例如 CryptoFloat',
                      ),
                    ),
                  ],
                  if (_kind == TemplateKind.reminder)
                    FTextField(
                      controller: _text,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '显示文字'),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const f.Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FTextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FFilledButton(onPressed: _add, child: const Text('加入显示')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
