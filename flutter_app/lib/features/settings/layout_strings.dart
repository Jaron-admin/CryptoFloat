class LayoutStrings {
  const LayoutStrings(this.chinese);
  final bool chinese;

  String get columns => chinese ? '列数' : 'Columns';
  String columnCount(int count) => chinese
      ? '$count 列'
      : count == 1
      ? '1 column'
      : '$count columns';
  String get entryLayout => chinese ? '单条数据排列' : 'Entry layout';
  String get horizontal => chinese ? '名称在左，数值在右' : 'Name beside value';
  String get vertical => chinese ? '名称在上，数值在下' : 'Name above value';
  String get narrowPanelHint => chinese
      ? '窗口较窄时可横向滚动，保留所选列数。'
      : 'Narrow panels scroll horizontally to keep the selected columns.';
  String get showChangePercent =>
      chinese ? '显示 24h 涨跌幅' : 'Show 24h change percentage';
  String get hiddenPercentHint => chinese
      ? '关闭后只显示价格。价格是否着色由共享的价格颜色决定。'
      : 'When hidden, only the price is shown. Color follows the shared price color setting.';
}
