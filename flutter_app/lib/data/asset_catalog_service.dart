import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import 'http_transport.dart';

/// Names and symbols only. This service never requests quotes or alters the
/// user's saved assets. Give it a dedicated transport; [dispose] closes it.
class AssetCatalogService extends ChangeNotifier {
  AssetCatalogService({required this.transport, required String cacheDirectory})
    : _cacheDirectory = Directory(cacheDirectory);

  static const _refreshInterval = Duration(hours: 24);
  static const _retryInterval = Duration(minutes: 5);
  static const _cacheByteLimit = 16 * 1024 * 1024;
  static const _entryLimit = 50000;
  static final _endpoints = <String, Uri>{
    // https://www.okx.com/docs-v5/en/#public-data-rest-api-get-instruments
    'OKX': Uri.https('www.okx.com', '/api/v5/public/instruments', {
      'instType': 'SPOT',
    }),
    // https://github.com/binance/binance-spot-api-docs/blob/master/rest-api.md#exchange-information
    // https://github.com/binance/binance-spot-api-docs/blob/master/faqs/market_data_only.md
    'BINANCE': Uri.https('data-api.binance.vision', '/api/v3/exchangeInfo', {
      'permissions': 'SPOT',
      'showPermissionSets': 'false',
      'symbolStatus': 'TRADING',
    }),
    // https://www.kucoin.com/docs-new/rest/spot-trading/market-data/get-all-symbols
    'KUCOIN': Uri.https('api.kucoin.com', '/api/v2/symbols'),
  };

  final HttpTransport transport;
  final Directory _cacheDirectory;
  final Map<String, _CatalogSnapshot> _snapshots = {};
  final Map<String, DateTime> _lastAttempts = {};
  final Map<String, String> _errors = {};
  List<Asset> _assets = List<Asset>.unmodifiable(Asset.popular);
  Future<void>? _refreshTask;
  bool _cacheLoaded = false;
  bool _loading = false;
  bool _disposed = false;

  List<Asset> get assets => _assets;
  bool get loading => _loading;
  Map<String, String> get errors => Map<String, String>.unmodifiable(_errors);

