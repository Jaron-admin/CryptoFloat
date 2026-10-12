import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/refresh_status.dart';
import '../platform/secret_store.dart';
import 'built_in_provider.dart';
import 'currency_rates.dart';
import 'http_transport.dart';
import 'json_path.dart';
import 'proxy_resolver.dart';
import 'source_security.dart';

/// Independent polling for each configured source, with retained good values.
class MarketDataService extends ChangeNotifier {
  MarketDataService(
    AppConfig config,
    this._secrets, {
    HttpTransport? transport,
    SystemProxyResolver? systemProxyResolver,
    DateTime Function()? now,
  }) : _config = config,
       _transport =
           transport ?? HttpTransport(systemProxyResolver: systemProxyResolver),
       _now = now ?? DateTime.now {
    _provider = BuiltInProvider(_transport);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(refresh());
  }

  AppConfig _config;
  final SecretStore _secrets;
  final HttpTransport _transport;
  final DateTime Function() _now;
  late final BuiltInProvider _provider;
  late final Timer _timer;
  final Map<String, MarketQuote> _quotes = {};
  final Map<String, DateTime> _nextDue = {};
  final Map<String, Future<void>> _running = {};
  final Map<String, DateTime> _lastSuccessfulFetchAt = {};
  RefreshStatus? _publishedStatus;
  Map<String, double> _cachedExchangeRates = const {};
  DateTime? _ratesFetchedAt;
  DateTime? _nextRatesDue;
  Future<void>? _ratesRunning;
  String? _ratesError;
  bool _publishedRatesUsable = false;
  bool _disposed = false;
  int _generation = 0;

  Map<String, MarketQuote> get quotes => Map.unmodifiable(_quotes);
  bool get refreshing => _running.isNotEmpty;
  Map<String, double> get exchangeRates => usableExchangeRates(
    rates: _cachedExchangeRates,
    fetchedAt: _ratesFetchedAt,
    now: _now(),
  );
  Map<String, double> get cachedExchangeRates =>
      Map.unmodifiable(_cachedExchangeRates);
  DateTime? get ratesFetchedAt => _ratesFetchedAt;
  String? get ratesError => _ratesError;
  Map<String, DateTime> get lastSuccessfulFetchAt =>
      Map.unmodifiable(_lastSuccessfulFetchAt);
  RefreshStatus get refreshStatus => calculateRefreshStatus(
    now: _now(),
    sourceIntervals: {
      for (final asset in _config.assets)
        asset.id: asset.provider == 'YAHOO' ? 60 : 15,
      for (final source in _config.customSources.where(
        (source) => source.enabled && source.fields.isNotEmpty,
      ))
        'custom:${source.id}': source.refreshSeconds.clamp(15, 3600),
    },
    lastSuccessfulFetchAt: _lastSuccessfulFetchAt,
  );

  void _tick() {
    if (_disposed) return;
    final status = refreshStatus;
    if (status.state != _publishedStatus?.state ||
        status.staleSourceCount != _publishedStatus?.staleSourceCount ||
        status.waitingSourceCount != _publishedStatus?.waitingSourceCount ||
        exchangeRates.isNotEmpty != _publishedRatesUsable) {
      _notify();
    }
    unawaited(refresh());
  }

  void _notify() {
    if (_disposed) return;
    _publishedStatus = refreshStatus;
    _publishedRatesUsable = exchangeRates.isNotEmpty;
    notifyListeners();
  }

