import 'package:flutter/widgets.dart';

extension MetricsLocalizationContext on BuildContext {
  MetricsStrings get metrics =>
      MetricsStrings(Localizations.localeOf(this).languageCode == 'zh');
}

class MetricsStrings {
  const MetricsStrings(this.chinese);
  final bool chinese;
  String get floating => chinese ? '悬浮窗' : 'Floating panel';
  String get taskbar => chinese ? '任务栏' : 'Taskbar';
  String get system => chinese ? '系统监测' : 'System monitor';
  String get monitorDescription =>
      chinese ? '选择当前显示位置需要的系统数据。' : 'Choose system metrics for this display.';
  String get deviceSettings => chinese ? '采集与设备' : 'Sampling & devices';
  String get selectedMetrics => chinese ? '已选系统指标' : 'Selected metrics';
  String get metricLibrary => chinese ? '可用指标' : 'Available metrics';
  String get interval => chinese ? '采样间隔' : 'Sample interval';
  String get adapter => chinese ? '网络接口' : 'Network interface';
  String get gpu => chinese ? '显卡' : 'Graphics adapter';
  String get disk => chinese ? '磁盘' : 'Disk';
  String get automatic => chinese ? '自动选择' : 'Automatic';
  String get physicalAdapters =>
      chinese ? '活动物理网卡' : 'Active physical adapters';
  String get allDisks => chinese ? '全部磁盘' : 'All disks';
  String get missingDevice => chinese ? '暂未连接' : 'Currently unavailable';
  String get sharedDevices => chinese
      ? '设备和采样间隔对所有显示位置生效。'
      : 'Devices and sample interval apply to all displays.';
  String get showTaskbar => chinese ? '显示任务栏数据' : 'Show taskbar data';
  String get showFloating => chinese ? '显示行情悬浮窗' : 'Show floating panel';
  String get taskbarLayout => chinese ? '任务栏布局' : 'Taskbar layout';
  String get width => chinese ? '宽度' : 'Width';
  String get layout => chinese ? '排列' : 'Layout';
  String get oneLine => chinese ? '单行' : 'One row';
  String get twoLines => chinese ? '双行' : 'Two rows';
  String get preview => chinese ? '预览' : 'Preview';
  String get customFields => chinese ? '显示字段' : 'Visible fields';
  String get removeSourceTitle => chinese ? '移除数据源？' : 'Remove data source?';
  String get removeSourceBody => chinese
      ? '这个数据源仍被显示项目引用。请先从悬浮窗和任务栏移除相关字段与模板。'
      : 'This source is still referenced. Remove its fields and templates from both displays first.';
  String get unavailable => chinese ? '暂不可用' : 'Unavailable';
  String get waiting => chinese ? '等待采样' : 'Waiting for sample';
  String get reorder => chinese ? '拖动排序' : 'Drag to reorder';
  String get up => chinese ? '上移' : 'Move up';
  String get down => chinese ? '下移' : 'Move down';
  String get remove => chinese ? '移除' : 'Remove';
  String seconds(int value) => chinese ? '$value 秒' : '$value s';
  String status(String state) => switch (state) {
    'displaying' => chinese ? '正在显示' : 'Displaying',
    'disabled' => chinese ? '已关闭' : 'Off',
    'noSpace' => chinese ? '任务栏空间不足，已暂停' : 'Paused: not enough taskbar space',
    'unsupported' => chinese ? '当前任务栏暂不支持' : 'This taskbar is not supported',
    'error' => chinese ? '任务栏显示暂不可用' : 'Taskbar display unavailable',
    _ => chinese ? '等待任务栏就绪' : 'Waiting for taskbar',
  };
}
