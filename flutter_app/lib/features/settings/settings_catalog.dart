import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as f;

class SettingsCategory {
  const SettingsCategory(this.title, this.icon);
  final String title;
  final IconData icon;
}

const settingsCategories = [
  SettingsCategory('关注行情', f.FluentIcons.favorite_star),
  SettingsCategory('自定义内容', f.FluentIcons.database),
  SettingsCategory('显示布局', f.FluentIcons.view_list),
  SettingsCategory('外观', f.FluentIcons.color),
  SettingsCategory('单位与换算', f.FluentIcons.money),
  SettingsCategory('窗口与托盘', f.FluentIcons.chrome_restore),
];

class SettingLocation {
  const SettingLocation(this.section, this.anchor, this.title, this.keywords);
  final int section;
  final String anchor;
  final String title;
  final String keywords;

  bool matches(String query) {
    final text = '${settingsCategories[section].title} $title $keywords'
        .toLowerCase();
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }
}

const settingsLocations = [
  SettingLocation(0, 'assets', '选择行情', '币种 加密货币 股票 ETF 搜索 代码'),
  SettingLocation(0, 'asset-order', '行情显示顺序', '排序 拖动 拖拽 上移 下移 已关注'),
  SettingLocation(1, 'sources', '自定义 API', '数据源 HTTPS 接口 请求头 密钥 刷新 字段'),
  SettingLocation(2, 'default-rows', '显示默认行情', '行情列表 名称 价格 涨跌'),
  SettingLocation(2, 'custom-rows', '自由显示行与模板', '布局 组合 文字 天气 汇率 GitHub'),
  SettingLocation(3, 'fonts', '文字与数字字体', '系统字体 font 中文 数字'),
  SettingLocation(3, 'font-size', '字号与行间距', '文字大小 大小 间隔 spacing'),
  SettingLocation(
    3,
    'themes',
    '浅色与深色主题',
    '配色 背景 颜色 取色 自定义 新建 预设 跟随系统 Fluent Catppuccin Nord Solarized theme',
  ),
  SettingLocation(3, 'opacity', '悬浮窗透明度', '不透明度 opacity 背景 透明'),
  SettingLocation(3, 'header', '窗口标题与图标', '名称 图片 表情 emoji 隐藏标题'),
  SettingLocation(4, 'units', '单位与显示货币', '换算 人民币 美元 CNY USD 简写 标签 倍率'),
  SettingLocation(5, 'window', '窗口置顶', '置顶 悬浮 大小 移动'),
  SettingLocation(5, 'tray', '隐藏与托盘恢复', '双击 隐藏 托盘 单击 恢复'),
  SettingLocation(0, 'storage', '导入与数据位置', '旧版 Python 设置文件 配置 文件夹 路径'),
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
            Text(title, style: f.FluentTheme.of(context).typography.body),
            if (description != null) ...[
              const SizedBox(height: 3),
              Text(
                description!,
                style: TextStyle(
                  color: f.FluentTheme.of(context)
                      .resources
                      .textFillColorSecondary,
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
