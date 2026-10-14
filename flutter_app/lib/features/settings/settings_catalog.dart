import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/metrics_strings.dart';

class SettingsCategory {
  const SettingsCategory(this.id, this.icon);
  final String id;
  final IconData icon;

  String title(AppLocalizations l10n) => switch (id) {
    'watchlist' => l10n.settingWatchlist,
    'sources' => l10n.settingCustomContent,
    'layout' => l10n.settingLayout,
    'appearance' => l10n.settingAppearance,
    'units' => l10n.settingUnitsTitle,
    'metrics' => MetricsStrings(l10n.localeName.startsWith('zh')).system,
    _ => l10n.settingWindow,
  };
}

const settingsCategories = [
  SettingsCategory('watchlist', Icons.star_outline_rounded),
  SettingsCategory('sources', Icons.api_rounded),
  SettingsCategory('layout', Icons.view_agenda_outlined),
  SettingsCategory('appearance', Icons.palette_outlined),
  SettingsCategory('units', Icons.currency_exchange_rounded),
  SettingsCategory('window', Icons.desktop_windows_outlined),
  SettingsCategory('metrics', Icons.monitor_heart_outlined),
];

class SettingLocation {
  const SettingLocation(
    this.section,
    this.anchor,
    this.searchTitle,
    this.keywords,
  );
  final int section;
  final String anchor;
  final String searchTitle;
  final String keywords;

  String title(AppLocalizations l10n) => switch (anchor) {
    'assets' => l10n.settingCatalogAssets,
    'asset-order' => l10n.settingCatalogOrder,
    'sources' => l10n.settingCatalogApi,
    'default-rows' => l10n.settingDefaultRows,
    'panel-layout' => l10n.settingLayout,
    'custom-rows' => l10n.settingCatalogRows,
    'language' => l10n.settingLanguage,
    'fonts' => l10n.settingCatalogFonts,
    'font-size' => l10n.settingCatalogSpacing,
    'themes' => l10n.settingCatalogThemes,
    'opacity' => l10n.settingOpacity,
    'header' => l10n.settingCatalogHeader,
    'units' => l10n.settingCatalogUnits,
    'window' => l10n.settingCatalogWindow,
    'tray' => l10n.settingCatalogTray,
    'metrics' => MetricsStrings(l10n.localeName.startsWith('zh')).system,
    _ => l10n.settingStorage,
  };

  bool matches(String query) {
    final text = '${settingsCategories[section].id} $searchTitle $keywords'
        .toLowerCase();
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }
}

const settingsLocations = [
  SettingLocation(
    2,
    'panel-layout',
    '列数与行情布局',
    '单列 双列 多列 横向 纵向 24h 涨跌幅 涨跌颜色 红涨绿跌 绿涨红跌 columns horizontal vertical orientation price change percent layout colors',
  ),
  SettingLocation(
    6,
    'metrics',
    '系统监测',
    'cpu memory ram gpu vram network upload download disk system monitor 内存 显卡 显存 网速 上传 下载 磁盘 采样 系统 指标',
  ),
  SettingLocation(
    0,
    'assets',
    '选择行情',
    '币种 加密货币 股票 ETF 搜索 代码 instruments currencies crypto stocks search symbol provider watchlist',
  ),
  SettingLocation(
    0,
    'asset-order',
    '行情显示顺序',
    '排序 拖动 拖拽 上移 下移 已关注 order reorder sort drag up down watchlist',
  ),
  SettingLocation(
    1,
    'sources',
    '自定义 API',
    '数据源 HTTPS 接口 请求头 密钥 刷新 字段 custom API sources headers keys refresh fields',
  ),
  SettingLocation(
    2,
    'default-rows',
    '显示默认行情',
    '行情列表 名称 价格 涨跌 default quotes rows list names prices changes',
  ),
  SettingLocation(
    2,
    'custom-rows',
    '自由显示行与模板',
    '布局 组合 文字 天气 汇率 GitHub custom rows templates layout text weather exchange rates',
  ),
  SettingLocation(
    3,
    'language',
    '语言',
    '中文 英文 跟随系统 简体 language English Chinese system',
  ),
  SettingLocation(3, 'fonts', '文字与数字字体', '系统字体 中文 数字 text number system fonts'),
  SettingLocation(3, 'font-size', '字号与行间距', '文字大小 大小 间隔 font size row spacing'),
  SettingLocation(
    3,
    'themes',
    '浅色与深色主题',
    '配色 背景 颜色 取色 自定义 新建 预设 跟随系统 Fluent Catppuccin Nord Solarized theme light dark colors custom presets follow system',
  ),
  SettingLocation(
    3,
    'opacity',
    '悬浮窗透明度',
    '不透明度 背景 透明 panel transparency opacity background',
  ),
  SettingLocation(
    3,
    'header',
    '窗口标题与图标',
    '名称 图片 表情 隐藏标题 header title name icon image emoji hide',
  ),
  SettingLocation(
    4,
    'units',
    '单位与显示货币',
    '换算 人民币 美元 CNY USD 简写 标签 倍率 units currency conversion short labels multiplier',
  ),
  SettingLocation(
    5,
    'window',
    '窗口置顶',
    '置顶 悬浮 大小 移动 window always on top size move',
  ),
  SettingLocation(
    5,
    'tray',
    '隐藏与托盘恢复',
    '双击 隐藏 托盘 单击 恢复 hide restore tray double click',
  ),
  SettingLocation(
    0,
    'storage',
    '导入与数据位置',
    '旧版 Python 设置文件 配置 文件夹 路径 import legacy storage data location config folder path',
  ),
];

/// A compact setting keeps its label and control together at small widths.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.description,
    required this.control,
    this.controlWidth = 180,
  });

  final String title;
  final String? description;
  final Widget control;
  final double controlWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            if (description != null) ...[
              const SizedBox(height: 3),
              Text(
                description!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
        if (constraints.maxWidth < 420 && controlWidth > 100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 8),
              Semantics(label: title, child: control),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 16),
            SizedBox(
              width: controlWidth,
              child: Semantics(label: title, child: control),
            ),
          ],
        );
      },
    ),
  );
}