  void updateConfig(AppConfig config) {
    if (_disposed) return;
    final changed = _sourceSignature(config) != _sourceSignature(_config);
    final conversionChanged = config.displayCurrency != _config.displayCurrency;
    _config = config;
    final activeKeys = {
      for (final asset in config.assets) asset.id,
      for (final source in config.customSources) 'custom:${source.id}',
    };
    _quotes.removeWhere((key, _) => !activeKeys.contains(key));
    _lastSuccessfulFetchAt.removeWhere((key, _) => !activeKeys.contains(key));
    _nextDue.removeWhere((key, _) => !activeKeys.contains(key));
    if (changed) {
      _generation++;
      _nextDue.clear();
      // Old work may finish, but must not block requests for the new settings.
      _running.clear();
      _ratesRunning = null;
      _lastSuccessfulFetchAt.clear();
      for (final key in _quotes.keys.toList()) {
        _quotes[key] = _quotes[key]!.withError('设置已更新，等待新行情。');
      }
    }
    if (changed || conversionChanged) _nextRatesDue = null;
    for (final source in config.customSources.where(
      (source) => !source.enabled,
    )) {
      final key = 'custom:${source.id}';
      _quotes[key] = (_quotes[key] ?? _emptyCustomQuote(source)).withError(
        '此数据源已停用。',
      );
    }
    _notify();
    if (changed || conversionChanged) unawaited(refresh());
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    final now = _now();
    final config = _config;
    final generation = _generation;
    final pending = <Future<void>>[];
    final ratesJob = _startRates(config, generation, now, force);
    if (ratesJob != null) pending.add(ratesJob);
    for (final asset in config.assets) {
      final key = asset.id;
      final interval = asset.provider == 'YAHOO' ? 60 : 15;
      final job = _start(
        key,
        now,
        interval,
        force,
        generation,
        () => _refreshAsset(asset, config, generation),
      );
      if (job != null) pending.add(job);
    }
    for (final source in config.customSources.where(
      (source) => source.enabled,
    )) {
      final key = 'custom:${source.id}';
      final interval = source.refreshSeconds.clamp(15, 3600);
      final job = _start(
        key,
        now,
        interval,
        force,
        generation,
        () => _refreshCustom(source, config, generation),
      );
      if (job != null) pending.add(job);
    }
    if (pending.isNotEmpty) await Future.wait(pending);
  }

  Future<void>? _startRates(
    AppConfig config,
    int generation,
    DateTime now,
    bool force,
  ) {
    if (_disposed ||
        generation != _generation ||
        config.displayCurrency.trim().isEmpty) {
      return null;
    }
    if (_ratesRunning != null) return _ratesRunning;
    if (!force && _nextRatesDue != null && now.isBefore(_nextRatesDue!)) {
      return null;
    }
    // Failed requests retry after 15 seconds; success schedules a 300s cache.
    _nextRatesDue = now.add(const Duration(seconds: 15));
    late final Future<void> operation;
    operation =
        Future<void>.microtask(() async {
          if (_disposed || generation != _generation) return;
          try {
            final response = await _transport.getJson(
              Uri.https('api.coinbase.com', '/v2/exchange-rates', {
                'currency': 'USD',
              }),
              config,
            );
            final rates = parseUsdExchangeRates(response);
            if (_disposed || generation != _generation) return;
            _cachedExchangeRates = rates;
            _ratesFetchedAt = _now();
            _nextRatesDue = _ratesFetchedAt!.add(currencyRateCacheDuration);
            _ratesError = null;
          } on Object catch (error) {
            if (_disposed || generation != _generation) return;
            _ratesError = _friendlyError(error);
          }
        }).whenComplete(() {
          if (generation != _generation ||
              !identical(_ratesRunning, operation)) {
            return;
          }
          _ratesRunning = null;
          _notify();
        });
    _ratesRunning = operation;
    return operation;
  }

  Future<void>? _start(
    String key,
    DateTime now,
    int seconds,
    bool force,
    int generation,
    Future<void> Function() action,
  ) {
    if (_disposed || generation != _generation) return null;
    if (_running.containsKey(key)) return _running[key];
    final due = _nextDue[key];
    if (!force && due != null && now.isBefore(due)) return null;
    _nextDue[key] = now.add(Duration(seconds: seconds));
    // Queue the action so the running state is installed before any notification.
    late final Future<void> operation;
    operation =
        Future<void>.microtask(() async {
          if (_disposed || generation != _generation) return;
          await action();
        }).whenComplete(() {
          if (generation != _generation ||
              !identical(_running[key], operation)) {
            return;
          }
          _running.remove(key);
          if (!_disposed) _notify();
        });
    _running[key] = operation;
    _notify();
    return operation;
  }

