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
  final Map<String, int> _sourceGenerations = {};
  int _sourceGeneration(String key) => _sourceGenerations[key] ?? 0;
  bool _sourceCurrent(String key, int generation) =>
      !_disposed && generation == _sourceGeneration(key);

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

  /// Raw customFieldKey => last successful value, independent of sibling fields.
  Map<String, DateTime> get customFieldSuccessfulFetchAt => Map.unmodifiable({
    for (final entry in _lastSuccessfulFetchAt.entries)
      if (entry.key.startsWith('field:')) entry.key.substring(6): entry.value,
  });

  RefreshStatus get refreshStatus =>
      _statusForDependencies(DisplayDependencies.forConfig(_config));

  /// Each display ages only its selected or template-referenced fields.
  RefreshStatus refreshStatusFor(DisplayTarget target) {
    final enabled = target == DisplayTarget.floating
        ? _config.floatingEnabled
        : _config.taskbar.enabled;
    return _statusForDependencies(
      enabled
          ? DisplayDependencies.forProfile(
              DisplayProfile.fromConfig(_config.displayFor(target)),
            )
          : const DisplayDependencies(),
    );
  }

  RefreshStatus _statusForDependencies(DisplayDependencies dependencies) =>
      calculateRefreshStatus(
        now: _now(),
        sourceIntervals: {
          for (final asset in _config.acquisitionAssets)
            if (dependencies.assetIds.contains(asset.id))
              asset.id: asset.provider == 'YAHOO' ? 60 : 15,
          for (final source in _config.customSources)
            if (source.enabled)
              for (final fieldKey in dependencies.customFieldIds)
                if (fieldKey.startsWith('custom:${source.id}|'))
                  'field:$fieldKey': source.refreshSeconds.clamp(15, 3600),
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
    final before = _sourceSignatures(_config);
    final after = _sourceSignatures(config);
    final changedKeys = {
      for (final key in {...before.keys, ...after.keys})
        if (before[key] != after[key]) key,
    };
    final conversionChanged =
        config.needsExchangeRates != _config.needsExchangeRates;
    final networkChanged =
        config.proxyEnabled != _config.proxyEnabled ||
        config.proxyHost != _config.proxyHost ||
        config.proxyPort != _config.proxyPort;
    final beforeFields = DisplayDependencies.forConfig(_config).customFieldIds;
    final addedFields = DisplayDependencies.forConfig(config).customFieldIds
        .difference(beforeFields);
    _config = config;
    final activeKeys = after.keys.toSet();
    _quotes.removeWhere((key, _) => !activeKeys.contains(key));
    _lastSuccessfulFetchAt.removeWhere(
      (key, _) => !activeKeys.contains(_timestampSourceKey(key)),
    );
    _nextDue.removeWhere((key, _) => !activeKeys.contains(key));
    for (final key in changedKeys) {
      _sourceGenerations[key] = _sourceGeneration(key) + 1;
      _nextDue.remove(key);
      _running.remove(key);
      _lastSuccessfulFetchAt.removeWhere(
        (timestamp, _) => _timestampSourceKey(timestamp) == key,
      );
      if (_quotes[key] != null) {
        _quotes[key] = _quotes[key]!.withError(
          '设置已更新，等待新行情。',
          clearFieldTimestamps: true,
        );
      }
    }
    for (final fieldKey in addedFields) {
      final separator = fieldKey.indexOf('|');
      if (separator > 0 &&
          !_lastSuccessfulFetchAt.containsKey('field:$fieldKey')) {
        _nextDue.remove(fieldKey.substring(0, separator));
      }
    }
    if (networkChanged) {
      _generation++;
      _ratesRunning = null;
      _nextRatesDue = null;
    }
    for (final source in config.customSources.where(
      (source) =>
          !source.enabled && config.activeCustomSourceIds.contains(source.id),
    )) {
      final key = 'custom:${source.id}';
      _quotes[key] = (_quotes[key] ?? _emptyCustomQuote(source)).withError(
        '此数据源已停用。',
      );
    }
    _notify();
    if (changedKeys.isNotEmpty ||
        addedFields.isNotEmpty ||
        conversionChanged ||
        networkChanged) {
      unawaited(refresh());
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    final now = _now();
    final config = _config;
    final generation = _generation;
    final pending = <Future<void>>[];
    final ratesJob = _startRates(config, generation, now, force);
    if (ratesJob != null) pending.add(ratesJob);
    for (final asset in config.acquisitionAssets) {
      final key = asset.id;
      final sourceGeneration = _sourceGeneration(key);
      final interval = asset.provider == 'YAHOO' ? 60 : 15;
      final job = _start(
        key,
        now,
        interval,
        force,
        sourceGeneration,
        () => _refreshAsset(asset, config, sourceGeneration),
      );
      if (job != null) pending.add(job);
    }
    for (final source in config.customSources.where(
      (source) =>
          source.enabled && config.activeCustomSourceIds.contains(source.id),
    )) {
      final key = 'custom:${source.id}';
      final sourceGeneration = _sourceGeneration(key);
      final interval = source.refreshSeconds.clamp(15, 3600);
      final job = _start(
        key,
        now,
        interval,
        force,
        sourceGeneration,
        () => _refreshCustom(source, config, sourceGeneration),
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
    if (_disposed || generation != _generation || !config.needsExchangeRates) {
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
    if (!_sourceCurrent(key, generation)) return null;
    if (_running.containsKey(key)) return _running[key];
    final due = _nextDue[key];
    if (!force && due != null && now.isBefore(due)) return null;
    _nextDue[key] = now.add(Duration(seconds: seconds));
    // Queue the action so the running state is installed before any notification.
    late final Future<void> operation;
    operation =
        Future<void>.microtask(() async {
          if (!_sourceCurrent(key, generation)) return;
          await action();
        }).whenComplete(() {
          if (!_sourceCurrent(key, generation) ||
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
      if (!_sourceCurrent(asset.id, generation)) return;
      _quotes[asset.id] = quote;
      _lastSuccessfulFetchAt[asset.id] = _now();
    } on Object catch (error) {
      if (!_sourceCurrent(asset.id, generation)) return;
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
      if (!_sourceCurrent(key, generation)) return;
      final sampleTime = _now();
      final previous = _quotes[key];
      final values = <String, Object?>{
        ...?previous?.extra,
        'name': source.name,
        'provider': source.name,
        'symbol': source.id,
      };
      final errors = <String, String>{...?previous?.fieldErrors};
      final timestamps = <String, DateTime>{...?previous?.fieldUpdatedAt};
      final selected = {
        for (final fieldKey in DisplayDependencies.forConfig(
          _config,
        ).customFieldIds)
          if (fieldKey.startsWith('$key|')) fieldKey.substring(key.length + 1),
      };
      final successful = <String>{};
      for (final field in source.fields) {
        final selectedValue = selected.contains(field.id);
        final selectedUnit = selected.contains('${field.id}.unit');
        if (!selectedValue && !selectedUnit) continue;
        final unitId = '${field.id}.unit';
        values[unitId] = field.unit;
        if (selectedUnit) {
          errors.remove(unitId);
          timestamps[unitId] = sampleTime;
          successful.add(unitId);
        }
        if (!selectedValue) continue;
        try {
          final value = resolveJsonPath(document, field.path);
          if (value == null) throw const SourceException('所选字段暂无有效数据。');
          if (!(value is String ||
              value is bool ||
              value is num && value.isFinite)) {
            throw const SourceException('所选字段需要单个数字、文本或布尔值。');
          }
          values[field.id] = value;
          timestamps[field.id] = sampleTime;
          errors.remove(field.id);
          successful.add(field.id);
        } on Object catch (error) {
          errors[field.id] = _friendlyError(error);
          values[field.id] = timestamps.containsKey(field.id)
              ? previous?.field(field.id)
              : null;
        }
      }
      // Template metadata is a valid dependency even without a configured path.
      final catalogIds = {
        for (final field in source.fields) field.id,
        for (final field in source.fields) '${field.id}.unit',
      };
      for (final id in selected.difference(catalogIds)) {
        final value = switch (id) {
          'name' || 'provider' => source.name,
          'symbol' => source.id,
          'updatedAt' => sampleTime,
          _ => null,
        };
        if (value == null) {
          errors[id] = '所选字段不存在。';
          if (!timestamps.containsKey(id)) values[id] = null;
        } else {
          values[id] = value;
          timestamps[id] = sampleTime;
          errors.remove(id);
          successful.add(id);
        }
      }
      final number = values['price'];
      final numeric = number is num
          ? number.toDouble()
          : double.tryParse('$number');
      final change = values['change'];
      final numericChange = change is num
          ? change.toDouble()
          : double.tryParse('$change');
      _quotes[key] = MarketQuote(
        assetId: key,
        price: numeric != null && numeric.isFinite ? numeric : null,
        currency: values['price.unit'] is String
            ? values['price.unit'] as String
            : '',
        updatedAt: sampleTime,
        changePercent: numericChange != null && numericChange.isFinite
            ? numericChange
            : null,
        extra: values,
        fieldErrors: errors,
        fieldUpdatedAt: timestamps,
      );
      for (final id in successful) {
        _lastSuccessfulFetchAt['field:${customFieldKey(source.id, id)}'] =
            sampleTime;
      }
      if (successful.isNotEmpty) _lastSuccessfulFetchAt[key] = sampleTime;
    } on Object catch (error) {
      if (!_sourceCurrent(key, generation)) return;
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

  static String _timestampSourceKey(String key) {
    if (!key.startsWith('field:')) return key;
    final separator = key.indexOf('|', 6);
    return separator < 0 ? key : key.substring(6, separator);
  }

  static Map<String, String> _sourceSignatures(AppConfig config) => {
    for (final asset in config.acquisitionAssets)
      asset.id: jsonEncode(asset.toJson()),
    for (final source in config.customSources)
      if (config.activeCustomSourceIds.contains(source.id))
        'custom:${source.id}': jsonEncode(source.toJson()),
  };

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
