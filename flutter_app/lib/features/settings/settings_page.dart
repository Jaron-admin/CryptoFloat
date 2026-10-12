import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as f;

import 'fluent_controls.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../platform/system_fonts.dart';
import '../../platform/header_image_store.dart';
import '../panel/display_row_view.dart';
import 'source_editor.dart';
import 'row_editor.dart';
import 'template_picker.dart';
import 'settings_catalog.dart';
import 'settings_theme_picker.dart';

part 'settings_dialogs.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialSection = 0,
  });
  final AppController controller;
  final VoidCallback onClose;
  final int initialSection;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppConfig _draft;
  int _section = 0;
  String _search = '';
  String _kind = 'all';
  String _provider = 'all';
  int _assetPage = 0;
  bool _catalogRequested = false;
  bool _saving = false;
  bool _pickingImage = false;
  bool _closing = false;
  late final Future<bool> Function() _exitGuard;
  String? _error;
  final _scrollController = ScrollController();
  final _watchlistScrollController = ScrollController();
  final _settingsSearch = TextEditingController();
  final _assetSearch = TextEditingController();
  final Map<String, GlobalKey> _anchors = {};
  String _settingsQuery = '';
  String? _highlightedAnchor;
  bool _storageExpanded = false;
  List<String> _fonts = [
    'Segoe UI',
    'Microsoft YaHei',
    'Arial',
    'Consolas',
    'Noto Sans',
    'sans-serif',
  ];
  final Set<String> _createdSecrets = {};

  bool get _dirty {
    final draft = Map<String, Object?>.of(_draft.toJson())
      ..remove('windowBounds');
    final saved = Map<String, Object?>.of(widget.controller.config.toJson())
      ..remove('windowBounds');
    return encodeJson(draft) != encodeJson(saved);
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.config;
    _exitGuard = () => _requestLeave(exitApp: true);
    widget.controller.beforeExit = _exitGuard;
    _section = widget.initialSection.clamp(0, settingsCategories.length - 1);
    if (_section == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadCatalog();
        }
      });
    }
    widget.controller.host
        .getSystemFonts()
        .then((fonts) {
          if (mounted && fonts.isNotEmpty) setState(() => _fonts = fonts);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    if (widget.controller.beforeExit == _exitGuard) {
      widget.controller.beforeExit = null;
    }
    _scrollController.dispose();
    _watchlistScrollController.dispose();
    _settingsSearch.dispose();
    _assetSearch.dispose();
    super.dispose();
  }

  void _preview(AppConfig value) {
    setState(() => _draft = value);
    widget.controller.previewAppearance(value);
  }

  Future<void> _close() async {
    await _requestLeave(exitApp: false);
  }

  Future<bool> _requestLeave({required bool exitApp}) async {
    if (!mounted || _closing || _saving || _pickingImage) return false;
    // An open editor owns its temporary secrets until it returns a result.
    if (exitApp && ModalRoute.of(context)?.isCurrent == false) return false;
    setState(() => _closing = true);
    try {
      if (_dirty) {
        final action = await f.showDialog<String>(
          context: context,
          builder: (context) => FAlertDialog(
            title: const Text('有未保存的更改'),
            content: Text(exitApp ? '退出前保存更改，或放弃这次更改。' : '保存后应用到悬浮窗，或放弃这次更改。'),
            actions: [
              FTextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('继续编辑'),
              ),
              FTextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('放弃更改'),
              ),
              FFilledButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: Text(exitApp ? '保存并退出' : '保存并返回'),
              ),
            ],
          ),
        );
        if (!mounted) return false;
        if (action == 'save') return await _save(closeSettings: !exitApp);
        if (action != 'discard') return false;
      }
      await _clearUncommittedSecrets();
      if (!mounted) return false;
      widget.controller.clearAppearancePreview();
      if (exitApp) {
        setState(() => _draft = widget.controller.config);
      } else {
        widget.onClose();
      }
      return true;
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _clearUncommittedSecrets() async {
    final committed = widget.controller.config.customSources
        .expand((source) => source.secretHeaderRefs.values)
        .toSet();
    for (final key in _createdSecrets.difference(committed)) {
      try {
        await widget.controller.secrets.delete(key);
      } catch (_) {}
    }
    _createdSecrets.clear();
  }

  Future<bool> _save({bool closeSettings = true}) async {
    if (_saving || _pickingImage) return false;
    final draftToSave = _draft;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final oldRefs = widget.controller.config.customSources
          .expand((source) => source.secretHeaderRefs.values)
          .toSet();
      await widget.controller.apply(draftToSave);
      final newRefs = draftToSave.customSources
          .expand((source) => source.secretHeaderRefs.values)
          .toSet();
      for (final key in {...oldRefs, ..._createdSecrets}.difference(newRefs)) {
        try {
          await widget.controller.secrets.delete(key);
        } catch (_) {}
      }
      _createdSecrets.clear();
      if (mounted && closeSettings) {
        widget.onClose();
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = '保存失败：$error');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: DefaultTextStyle(
      style: f.FluentTheme.of(context).typography.body!,
      child: ColoredBox(
        color: f.FluentTheme.of(context).scaffoldBackgroundColor,
        child: AbsorbPointer(
          absorbing: _saving || _closing,
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: f.InfoBar(
                    title: const Text('未能完成操作'),
                    content: Text(_error!),
                    severity: f.InfoBarSeverity.error,
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final body = _settingsQuery.trim().isEmpty
                        ? _sectionBody()
                        : _searchResults();
                    return f.NavigationView(
                      titleBar: f.TitleBar(
                        height: 38,
                        isBackButtonVisible: true,
                        onDragStarted: () => widget.controller.host.beginDrag(),
                        backButton: FIconButton(
                          onPressed: _saving || _pickingImage || _closing
                              ? null
                              : _close,
                          tooltip: '返回悬浮窗',
                          icon: const Icon(f.FluentIcons.back, size: 16),
                        ),
                        title: const Text(
                          'CryptoFloat 设置',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        captionControls: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: FFilledButton(
                            onPressed:
                                _saving || _pickingImage || _closing || !_dirty
                                ? null
                                : _save,
                            child: Text(_saving ? '保存中…' : '保存并返回'),
                          ),
                        ),
                      ),
                      pane: f.NavigationPane(
                        acrylicDisabled: true,
                        selected: _section,
                        onChanged: (index) => _selectSection(index),
                        displayMode: constraints.maxWidth >= 680
                            ? f.PaneDisplayMode.expanded
                            : f.PaneDisplayMode.minimal,
                        size: const f.NavigationPaneSize(openWidth: 196),
                        autoSuggestBox: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _searchField(),
                        ),
                        items: [
                          for (var i = 0; i < settingsCategories.length; i++)
                            f.PaneItem(
                              icon: Icon(settingsCategories[i].icon, size: 18),
                              title: Text(settingsCategories[i].title),
                              body: i == _section
                                  ? body
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: f.FluentTheme.of(context)
                          .resources
                          .dividerStrokeColorDefault,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _dirty ? f.FluentIcons.edit : f.FluentIcons.check_mark,
                      size: 12,
                      color: f.FluentTheme.of(context)
                          .resources
                          .textFillColorSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dirty ? '未保存' : '已保存',
                        style: f.FluentTheme.of(context).typography.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _searchField() => FTextField(
    controller: _settingsSearch,
    decoration: InputDecoration(
      hintText: '搜索设置',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      prefixIcon: const Icon(Icons.search_rounded, size: 19),
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      suffixIcon: _settingsQuery.isEmpty
          ? null
          : FIconButton(
              tooltip: '清除搜索',
              icon: const Icon(Icons.close_rounded, size: 17),
              onPressed: () {
                _settingsSearch.clear();
                setState(() => _settingsQuery = '');
              },
            ),
    ),
    onChanged: (value) => setState(() => _settingsQuery = value),
  );

  Widget _sectionBody() => switch (_section) {
    0 => _assets(),
    1 => _sources(),
    2 => _rows(),
    3 => _appearance(),
    4 => _page([
      _intro('单位与换算', '选择行情货币和单位标签；自定义倍率可用于其他数值。'),
      _anchor('units', _unitOptions()),
    ]),
    _ => _window(),
  };

  void _selectSection(int section, {String? anchor}) {
    FocusManager.instance.primaryFocus?.unfocus();
    _settingsSearch.clear();
    setState(() {
      _section = section;
      _settingsQuery = '';
      _highlightedAnchor = anchor;
      if (anchor == 'storage') _storageExpanded = true;
    });
    if (section == 0) _loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      final target = anchor == null ? null : _anchors[anchor]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 0.08);
      }
    });
  }

  Widget _searchResults() {
    final matches = settingsLocations
        .where((entry) => entry.matches(_settingsQuery))
        .toList();
    return _page([
      _intro('搜索设置', '${matches.length} 项结果'),
      if (matches.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('没有匹配的设置，试试“字体”“单位”或“置顶”。'),
        ),
      for (final entry in matches)
        _card(
          FListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(settingsCategories[entry.section].icon, size: 20),
            title: Text(entry.title),
            subtitle: Text(settingsCategories[entry.section].title),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => _selectSection(entry.section, anchor: entry.anchor),
          ),
        ),
    ], includeStorage: false);
  }

  Widget _anchor(String id, Widget child) => Container(
    key: _anchors.putIfAbsent(id, GlobalKey.new),
    decoration: BoxDecoration(
      border: _highlightedAnchor == id
          ? Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            )
          : null,
    ),
    child: child,
  );

  Widget _page(List<Widget> children, {bool includeStorage = true}) =>
      Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  if (includeStorage) ...[
                    const SizedBox(height: 18),
                    _anchor('storage', _storage()),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _storage() => FExpansionTile(
    key: ValueKey('storage-$_section-$_storageExpanded'),
    initiallyExpanded: _storageExpanded,
    onExpansionChanged: (value) => _storageExpanded = value,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    title: const Text('导入与数据位置', style: TextStyle(fontSize: 12)),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FTextButton.icon(
          onPressed: _saving ? null : _importLegacy,
          icon: const Icon(Icons.file_download_outlined, size: 17),
          label: const Text('导入旧版设置副本'),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          '设置文件：${widget.controller.store.configPath}',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    ],
  );

  Widget _intro(String title, String description) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _card(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: f.Card(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: child,
      ),
    ),
  );
  Widget _assets() {
    final directory = widget.controller.catalog;
    final catalog = {
      for (final asset in [
        ...directory.assets,
        ...Asset.popular,
        ..._draft.customAssets,
      ])
        asset.id: asset,
    };
    final terms = _search.toLowerCase().trim().split(RegExp(r'\s+'));
    final selectedOrder = {
      for (var i = 0; i < _draft.selectedAssetIds.length; i++)
        _draft.selectedAssetIds[i]: i,
    };
    final popularOrder = {
      for (var i = 0; i < Asset.popular.length; i++) Asset.popular[i].id: i,
    };
    int rank(Asset asset) =>
        selectedOrder[asset.id] ??
        (selectedOrder.length +
            (popularOrder[asset.id] ?? Asset.popular.length));
    final filtered =
        catalog.values
            .where(
              (asset) =>
                  (_kind == 'all' ||
                      (_kind == 'crypto'
                          ? asset.kind == MarketKind.crypto
                          : asset.kind == MarketKind.equity)) &&
                  (_provider == 'all' || asset.provider == _provider) &&
                  terms.every(
                    '${asset.name} ${asset.symbol} ${asset.symbol.replaceAll('-', ' ')} ${asset.provider} ${asset.currency}'
                        .toLowerCase()
                        .contains,
                  ),
            )
            .toList()
          ..sort((a, b) {
            final priority = rank(a).compareTo(rank(b));
            return priority == 0 ? a.id.compareTo(b.id) : priority;
          });
    const pageSize = 100;
    final pageCount = ((filtered.length + pageSize - 1) ~/ pageSize).clamp(
      1,
      999999,
    );
    final currentPage = _assetPage.clamp(0, pageCount - 1);
    final page = filtered.skip(currentPage * pageSize).take(pageSize);
    return _page([
      _intro('关注行情', '管理关注列表，搜索更多币种、股票与 ETF。'),
      _anchor('asset-order', _watchlistOrder()),
      const SizedBox(height: 18),
      _anchor(
        'assets',
        const Text(
          '添加行情',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 10),
      FTextField(
        controller: _assetSearch,
        decoration: const InputDecoration(
          labelText: '搜索名称、代码或数据源',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) => setState(() {
          _search = value;
          _assetPage = 0;
        }),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final entry in const {
            'all': '全部',
            'crypto': '加密货币',
            'equity': '股票 / ETF',
          }.entries)
            FChoiceChip(
              label: Text(entry.value),
              selected: _kind == entry.key,
              onSelected: (_) => setState(() {
                _kind = entry.key;
                _provider = 'all';
                _assetPage = 0;
              }),
            ),
          SizedBox(
            width: 142,
            child: FDropdown<String>(
              key: ValueKey(_provider),
              initialValue: _provider,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '数据源'),
              items: const [
                FDropdownItem(value: 'all', child: Text('全部来源')),
                FDropdownItem(value: 'OKX', child: Text('OKX')),
                FDropdownItem(value: 'BINANCE', child: Text('Binance')),
                FDropdownItem(value: 'KUCOIN', child: Text('KuCoin')),
                FDropdownItem(value: 'YAHOO', child: Text('Yahoo 财经')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _provider = value;
                  if (value != 'all') {
                    _kind = value == 'YAHOO' ? 'equity' : 'crypto';
                  }
                  _assetPage = 0;
                });
              },
            ),
          ),
          FButton.icon(
            onPressed: _addAsset,
            icon: const Icon(Icons.add),
            label: const Text('添加代码'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '已选 ${_draft.selectedAssetIds.length} 项 · 目录 ${catalog.length} 项 · 匹配 ${filtered.length} 项',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          FTextButton.icon(
            onPressed: directory.loading
                ? null
                : () => _loadCatalog(force: true),
            icon: directory.loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: f.ProgressRing(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(directory.loading ? '正在更新目录' : '刷新目录'),
          ),
        ],
      ),
      if (directory.errors.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${directory.errors.keys.join('、')} 目录暂未更新，仍可选择已有项目。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      for (final asset in page)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: f.Card(
            child: FCheckboxListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -1),
              value: _draft.selectedAssetIds.contains(asset.id),
              title: Text(
                asset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${asset.symbol}  ·  ${asset.provider}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onChanged: (value) => _toggleAsset(asset, value == true),
            ),
          ),
        ),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('没有找到这个代码，可以用“添加代码”手动加入。'),
        ),
      if (pageCount > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FIconButton(
                tooltip: '上一页',
                onPressed: currentPage == 0
                    ? null
                    : () => _changeAssetPage(currentPage - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '第 ${currentPage + 1} / $pageCount 页 · 每页 $pageSize 项',
                style: const TextStyle(fontSize: 12),
              ),
              FIconButton(
                tooltip: '下一页',
                onPressed: currentPage == pageCount - 1
                    ? null
                    : () => _changeAssetPage(currentPage + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _watchlistOrder() {
    final assets = _draft.assets;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '已关注 · ${assets.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('从下方目录添加行情。'),
            )
          else
            SizedBox(
              height: (assets.length * 60.0).clamp(60.0, 300.0),
              child: f.Scrollbar(
                controller: _watchlistScrollController,
                thumbVisibility: true,
                child: ReorderableListView.builder(
                  scrollController: _watchlistScrollController,
                  primary: false,
                  itemExtent: 60,
                  buildDefaultDragHandles: false,
                  itemCount: assets.length,
                  onReorderItem: _reorderAsset,
                  proxyDecorator: (child, index, animation) => Material(
                    color: f.FluentTheme.of(context).cardColor,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(4),
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final asset = assets[i];
                    return Container(
                      key: ValueKey('watch-order-${asset.id}'),
                      decoration: BoxDecoration(
                        border: i == assets.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: f.FluentTheme.of(context)
                                      .resources
                                      .dividerStrokeColorDefault,
                                ),
                              ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: f.Tooltip(
                                  message: '拖动排序',
                                  child: Semantics(
                                    label: '拖动 ${asset.name} 排序',
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        f.FluentIcons.gripper_dots_vertical,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asset.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${asset.symbol} · ${asset.provider}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: f.FluentTheme.of(context)
                                        .typography
                                        .caption,
                                  ),
                                ],
                              ),
                            ),
                            FIconButton(
                              tooltip: '上移 ${asset.name}',
                              icon: const Icon(f.FluentIcons.up, size: 14),
                              onPressed: i == 0
                                  ? null
                                  : () => _moveAsset(i, -1),
                            ),
                            FIconButton(
                              tooltip: '下移 ${asset.name}',
                              icon: const Icon(f.FluentIcons.down, size: 14),
                              onPressed: i == assets.length - 1
                                  ? null
                                  : () => _moveAsset(i, 1),
                            ),
                            FIconButton(
                              tooltip: '取消关注 ${asset.name}',
                              icon: const Icon(f.FluentIcons.cancel, size: 12),
                              onPressed: () => _toggleAsset(asset, false),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _reorderAsset(int oldIndex, int newIndex) {
    final visible = _draft.assets.map((asset) => asset.id).toList();
    if (newIndex == oldIndex) return;
    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);
    // Keep any temporarily unavailable IDs in their slots.
    final visibleIds = visible.toSet();
    var index = 0;
    final ordered = [
      for (final id in _draft.selectedAssetIds)
        visibleIds.contains(id) ? visible[index++] : id,
    ];
    setState(() => _draft = _draft.copyWith(selectedAssetIds: ordered));
  }

  void _loadCatalog({bool force = false}) {
    if (_catalogRequested && !force) return;
    _catalogRequested = true;
    unawaited(
      widget.controller.catalog.refresh(force: force).catchError((
        Object error,
      ) {
        if (mounted) setState(() => _error = '目录更新失败，请稍后重试。');
      }),
    );
  }

  void _toggleAsset(Asset asset, bool selected) {
    setState(
      () => _draft = _draft.copyWith(
        customAssets: selected
            ? [
                ..._draft.customAssets.where((item) => item.id != asset.id),
                asset,
              ]
            : _draft.customAssets,
        selectedAssetIds: selected
            ? {..._draft.selectedAssetIds, asset.id}.toList()
            : _draft.selectedAssetIds.where((id) => id != asset.id).toList(),
      ),
    );
  }

  void _changeAssetPage(int page) {
    setState(() => _assetPage = page);
    _scrollController.jumpTo(0);
  }

  void _moveAsset(int index, int direction) {
    final ids = [..._draft.selectedAssetIds];
    final id = _draft.assets[index].id;
    final actual = ids.indexOf(id);
    final otherId = _draft.assets[index + direction].id;
    final other = ids.indexOf(otherId);
    ids[actual] = otherId;
    ids[other] = id;
    setState(() => _draft = _draft.copyWith(selectedAssetIds: ids));
  }

  Future<void> _addAsset() async {
    final asset = await f.showDialog<Asset>(
      context: context,
      builder: (context) => const _AssetDialog(),
    );
    if (asset == null || !mounted) return;
    setState(
      () => _draft = _draft.copyWith(
        customAssets: [
          ..._draft.customAssets.where((item) => item.id != asset.id),
          asset,
        ],
        selectedAssetIds: {..._draft.selectedAssetIds, asset.id}.toList(),
      ),
    );
  }

  Future<void> _importLegacy() async {
    final input = TextEditingController();
    final path = await f.showDialog<String>(
      context: context,
      builder: (context) => FAlertDialog(
        title: const Text('导入旧版设置副本'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将行情选择和可兼容的布局读入当前草稿；点击保存后应用。'),
              const SizedBox(height: 16),
              FTextField(
                controller: input,
                decoration: const InputDecoration(
                  labelText: '旧版配置文件位置',
                  hintText: '选择旧版 crypto_config.json 的完整路径',
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
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('读取'),
          ),
        ],
      ),
    );
    input.dispose();
    if (path == null || !mounted) return;
    try {
      final imported = await widget.controller.store.importLegacy(path);
      if (mounted) _preview(imported);
    } catch (error) {
      if (mounted) setState(() => _error = '导入失败：$error');
    }
  }

  Widget _sources() => _page([
    _anchor('sources', _intro('自定义内容', '连接数据接口，选择需要显示的字段。')),
    FFilledButton.icon(
      onPressed: () => _editSource(null),
      icon: const Icon(Icons.add),
      label: const Text('添加自定义 API'),
    ),
    const SizedBox(height: 20),
    if (_draft.customSources.isEmpty)
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加只需三步',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. 粘贴数据接口地址\n2. 点击“读取返回字段”\n3. 勾选字段，为它起名并填写单位',
              style: TextStyle(height: 1.8),
            ),
            const SizedBox(height: 12),
            Text(
              '支持免密钥接口和请求头密钥。密钥保存在系统保护的存储中。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    for (final source in _draft.customSources)
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    source.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FIconButton(
                  onPressed: () => _editSource(source),
                  tooltip: '编辑',
                  icon: const Icon(Icons.edit_outlined),
                ),
                FIconButton(
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(
                      customSources: _draft.customSources
                          .where((item) => item.id != source.id)
                          .toList(),
                    ),
                  ),
                  tooltip: '移除',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              source.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in source.fields)
                  _SettingTag(
                    label: Text(
                      '${field.label}${field.unit.isEmpty ? '' : ' · ${field.unit}'}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${source.enabled ? '已启用' : '已停用'} · 每 ${source.refreshSeconds} 秒刷新 · ${source.fields.length} 个显示字段',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
  ]);

  Future<void> _editSource(CustomApiSource? source) async {
    final result = await f.showDialog<SourceEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          SourceEditor(controller: widget.controller, source: source),
    );
    if (result == null || !mounted) return;
    _createdSecrets.addAll(result.createdSecretKeys);
    setState(
      () => _draft = _draft.copyWith(
        customSources: [
          ..._draft.customSources.where((item) => item.id != result.source.id),
          result.source,
        ],
      ),
    );
  }

  Widget _rows() => _page([
    _intro('显示布局', '组合行情字段与文字，创建自己的显示布局。'),
    _anchor(
      'default-rows',
      _card(
        FSwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('显示默认行情'),
          subtitle: const Text('显示已关注代码的名称、价格、单位和涨跌幅；关闭后保留自由显示行。'),
          value: _draft.showDefaultRows,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(showDefaultRows: value)),
        ),
      ),
    ),
    _anchor(
      'custom-rows',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FFilledButton.icon(
            onPressed: () => _editRow(null),
            icon: const Icon(Icons.add),
            label: const Text('添加自由显示行'),
          ),
          FButton.icon(
            onPressed: _addTemplate,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('添加实用模板'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    if (_draft.showDefaultRows)
      _card(
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('默认行情已开启，添加自由显示行后仍会保留。')),
          ],
        ),
      ),
    for (var i = 0; i < _draft.displayRows.length; i++)
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${i + 1} 行',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FIconButton(
                  tooltip: '上移',
                  onPressed: i == 0 ? null : () => _moveRow(i, -1),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                FIconButton(
                  tooltip: '下移',
                  onPressed: i == _draft.displayRows.length - 1
                      ? null
                      : () => _moveRow(i, 1),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
                FIconButton(
                  tooltip: '编辑',
                  onPressed: () => _editRow(_draft.displayRows[i]),
                  icon: const Icon(Icons.edit_outlined),
                ),
                FIconButton(
                  tooltip: '删除',
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(
                      displayRows: _draft.displayRows
                          .where((row) => row.id != _draft.displayRows[i].id)
                          .toList(),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final segment in _draft.displayRows[i].segments)
                  _SettingTag(
                    avatar: Icon(
                      segment.isField ? Icons.data_object : Icons.text_fields,
                      size: 16,
                    ),
                    label: Text(
                      segment.isField
                          ? fieldLabel(segment, _draft)
                          : segment.text,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DisplayRowView(
                row: _draft.displayRows[i],
                config: _draft,
                quotes: widget.controller.data.quotes,
                rates: widget.controller.data.exchangeRates,
                showFreshness: false,
              ),
            ),
          ],
        ),
      ),
  ]);

  void _moveRow(int index, int direction) {
    final rows = [..._draft.displayRows];
    final row = rows.removeAt(index);
    rows.insert(index + direction, row);
    setState(() => _draft = _draft.copyWith(displayRows: rows));
  }

  Future<void> _editRow(DisplayRow? row) async {
    final result = await f.showDialog<DisplayRow>(
      context: context,
      builder: (context) => RowEditor(
        config: _draft,
        quotes: widget.controller.data.quotes,
        rates: widget.controller.data.exchangeRates,
        row: row,
      ),
    );
    if (result == null || !mounted) return;
    final rows = [..._draft.displayRows];
    final index = rows.indexWhere((item) => item.id == result.id);
    if (index < 0) {
      rows.add(result);
    } else {
      rows[index] = result;
    }
    setState(() => _draft = _draft.copyWith(displayRows: rows));
  }

  Future<void> _addTemplate() async {
    final result = await showTemplatePicker(context, config: _draft);
    if (result != null && mounted) _preview(result);
  }

  Widget _appearance() => _page([
    _intro('外观', '主题、悬浮窗透明度、字体与标题。'),
    _anchor(
      'opacity',
      _card(
        _slider(
          '悬浮窗透明度',
          1 - _draft.opacity,
          0,
          0.6,
          '${((1 - _draft.opacity) * 100).round()}%',
          (value) => _draft = _draft.copyWith(opacity: 1 - value),
        ),
      ),
    ),
    _anchor(
      'themes',
      _card(SettingsThemePicker(config: _draft, onChanged: _preview)),
    ),
    _anchor(
      'fonts',
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingRow(
              title: '文字字体',
              description: _draft.fontFamily,
              controlWidth: 116,
              control: FButton(
                onPressed: () => _pickFont(false),
                child: const Text('选择系统字体'),
              ),
            ),
            const Divider(height: 1),
            SettingRow(
              title: '数字字体',
              description: _draft.numberFontFamily,
              controlWidth: 116,
              control: FButton(
                onPressed: () => _pickFont(true),
                child: const Text('选择系统字体'),
              ),
            ),
            const Divider(height: 1),
            _anchor(
              'font-size',
              Column(
                children: [
                  const SizedBox(height: 12),
                  _slider(
                    '字号',
                    _draft.fontSize,
                    10,
                    32,
                    '${_draft.fontSize.round()} px',
                    (value) => _preview(_draft.copyWith(fontSize: value)),
                  ),
                  _slider(
                    '行间距',
                    _draft.rowSpacing,
                    0,
                    24,
                    '${_draft.rowSpacing.round()} px',
                    (value) => _preview(_draft.copyWith(rowSpacing: value)),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '中文预览：比特币 · 价格与涨跌',
                    style: TextStyle(
                      fontFamily: SystemFonts.family(_draft.fontFamily),
                      fontSize: _draft.fontSize,
                    ),
                  ),
                  SizedBox(height: _draft.rowSpacing.clamp(4, 12)),
                  Text(
                    'AaBb · BTC / USDT',
                    style: TextStyle(
                      fontFamily: SystemFonts.family(_draft.fontFamily),
                      fontSize: _draft.fontSize,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '83,342.30  +0.37%  0123456789',
                    style: TextStyle(
                      fontFamily: SystemFonts.family(_draft.numberFontFamily),
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: _draft.fontSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
    _anchor('header', _headerOptions()),
  ]);

  Widget _window() => _page([
    _intro('窗口与托盘', '置顶、移动和系统托盘。'),
    _anchor(
      'window',
      _card(
        Column(
          children: [
            SettingRow(
              title: '保持在其他窗口上方',
              controlWidth: 52,
              control: FSwitch(
                value: _draft.alwaysOnTop,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(alwaysOnTop: value),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    _anchor(
      'tray',
      _card(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingRow(
              title: '隐藏悬浮窗',
              description: '双击悬浮窗空白处或标题，隐藏到系统托盘。',
              controlWidth: 28,
              control: Icon(Icons.touch_app_outlined, size: 20),
            ),
            Divider(height: 1),
            SettingRow(
              title: '从托盘恢复',
              description: '单击托盘图标恢复悬浮窗，并置于其他窗口上方。',
              controlWidth: 28,
              control: Icon(Icons.open_in_new_rounded, size: 20),
            ),
          ],
        ),
      ),
    ),
  ]);
  static const _headerIcons = {
    'chart': '行情图',
    'bitcoin': '比特币',
    'star': '星标',
    'bolt': '闪电',
    'heart': '爱心',
  };

  IconData? _headerIconData(String id) => switch (id) {
    'chart' => Icons.show_chart_rounded,
    'bitcoin' => Icons.currency_bitcoin,
    'star' => Icons.star_rounded,
    'bolt' => Icons.bolt_rounded,
    'heart' => Icons.favorite_rounded,
    _ => null,
  };

  Widget _headerIconPreview({double size = 24}) {
    final icon = _headerIconData(_draft.headerIcon);
    final fallback = icon == null
        ? Text(_draft.headerIcon, maxLines: 1, style: TextStyle(fontSize: size))
        : Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: _draft.headerImagePath.isEmpty
          ? FittedBox(child: fallback)
          : Image.file(
              File(_draft.headerImagePath),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  Widget _headerOptions() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _headerIconPreview(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _draft.headerName.isEmpty ? '标题预览' : _draft.headerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '图标预览',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SettingRow(
          title: '显示标题名称',
          controlWidth: 52,
          control: FSwitch(
            value: _draft.showHeaderName,
            onChanged: (value) =>
                _preview(_draft.copyWith(showHeaderName: value)),
          ),
        ),
        SettingRow(
          title: '标题名称',
          controlWidth: 220,
          control: FTextFormField(
            key: const ValueKey('header-name'),
            initialValue: _draft.headerName,
            maxLength: 80,
            decoration: const InputDecoration(isDense: true, counterText: ''),
            onChanged: (value) => _preview(_draft.copyWith(headerName: value)),
          ),
        ),
        const Divider(height: 1),
        SettingRow(
          title: '显示标题图标',
          controlWidth: 52,
          control: FSwitch(
            value: _draft.showHeaderIcon,
            onChanged: (value) =>
                _preview(_draft.copyWith(showHeaderIcon: value)),
          ),
        ),
        SettingRow(
          title: '图标样式',
          controlWidth: 220,
          control: FDropdown<String>(
            key: ValueKey('header-icon-${_draft.headerIcon}'),
            initialValue: _headerIcons.containsKey(_draft.headerIcon)
                ? _draft.headerIcon
                : 'emoji',
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final entry in _headerIcons.entries)
                FDropdownItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(_headerIconData(entry.key), size: 19),
                      const SizedBox(width: 9),
                      Text(entry.value),
                    ],
                  ),
                ),
              const FDropdownItem(
                value: 'emoji',
                child: Row(
                  children: [
                    Icon(Icons.emoji_emotions_outlined, size: 19),
                    SizedBox(width: 9),
                    Text('自定义表情'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _preview(
                _draft.copyWith(
                  headerIcon: value == 'emoji' ? '⭐' : value,
                  headerImagePath: '',
                ),
              );
            },
          ),
        ),
        if (!_headerIcons.containsKey(_draft.headerIcon)) ...[
          const SizedBox(height: 8),
          FTextFormField(
            key: const ValueKey('header-emoji'),
            initialValue: _draft.headerIcon,
            decoration: const InputDecoration(
              labelText: '输入表情或字符',
              hintText: '例如 🌙',
            ),
            onChanged: (value) =>
                _preview(_draft.copyWith(headerIcon: value.trim())),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_draft.headerImagePath.isNotEmpty)
              Image.file(
                File(_draft.headerImagePath),
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Tooltip(
                  message: '图片无法显示，请重新选择',
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            FButton.icon(
              onPressed: _saving || _pickingImage ? null : _pickHeaderImage,
              icon: _pickingImage
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: f.ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: const Text('选择图片图标'),
            ),
            if (_draft.headerImagePath.isNotEmpty)
              FTextButton(
                onPressed: () => _preview(_draft.copyWith(headerImagePath: '')),
                child: const Text('清除图片图标'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '选择不超过 1 MB 的图片；图片图标会优先显示。',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Future<void> _pickHeaderImage() async {
    setState(() => _pickingImage = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '图片',
            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      final path = await HeaderImageStore(store: widget.controller.store)
          .importFile(file);
      if (mounted) _preview(_draft.copyWith(headerImagePath: path));
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : '图片未能导入，请重新选择。';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Widget _unitOptions() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingRow(
          title: '单位标签',
          description: '选择完整名称、简写或自己的标签',
          control: FDropdown<String>(
            key: const ValueKey('unit-label-mode'),
            initialValue: _draft.unitLabelMode,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: const [
              FDropdownItem(value: 'full', child: Text('完整')),
              FDropdownItem(value: 'compact', child: Text('简写')),
              FDropdownItem(value: 'custom', child: Text('自定义')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _draft = _draft.copyWith(unitLabelMode: value));
              }
            },
          ),
        ),
        const Divider(height: 1),
        SettingRow(
          title: '行情显示货币',
          description: '行情价格按可用汇率换算',
          control: FDropdown<String>(
            key: const ValueKey('display-currency'),
            initialValue: _draft.displayCurrency,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const FDropdownItem(value: '', child: Text('保留原币')),
              for (final currency in {
                'USD',
                'CNY',
                'EUR',
                'GBP',
                'HKD',
                'JPY',
                'USDT',
                'USDC',
                if (_draft.displayCurrency.isNotEmpty) _draft.displayCurrency,
              })
                FDropdownItem(value: currency, child: Text(currency)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(
                  () => _draft = _draft.copyWith(displayCurrency: value),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '行情货币按可用汇率换算；汇率不可用时保留原币并显示提示。自定义倍率用于其他单位。',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (_draft.unitLabelMode == 'custom') ...[
          const SizedBox(height: 10),
          for (final entry in _draft.unitLabels.entries)
            FListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${entry.key} → ${entry.value}'),
              trailing: FIconButton(
                tooltip: '删除单位标签',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  final labels = Map<String, String>.of(_draft.unitLabels)
                    ..remove(entry.key);
                  _draft = _draft.copyWith(unitLabels: labels);
                }),
              ),
            ),
          FButton.icon(
            onPressed: _addUnitLabel,
            icon: const Icon(Icons.add),
            label: const Text('添加单位标签'),
          ),
        ],
        const SizedBox(height: 10),
        for (var i = 0; i < _draft.unitRules.length; i++)
          FListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_draft.unitRules[i].sourceUnit} → ${_draft.unitRules[i].targetUnit}',
            ),
            subtitle: Text('数值 × ${_draft.unitRules[i].multiplier}'),
            trailing: FIconButton(
              tooltip: '删除倍率规则',
              icon: const Icon(Icons.close),
              onPressed: () => setState(
                () => _draft = _draft.copyWith(
                  unitRules: [
                    for (var j = 0; j < _draft.unitRules.length; j++)
                      if (j != i) _draft.unitRules[j],
                  ],
                ),
              ),
            ),
          ),
        FButton.icon(
          onPressed: _addUnitRule,
          icon: const Icon(Icons.add),
          label: const Text('添加倍率规则'),
        ),
      ],
    ),
  );

  Future<void> _addUnitLabel() async {
    var source = '', label = '';
    String? error;
    final result = await f.showDialog<MapEntry<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => FAlertDialog(
          scrollable: true,
          title: const Text('自定义单位标签'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FTextFormField(
                  key: const ValueKey('label-source'),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '原单位',
                    hintText: '例如 USDT',
                  ),
                  onChanged: (value) => source = value.trim(),
                ),
                const SizedBox(height: 10),
                FTextFormField(
                  key: const ValueKey('label-text'),
                  decoration: const InputDecoration(
                    labelText: '显示标签',
                    hintText: '例如 U',
                  ),
                  onChanged: (value) => label = value.trim(),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                if (source.isEmpty || label.isEmpty) {
                  refresh(() => error = '请填写原单位和显示标签。');
                  return;
                }
                Navigator.pop(context, MapEntry(source, label));
              },
              child: const Text('保存标签'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => _draft = _draft.copyWith(
          unitLabels: {
            for (final entry in _draft.unitLabels.entries)
              if (_unitKey(entry.key) != _unitKey(result.key))
                entry.key: entry.value,
            result.key: result.value,
          },
        ),
      );
    }
  }

  Future<void> _addUnitRule() async {
    var source = '', target = '', multiplier = '';
    String? error;
    final result = await f.showDialog<UnitConversionRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => FAlertDialog(
          scrollable: true,
          title: const Text('自定义倍率换算'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FTextFormField(
                  key: const ValueKey('rule-source'),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '原单位',
                    hintText: '例如 oz',
                  ),
                  onChanged: (value) => source = value.trim(),
                ),
                const SizedBox(height: 10),
                FTextFormField(
                  key: const ValueKey('rule-target'),
                  decoration: const InputDecoration(
                    labelText: '目标单位',
                    hintText: '例如 g',
                  ),
                  onChanged: (value) => target = value.trim(),
                ),
                const SizedBox(height: 10),
                FTextFormField(
                  key: const ValueKey('rule-multiplier'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '倍率',
                    hintText: '例如 28.3495',
                  ),
                  onChanged: (value) => multiplier = value.trim(),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                final number = double.tryParse(multiplier);
                if (source.isEmpty ||
                    target.isEmpty ||
                    number == null ||
                    !number.isFinite ||
                    number <= 0) {
                  refresh(() => error = '请填写两个单位和大于 0 的有效倍率。');
                  return;
                }
                Navigator.pop(
                  context,
                  UnitConversionRule(
                    sourceUnit: source,
                    targetUnit: target,
                    multiplier: number,
                  ),
                );
              },
              child: const Text('保存规则'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => _draft = _draft.copyWith(
          unitRules: [
            ..._draft.unitRules.where(
              (rule) =>
                  _unitKey(rule.sourceUnit) != _unitKey(result.sourceUnit),
            ),
            result,
          ],
        ),
      );
    }
  }

  String _unitKey(String value) => value.trim().toUpperCase();

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String trailing,
    void Function(double) change,
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            trailing,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      FSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: label == '悬浮窗透明度' ? 60 : 30,
        onChanged: (value) => setState(() => change(value)),
      ),
    ],
  );
  Future<void> _pickFont(bool numbers) async {
    final font = await f.showDialog<String>(
      context: context,
      builder: (context) => _FontDialog(
        fonts: _fonts,
        current: numbers ? _draft.numberFontFamily : _draft.fontFamily,
      ),
    );
    if (font != null && mounted) {
      try {
        await SystemFonts.ensureLoaded(font);
      } catch (_) {
        if (mounted) setState(() => _error = '字体无法加载，请重新选择其他字体。');
        return;
      }
      if (!mounted) return;
      setState(
        () => _draft = numbers
            ? _draft.copyWith(numberFontFamily: font)
            : _draft.copyWith(fontFamily: font),
      );
      widget.controller.previewAppearance(_draft);
    }
  }
}

class _SettingTag extends StatelessWidget {
  const _SettingTag({required this.label, this.avatar});
  final Widget label;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) => f.Card(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (avatar != null) ...[avatar!, const SizedBox(width: 6)],
        Flexible(
          child: DefaultTextStyle(
            style: f.FluentTheme.of(context).typography.caption!,
            child: label,
          ),
        ),
      ],
    ),
  );
}