  /// Reads the last successful catalogs first, then refreshes stale sources.
  /// Calls share the current refresh; force bypasses the age/retry checks.
  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future<void>.value();
    return _refreshTask ??= _refresh(force).whenComplete(() {
      _refreshTask = null;
    });
  }

  Future<void> _refresh(bool force) async {
    _loading = true;
    _notify();
    try {
      if (!_cacheLoaded) {
        await Future.wait(_endpoints.keys.map(_loadCache));
        _cacheLoaded = true;
        if (_disposed) return;
        _rebuildAssets();
        _notify();
      }
      if (_disposed) return;
      final now = DateTime.now().toUtc();
      final providers = _endpoints.keys.where((provider) {
        if (force) return true;
        final snapshot = _snapshots[provider];
        if (snapshot != null &&
            now.difference(snapshot.updatedAt) < _refreshInterval) {
          return false;
        }
        final attemptedAt = _lastAttempts[provider];
        return attemptedAt == null ||
            now.difference(attemptedAt) >= _retryInterval;
      }).toList();
      await Future.wait(providers.map(_refreshProvider));
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _refreshProvider(String provider) async {
    _lastAttempts[provider] = DateTime.now().toUtc();
    try {
      final body = await transport.getCatalogJson(
        _endpoints[provider]!,
        AppConfig.defaults,
      );
      if (_disposed) return;
      final assets = _parseCatalog(provider, body);
      final snapshot = _CatalogSnapshot(DateTime.now().toUtc(), assets);
      _snapshots[provider] = snapshot;
      _errors.remove(provider);
      _rebuildAssets();
      _notify();
      try {
        await _saveCache(provider, snapshot);
      } on Object {
        if (!_disposed) _errors[provider] = '目录已更新，但本地缓存无法保存。';
      }
    } on SourceException catch (error) {
      if (!_disposed) _errors[provider] = error.message;
    } on Object {
      // Exchange responses and filesystem exceptions must not leak raw details.
      if (!_disposed) _errors[provider] = '币种目录暂时无法更新，请稍后重试。';
    } finally {
      _notify();
    }
  }

  void _rebuildAssets() {
    final all = <Asset>[
      ...Asset.popular.where(
        (asset) => !_endpoints.containsKey(asset.provider),
      ),
      for (final provider in _endpoints.keys)
        ...(_snapshots[provider]?.assets ??
            Asset.popular.where((asset) => asset.provider == provider)),
    ];
    all.sort((left, right) {
      final providerOrder = left.provider.compareTo(right.provider);
      return providerOrder != 0
          ? providerOrder
          : left.symbol.compareTo(right.symbol);
    });
    _assets = List<Asset>.unmodifiable(all);
  }

  File _cacheFile(String provider) => File(
    '${_cacheDirectory.path}${Platform.pathSeparator}'
    'asset-catalog-${provider.toLowerCase()}-v1.json',
  );

  Future<void> _loadCache(String provider) async {
    try {
      final file = _cacheFile(provider);
      if (!await file.exists() || await file.length() > _cacheByteLimit) return;
      final bytes = <int>[];
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > _cacheByteLimit) return;
        bytes.addAll(chunk);
      }
      final snapshot = await Isolate.run(() => _decodeCache(provider, bytes));
      if (!_disposed && snapshot != null) _snapshots[provider] = snapshot;
    } on Object {
      // A missing or damaged cache is recoverable from the public catalog.
    }
  }

  static _CatalogSnapshot? _decodeCache(String provider, List<int> bytes) {
    final body = jsonDecode(utf8.decode(bytes));
    if (body is! Map ||
        body['version'] != 1 ||
        body['provider'] != provider ||
        body['updatedAt'] is! String) {
      return null;
    }
    final updatedAt = DateTime.tryParse(body['updatedAt'] as String)?.toUtc();
    if (updatedAt == null ||
        updatedAt.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        )) {
      return null;
    }
    final rows = body['assets'];
    if (rows is! List || rows.isEmpty || rows.length > _entryLimit) return null;
    final assets = <String, Asset>{};
    for (final row in rows) {
      if (row is! Map ||
          row['provider'] != provider ||
          row['kind'] != 'crypto') {
        return null;
      }
      final symbol = _identifier(row['symbol']);
      final currency = _identifier(row['currency']);
      final name = _label(row['name']);
      final id = '$provider:$symbol';
      if (row['id'] != id || assets.containsKey(id)) return null;
      assets[id] = Asset(
        id: id,
        provider: provider,
        symbol: symbol,
        name: name,
        kind: MarketKind.crypto,
        currency: currency,
      );
    }
    return _CatalogSnapshot(updatedAt, assets.values.toList());
  }

  Future<void> _saveCache(String provider, _CatalogSnapshot snapshot) async {
    if (_disposed) return;
    final encoded = utf8.encode(
      jsonEncode({
        'version': 1,
        'provider': provider,
        'updatedAt': snapshot.updatedAt.toIso8601String(),
        'assets': snapshot.assets.map((asset) => asset.toJson()).toList(),
      }),
    );
    if (encoded.length > _cacheByteLimit) {
      throw const SourceException('币种目录缓存超过大小上限。');
    }
    await _cacheDirectory.create(recursive: true);
    if (_disposed) return;
    final destination = _cacheFile(provider);
    final temporary = File(
      '${destination.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(encoded, flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static List<Asset> _parseCatalog(String provider, Object? body) {
    if (body is! Map ||
        (provider == 'OKX' && body['code'] != '0') ||
        (provider == 'KUCOIN' && body['code'] != '200000')) {
      throw const SourceException('交易所未返回有效的币种目录。');
    }
    final rows = body[provider == 'BINANCE' ? 'symbols' : 'data'];
    if (rows is! List || rows.length > _entryLimit) {
      throw const SourceException('币种目录格式或数量不受支持。');
    }
    final assets = <String, Asset>{};
    final knownNames = {
      for (final asset in Asset.popular) asset.id: asset.name,
    };
    for (final row in rows) {
      if (row is! Map) {
        throw const SourceException('币种目录格式不正确。');
      }
      final (online, symbolKey, baseKey, quoteKey) = switch (provider) {
        'OKX' => (
          row['instType'] == 'SPOT' && row['state'] == 'live',
          'instId',
          'baseCcy',
          'quoteCcy',
        ),
        'BINANCE' => (
          row['status'] == 'TRADING' && row['isSpotTradingAllowed'] == true,
          'symbol',
          'baseAsset',
          'quoteAsset',
        ),
        'KUCOIN' => (
          row['enableTrading'] == true,
          'symbol',
          'baseCurrency',
          'quoteCurrency',
        ),
        _ => throw const SourceException('币种目录来源不受支持。'),
      };
      if (!online) continue;
      final symbol = _identifier(row[symbolKey]);
      final base = _identifier(row[baseKey]);
      final quote = _identifier(row[quoteKey]);
      final id = '$provider:$symbol';
      assets[id] = Asset(
        id: id,
        provider: provider,
        symbol: symbol,
        name: knownNames[id] ?? base,
        kind: MarketKind.crypto,
        currency: quote,
      );
    }
    if (assets.isEmpty) {
      throw const SourceException('交易所暂未返回可用的现货交易对，已保留现有目录。');
    }
    return List<Asset>.unmodifiable(assets.values);
  }

  static String _identifier(Object? value) {
    final text = _label(value);
    // Symbols may contain non-ASCII names (supported by Binance), but cannot
    // contain separators that change the ID, path, query, or authority.
    if (text.length > 128 || RegExp(r'[\s:/\\?#@%&=;]').hasMatch(text)) {
      throw const SourceException('币种目录包含无效的交易对代码。');
    }
    return text.toUpperCase();
  }

  static String _label(Object? value) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > 160 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
      throw const SourceException('币种目录包含无效的名称或代码。');
    }
    return value.trim();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    transport.dispose();
    super.dispose();
  }
}

class _CatalogSnapshot {
  const _CatalogSnapshot(this.updatedAt, this.assets);
  final DateTime updatedAt;
  final List<Asset> assets;
}
