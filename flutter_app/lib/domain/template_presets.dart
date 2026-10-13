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

/// Text copied into a new template. Existing saved content is never translated.
class TemplateStrings {
  const TemplateStrings({
    this.cityLabels = const {},
    this.weatherName = _defaultWeatherName,
    this.invalidCity = '请选择列表中的城市。添加后可在数据源中调整地址。',
    this.temperature = '气温',
    this.feelsLike = '体感',
    this.humidity = '湿度',
    this.usdRates = '美元参考汇率',
    this.usdCny = '美元兑人民币',
    this.usdEur = '美元兑欧元',
    this.usdUsdt = '美元兑 USDT',
    this.referenceRates = '参考汇率',
    this.invalidRepository = '请填写公开仓库的拥有者和仓库名，例如 flutter / flutter。',
    this.openIssues = '未解决议题与 PR',
    this.open = '未解决',
    this.emptyWatchlist = '请先选择至少一个币种或股票。',
    this.emptyText = '请填写要显示的文字。',
  });

  final Map<String, String> cityLabels;
  final String Function(String city) weatherName;
  final String invalidCity,
      temperature,
      feelsLike,
      humidity,
      usdRates,
      usdCny,
      usdEur,
      usdUsdt,
      referenceRates,
      invalidRepository,
      openIssues,
      open,
      emptyWatchlist,
      emptyText;

  String cityLabel(String city) => cityLabels[city] ?? city;
}

String _defaultWeatherName(String city) => '$city天气';

AppConfig appendTemplate(
  AppConfig config,
  TemplateKind kind, {
  String city = '北京',
  String owner = 'flutter',
  String repository = 'flutter',
  String text = '提醒：起来走走，喝杯水',
  String? id,
  TemplateStrings strings = const TemplateStrings(),
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
        throw FormatException(strings.invalidCity);
      }
      source = CustomApiSource(
        id: key,
        name: strings.weatherName(strings.cityLabel(city)),
        refreshSeconds: 900,
        url: Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '${coordinates.$1}',
          'longitude': '${coordinates.$2}',
          'current': 'temperature_2m,apparent_temperature,relative_humidity_2m',
          'timezone': 'auto',
        }).toString(),
        fields: [
          CustomField(
            id: 'temperature',
            label: strings.temperature,
            path: 'current.temperature_2m',
            unit: '°C',
          ),
          CustomField(
            id: 'feels',
            label: strings.feelsLike,
            path: 'current.apparent_temperature',
            unit: '°C',
          ),
          CustomField(
            id: 'humidity',
            label: strings.humidity,
            path: 'current.relative_humidity_2m',
            unit: '%',
          ),
        ],
      );
      literal('${strings.cityLabel(city)}  ');
      field('temperature', format: '.1f');
      literal('  ${strings.feelsLike} ');
      field('feels', format: '.1f');
      literal('  ${strings.humidity} ');
      field('humidity', format: '.0f');
    case TemplateKind.exchangeRates:
      source = CustomApiSource(
        id: key,
        name: strings.usdRates,
        url: 'https://api.coinbase.com/v2/exchange-rates?currency=USD',
        refreshSeconds: 300,
        fields: [
          CustomField(
            id: 'cny',
            label: strings.usdCny,
            path: 'data.rates.CNY',
            unit: 'CNY/USD',
          ),
          CustomField(
            id: 'eur',
            label: strings.usdEur,
            path: 'data.rates.EUR',
            unit: 'EUR/USD',
          ),
          CustomField(
            id: 'usdt',
            label: strings.usdUsdt,
            path: 'data.rates.USDT',
            unit: 'USDT/USD',
          ),
        ],
      );
      literal('${strings.referenceRates}  ');
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
        throw FormatException(strings.invalidRepository);
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
          'User-Agent': 'MetricPerch',
        },
        fields: [
          CustomField(id: 'stars', label: 'Stars', path: 'stargazers_count'),
          CustomField(
            id: 'issues',
            label: strings.openIssues,
            path: 'open_issues_count',
          ),
        ],
      );
      literal('$repository  ★ ');
      field('stars', format: '.0f');
      literal('  ${strings.open} ');
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
      if (segments.isEmpty) throw FormatException(strings.emptyWatchlist);
    case TemplateKind.reminder:
      if (text.trim().isEmpty) throw FormatException(strings.emptyText);
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
