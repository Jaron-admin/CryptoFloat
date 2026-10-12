import '../domain/models.dart';
import 'http_transport.dart';

/// Public read-only providers. Endpoint contracts are linked beside each client.
class BuiltInProvider {
  BuiltInProvider(this.transport);
  final HttpTransport transport;

  Future<MarketQuote> fetch(Asset asset, AppConfig config) async {
    return switch (asset.provider) {
      'OKX' => _okx(asset, config),
      'BINANCE' => _binance(asset, config),
      'KUCOIN' => _kucoin(asset, config),
      'YAHOO' => _yahoo(asset, config),
      _ => throw const SourceException('此资产的数据源尚不支持。'),
    };
  }

  // https://www.okx.com/docs-v5/en/#rest-api-market-data-get-ticker
  Future<MarketQuote> _okx(Asset asset, AppConfig config) async {
    final payload = _object(
      await transport.getJson(
        Uri.https('www.okx.com', '/api/v5/market/ticker', {
          'instId': asset.symbol,
        }),
        config,
      ),
    );
    if (payload['code'] != '0') {
      throw const SourceException('OKX 未返回有效行情，请检查交易对或地区可用性。');
    }
    final data = _firstObject(payload['data']);
    final price = _price(data['last']);
    final open = _number(data['open24h']);
    return _quote(
      asset,
      price,
      _timestamp(data['ts']),
      change: _change(price, open),
      extra: {
        'open': open,
        'high': _number(data['high24h']),
        'low': _number(data['low24h']),
        'volume': _number(data['vol24h']),
        'quote_volume': _number(data['volCcy24h']),
        'bid': _number(data['bidPx']),
        'ask': _number(data['askPx']),
      },
    );
  }

  // https://github.com/binance/binance-spot-api-docs/blob/master/faqs/market_data_only.md
  // https://developers.binance.com/docs/binance-spot-api-docs/rest-api/market-data-endpoints
  Future<MarketQuote> _binance(Asset asset, AppConfig config) async {
    final data = _object(
      await transport.getJson(
        Uri.https('data-api.binance.vision', '/api/v3/ticker/24hr', {
          'symbol': asset.symbol,
        }),
        config,
      ),
    );
    final price = _price(data['lastPrice']);
    return _quote(
      asset,
      price,
      _timestamp(data['closeTime']),
      change: _number(data['priceChangePercent']),
      extra: {
        'open': _number(data['openPrice']),
        'high': _number(data['highPrice']),
        'low': _number(data['lowPrice']),
        'volume': _number(data['volume']),
        'quote_volume': _number(data['quoteVolume']),
        'previous_close': _number(data['prevClosePrice']),
        'weighted_average': _number(data['weightedAvgPrice']),
        'trades': _number(data['count']),
        'bid': _number(data['bidPrice']),
        'ask': _number(data['askPrice']),
      },
    );
  }

  // https://www.kucoin.com/docs-new/rest/spot-trading/market-data/get-24hr-stats
  Future<MarketQuote> _kucoin(Asset asset, AppConfig config) async {
    final payload = _object(
      await transport.getJson(
        Uri.https('api.kucoin.com', '/api/v1/market/stats', {
          'symbol': asset.symbol,
        }),
        config,
      ),
    );
    if (payload['code'] != '200000') {
      throw const SourceException('KuCoin 未返回有效行情，请检查交易对。');
    }
    final data = _object(payload['data']);
    final rate = _number(data['changeRate']);
    return _quote(
      asset,
      _price(data['last']),
      _timestamp(data['time']),
      change: rate == null ? null : rate * 100,
      extra: {
        'high': _number(data['high']),
        'low': _number(data['low']),
        'volume': _number(data['vol']),
        'quote_volume': _number(data['volValue']),
        'weighted_average': _number(data['averagePrice']),
        'bid': _number(data['buy']),
        'ask': _number(data['sell']),
      },
    );
  }

  // Yahoo's chart endpoint is unofficial, may be delayed and can change or throttle.
  // .SS / .SZ symbols select Shanghai / Shenzhen A-share quotes on the same host.
  Future<MarketQuote> _yahoo(Asset asset, AppConfig config) async {
    final uri = Uri(
      scheme: 'https',
      host: 'query1.finance.yahoo.com',
      pathSegments: ['v8', 'finance', 'chart', asset.symbol],
      queryParameters: {'interval': '1d', 'range': '1d'},
    );
    final payload = _object(await transport.getJson(uri, config));
    final chart = _object(payload['chart']);
    if (chart['error'] != null) {
      throw const SourceException('Yahoo Finance 未返回有效行情，请检查股票代码或稍后重试。');
    }
    final result = _firstObject(chart['result']);
    final meta = _object(result['meta']);
    final indicators = _object(result['indicators']);
    final bars =
        indicators['quote'] is List && (indicators['quote'] as List).isNotEmpty
        ? _object((indicators['quote'] as List).first)
        : <String, dynamic>{};
    final price = _price(
      meta['regularMarketPrice'] ?? _lastNumber(bars['close']),
    );
    final previous = _number(
      meta['previousClose'] ?? meta['chartPreviousClose'],
    );
    final seconds = _number(meta['regularMarketTime']);
    return _quote(
      asset,
      price,
      seconds == null ? DateTime.now() : _timestamp(seconds * 1000),
      currency: meta['currency'] is String
          ? meta['currency'] as String
          : asset.currency,
      change: _change(price, previous),
      extra: {
        'open': _lastNumber(bars['open']),
        'high':
            _number(meta['regularMarketDayHigh']) ?? _lastNumber(bars['high']),
        'low': _number(meta['regularMarketDayLow']) ?? _lastNumber(bars['low']),
        'volume':
            _number(meta['regularMarketVolume']) ?? _lastNumber(bars['volume']),
        'previous_close': previous,
        'exchange': meta['exchangeName'],
        'market_state': meta['marketState'],
        'dataNote': 'Yahoo Finance 非官方接口；行情可能延迟。',
      },
    );
  }

  MarketQuote _quote(
    Asset asset,
    double price,
    DateTime updatedAt, {
    double? change,
    String? currency,
    Map<String, Object?> extra = const {},
  }) => MarketQuote(
    assetId: asset.id,
    price: price,
    currency: currency ?? asset.currency,
    updatedAt: updatedAt,
    changePercent: change,
    extra: {
      'symbol': asset.symbol,
      'name': asset.name,
      'provider': asset.provider,
      'exchange': asset.provider,
      ...extra,
    },
  );

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const SourceException('行情响应结构无效。');
    }
    return value;
  }

  static Map<String, dynamic> _firstObject(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const SourceException('数据源未返回此资产的行情。');
    }
    return _object(value.first);
  }

  static double? _number(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  static double _price(Object? value) {
    final price = _number(value);
    if (price == null || price < 0) {
      throw const SourceException('数据源没有有效的最新价格。');
    }
    return price;
  }

  static double? _lastNumber(Object? values) => values is List
      ? values.reversed.map(_number).whereType<double>().firstOrNull
      : null;
  static double? _change(double price, double? previous) =>
      previous != null && previous > 0
      ? (price - previous) / previous * 100
      : null;
  static DateTime _timestamp(Object? value) {
    final timestamp = _number(value);
    if (timestamp == null || timestamp <= 0 || timestamp > 8640000000000000) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
  }
}