  Future<void> _refreshAsset(
    Asset asset,
    AppConfig config,
    int generation,
  ) async {
    try {
      final quote = await _provider.fetch(asset, config);
      if (_disposed || generation != _generation) return;
      _quotes[asset.id] = quote;
      _lastSuccessfulFetchAt[asset.id] = _now();
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _quotes[asset.id] =
          (_quotes[asset.id] ??
                  MarketQuote(
                    assetId: asset.id,
                    price: null,
                    currency: asset.currency,
                    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                    extra: {
                      'symbol': asset.symbol,
                      'name': asset.name,
                      'provider': asset.provider,
                    },
                  ))
              .withError(_friendlyError(error));
    }
    if (!_disposed) _notify();
  }

  Future<void> _refreshCustom(
    CustomApiSource source,
    AppConfig config,
    int generation,
  ) async {
    final key = 'custom:${source.id}';
    try {
      final document = await _fetchCustom(source, config);
      final values = <String, Object?>{
        'name': source.name,
        'provider': source.name,
        'symbol': source.id,
      };
      for (final field in source.fields) {
        final value = resolveJsonPath(document, field.path);
        if (value is Map || value is List) {
          throw const SourceException('所选字段需要单个数字、文本或布尔值。');
        }
        values[field.id] = value;
        values['${field.id}.unit'] = field.unit;
      }
      if (source.fields.isNotEmpty &&
          source.fields.every((field) => values[field.id] == null)) {
        throw const SourceException('所选字段暂无有效数据。');
      }
      final number = values['price'];
      final numeric = number is num
          ? number.toDouble()
          : double.tryParse('$number');
      final change = values['change'];
      final numericChange = change is num
          ? change.toDouble()
          : double.tryParse('$change');
      if (_disposed || generation != _generation) return;
      _quotes[key] = MarketQuote(
        assetId: key,
        price: numeric != null && numeric.isFinite ? numeric : null,
        currency: values['price.unit'] is String
            ? values['price.unit'] as String
            : '',
        updatedAt: _now(),
        changePercent: numericChange != null && numericChange.isFinite
            ? numericChange
            : null,
        extra: values,
      );
      if (source.fields.isNotEmpty) {
        _lastSuccessfulFetchAt[key] = _now();
      }
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _quotes[key] = (_quotes[key] ?? _emptyCustomQuote(source)).withError(
        _friendlyError(error),
      );
    }
    if (!_disposed) _notify();
  }

  /// Reads primitive fields for the visual picker, using the same protected GET.
  Future<Map<String, Object?>> previewSource(CustomApiSource source) async {
    try {
      final document = await _fetchCustom(source, _config);
      final fields = flattenJson(document);
      if (fields.isEmpty) throw const SourceException('响应中没有可选择的字段。');
      return fields;
    } on Object catch (error) {
      throw SourceException(_friendlyError(error));
    }
  }

  Future<Object?> _fetchCustom(CustomApiSource source, AppConfig config) async {
    final uri = validateSource(source);
    final headers = {...source.headers};
    for (final entry in source.secretHeaderRefs.entries) {
      final value = await _secrets
          .read(entry.value)
          .timeout(HttpTransport.timeout);
      if (value == null || value.isEmpty) {
        throw const SourceException('此数据源缺少受保护的请求头。请在设置中重新填写密钥。');
      }
      validateHeader(entry.key, value);
      headers[entry.key] = value;
    }
    return _transport.getJson(uri, config, headers: headers);
  }

  static MarketQuote _emptyCustomQuote(CustomApiSource source) => MarketQuote(
    assetId: 'custom:${source.id}',
    price: null,
    currency: '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    extra: {'name': source.name, 'provider': source.name, 'symbol': source.id},
  );

  static String _sourceSignature(AppConfig config) => jsonEncode({
    'assets': config.assets.map((asset) => asset.toJson()).toList(),
    'sources': config.customSources.map((source) => source.toJson()).toList(),
  });

  static String _friendlyError(Object error) {
    if (error is SourceException) return error.message;
    if (error is FormatException) return error.message.toString();
    if (error is TimeoutException) return '读取受保护的请求头超时，请重试。';
    return '无法完成数据请求。请检查数据源、密钥和网络设置。';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    _transport.dispose();
    super.dispose();
  }
}
