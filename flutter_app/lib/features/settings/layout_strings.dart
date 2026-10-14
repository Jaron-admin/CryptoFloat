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
      ? '关闭后，行情价格以涨跌颜色显示。'
      : 'When hidden, market prices use the rise or fall color.';
  String get changeColors => chinese ? '涨跌颜色' : 'Rise and fall colors';
  String get themeColors => chinese ? '使用主题颜色' : 'Use theme colors';
  String get greenUp => chinese ? '绿涨红跌' : 'Green up, red down';
  String get redUp => chinese ? '红涨绿跌' : 'Red up, green down';
  String get colorHint => chinese
      ? '选择“使用主题颜色”可沿用主题中自定义的上涨、下跌颜色。'
      : 'Use theme colors to keep the custom rise and fall colors in your theme.';
}
