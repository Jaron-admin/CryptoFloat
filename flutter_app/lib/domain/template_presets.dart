import 'models.dart';

enum TemplateKind { weather, exchangeRates, github, marketBar, reminder }

const weatherCities = <String, (double, double)>{
  '北京': (39.9042, 116.4074),
  '上海': (31.2304, 121.4737),
  '广州': (23.1291, 113.2644),
  '深圳': (22.5431, 114.0579),
  '杭州': (30.2741, 120.1551),
  '成都': (30.5728, 104.0668),
  '武汉': (30.5928, 114.3055),
  '西安': (34.3416, 108.9398),
};

AppConfig appendTemplate(
  AppConfig config,
  TemplateKind kind, {
  String city = '北京',
  String owner = 'flutter',
  String repository = 'flutter',
  String text = '提醒：起来走走，喝杯水',
  String? id,
}) {
  final base = id ?? 'preset_${DateTime.now().microsecondsSinceEpoch}';
  var key = base;
  var suffix = 1;
  while (config.displayRows.any((row) => row.id == key) ||
      config.customSources.any((source) => source.id == key)) {
    key = '${base}_${suffix++}';
  }
  CustomApiSource? source;
  final segments = <DisplaySegment>[];
  void literal(String value) => segments.add(DisplaySegment.literal(value));
  void field(String name, {String format = ''}) => segments.add(
    DisplaySegment.field(assetId: 'custom:$key', fieldId: name, format: format),
  );
  switch (kind) {
    case TemplateKind.weather:
      final coordinates = weatherCities[city];
      if (coordinates == null) {
        throw const FormatException('请选择列表中的城市。添加后可在数据源中调整地址。');
      }
      source = CustomApiSource(
        id: key,
        name: '$city天气',
        refreshSeconds: 900,
        url: Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '${coordinates.$1}',
          'longitude': '${coordinates.$2}',
          'current': 'temperature_2m,apparent_temperature,relative_humidity_2m',
          'timezone': 'auto',
        }).toString(),
        fields: const [
          CustomField(
            id: 'temperature',
            label: '气温',
            path: 'current.temperature_2m',
            unit: '°C',
          ),
          CustomField(
            id: 'feels',
            label: '体感',
            path: 'current.apparent_temperature',
            unit: '°C',
          ),
          CustomField(
            id: 'humidity',
            label: '湿度',
            path: 'current.relative_humidity_2m',
            unit: '%',
          ),
        ],
      );
      literal('$city  ');
      field('temperature', format: '.1f');
      literal('  体感 ');
      field('feels', format: '.1f');
      literal('  湿度 ');
      field('humidity', format: '.0f');
    case TemplateKind.exchangeRates:
      source = CustomApiSource(
        id: key,
        name: '美元参考汇率',
        url: 'https://api.coinbase.com/v2/exchange-rates?currency=USD',
        refreshSeconds: 300,
        fields: const [
          CustomField(
            id: 'cny',
            label: '美元兑人民币',
            path: 'data.rates.CNY',
            unit: 'CNY/USD',
          ),
          CustomField(
            id: 'eur',
            label: '美元兑欧元',
            path: 'data.rates.EUR',
            unit: 'EUR/USD',
          ),
          CustomField(
            id: 'usdt',
            label: '美元兑 USDT',
            path: 'data.rates.USDT',
            unit: 'USDT/USD',
          ),
        ],
      );
      literal('参考汇率  ');
      field('cny', format: '.4f');
      literal('  ');
      field('eur', format: '.4f');
      literal('  ');
      field('usdt', format: '.4f');
    case TemplateKind.github:
      owner = owner.trim();
      repository = repository.trim();
      final valid = RegExp(r'^[A-Za-z0-9_.-]+$');
      if (!valid.hasMatch(owner) ||
          !valid.hasMatch(repository) ||
          owner.contains('..') ||
          repository.contains('..')) {
        throw const FormatException('请填写公开仓库的拥有者和仓库名，例如 flutter / flutter。');
      }
      source = CustomApiSource(
        id: key,
        name: '$owner/$repository',
        url: Uri.https(
          'api.github.com',
          '/repos/$owner/$repository',
        ).toString(),
        refreshSeconds: 600,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'CryptoFloat',
        },
        fields: const [
          CustomField(id: 'stars', label: 'Stars', path: 'stargazers_count'),
          CustomField(
            id: 'issues',
            label: '未解决议题与 PR',
            path: 'open_issues_count',
          ),
        ],
      );
      literal('$repository  ★ ');
      field('stars', format: '.0f');
      literal('  未解决 ');
      field('issues', format: '.0f');
    case TemplateKind.marketBar:
      for (final asset in config.assets.take(3)) {
        if (segments.isNotEmpty) literal('  ·  ');
        literal('${asset.symbol} ');
        segments.add(DisplaySegment.field(assetId: asset.id, fieldId: 'price'));
        literal(' ');
        segments.add(
          DisplaySegment.field(assetId: asset.id, fieldId: 'currency'),
        );
      }
      if (segments.isEmpty) throw const FormatException('请先选择至少一个币种或股票。');
    case TemplateKind.reminder:
      if (text.trim().isEmpty) throw const FormatException('请填写要显示的文字。');
      literal(text);
  }
  return config.copyWith(
    customSources: [...config.customSources, ?source],
    displayRows: [
      ...config.displayRows,
      DisplayRow(id: key, segments: segments),
    ],
  );
}
