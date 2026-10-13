import 'dart:async';

import 'package:cryptofloat/domain/refresh_status.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/data/http_transport.dart';
import 'package:cryptofloat/data/market_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

class ControlledTransport extends HttpTransport {
  Object? document = {'price': 42};
  bool failing = false;

  @override
  Future<Object?> getJson(
    Uri uri,
    AppConfig config, {
    Map<String, String> headers = const {},
  }) async {
    if (failing) throw const SourceException('Controlled unavailable source');
    return document;
  }
}

class PendingRequest {
  PendingRequest(this.uri, this.config);
  final Uri uri;
  final AppConfig config;
  final response = Completer<Object?>();
}

class DeferredTransport extends HttpTransport {
  final requests = <PendingRequest>[];

  @override
  Future<Object?> getJson(
    Uri uri,
    AppConfig config, {
    Map<String, String> headers = const {},
  }) {
    final request = PendingRequest(uri, config);
    requests.add(request);
    return request.response.future;
  }

  @override
  void dispose() {
    for (final request in requests) {
      if (!request.response.isCompleted) request.response.complete({});
    }
    super.dispose();
  }
}

void main() {
  final now = DateTime(2026, 10, 2, 12);
  RefreshStatus status(
    Map<String, int> intervals,
    Map<String, DateTime> success,
  ) => calculateRefreshStatus(
    now: now,
    sourceIntervals: intervals,
    lastSuccessfulFetchAt: success,
  );

  test('no sources has no fabricated last update', () {
    final result = status({}, {'removed': now});
    expect(result.state, RefreshState.noSources);
    expect(result.lastUpdatedAt, isNull);
    expect(result.intervalsSeconds, isEmpty);
  });

  test('a source without first success cannot report live', () {
    final result = status({'crypto': 15, 'stock': 60}, {'crypto': now});
    expect(result.state, RefreshState.waiting);
    expect(result.waitingSourceCount, 1);
  });

  test('each source uses its own interval and the boundary stays live', () {
    final result = status(
      {'crypto': 15, 'stock': 60, 'custom': 120},
      {
        'crypto': now.subtract(const Duration(seconds: 15)),
        'stock': now.subtract(const Duration(seconds: 59)),
        'custom': now.subtract(const Duration(seconds: 119)),
      },
    );
    expect(result.isLive, isTrue);
    expect(result.intervalsSeconds, [15, 60, 120]);
    expect(result.lastUpdatedAt, now.subtract(const Duration(seconds: 119)));
  });

  test('one overdue source makes the global status stale', () {
    final result = status(
      {'crypto': 15, 'stock': 60},
      {'crypto': now, 'stock': now.subtract(const Duration(seconds: 61))},
    );
    expect(result.state, RefreshState.stale);
    expect(result.staleSourceCount, 1);
  });

  test('epoch placeholder and future time never count as successful data', () {
    final result = status(
      {'first': 15, 'future': 60},
      {
        'first': DateTime.fromMillisecondsSinceEpoch(0),
        'future': now.add(const Duration(seconds: 1)),
      },
    );
    expect(result.state, RefreshState.waiting);
    expect(result.lastUpdatedAt, isNull);
  });

  final customConfig = AppConfig.defaults.copyWith(
    selectedAssetIds: [],
    selectedCustomFieldIds: ['custom:metrics|price'],
    customSources: const [
      CustomApiSource(
        id: 'metrics',
        name: 'Metrics',
        url: 'https://example.com/metrics',
        refreshSeconds: 60,
        fields: [CustomField(id: 'price', label: 'Value', path: 'price')],
      ),
    ],
  );

  AppConfig changedSource(AppConfig config) => config.copyWith(
    customSources: const [
      CustomApiSource(
        id: 'metrics',
        name: 'New metrics',
        url: 'https://example.com/new-metrics',
        refreshSeconds: 60,
        fields: [CustomField(id: 'price', label: 'Value', path: 'price')],
      ),
    ],
  );

  testWidgets(
    'new configuration can publish while the previous request is pending',
    (tester) async {
      var clock = now;
      final transport = DeferredTransport();
      final service = MarketDataService(
        customConfig,
        SettingsSecrets(),
        transport: transport,
        now: () => clock,
      );
      try {
        await tester.pump();
        service.updateConfig(changedSource(customConfig));
        await tester.pump();
        expect(transport.requests.length, 2);
        expect(transport.requests[1].uri.path, '/new-metrics');
        clock = now.add(const Duration(seconds: 2));
        transport.requests[1].response.complete({'price': 84});
        await tester.pump();
        expect(transport.requests[0].response.isCompleted, isFalse);
        expect(service.quotes['custom:metrics']!.price, 84);
        expect(service.lastSuccessfulFetchAt['custom:metrics'], clock);
        final newTimestamp = clock;
        clock = now.add(const Duration(seconds: 5));
        transport.requests[0].response.complete({'price': 21});
        await tester.pump();
        expect(service.quotes['custom:metrics']!.price, 84);
        expect(service.lastSuccessfulFetchAt['custom:metrics'], newTimestamp);
      } finally {
        service.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'old request completion cannot remove a new same-key pending task',
    (tester) async {
      final transport = DeferredTransport();
      final service = MarketDataService(
        customConfig,
        SettingsSecrets(),
        transport: transport,
        now: () => now,
      );
      try {
        await tester.pump();
        service.updateConfig(changedSource(customConfig));
        await tester.pump();
        expect(transport.requests.length, 2);
        transport.requests[0].response.complete({'price': 21});
        await tester.pump();
        expect(service.refreshing, isTrue);
        expect(service.lastSuccessfulFetchAt, isEmpty);
        final forced = service.refresh(force: true);
        await tester.pump();
        expect(transport.requests.length, 2);
        transport.requests[1].response.complete({'price': 84});
        await forced;
        expect(service.quotes['custom:metrics']!.price, 84);
        expect(service.refreshing, isFalse);
      } finally {
        service.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets('unrelated catalog edit keeps the current shared FX request', (
    tester,
  ) async {
    var clock = now;
    final transport = DeferredTransport();
    final config = AppConfig.defaults.copyWith(
      selectedAssetIds: [],
      displayCurrency: 'CNY',
      proxyEnabled: false,
    );
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
      now: () => clock,
    );
    Object document(String rate) => {
      'data': {
        'currency': 'USD',
        'rates': {'USD': '1', 'CNY': rate},
      },
    };
    try {
      await tester.pump();
      service.updateConfig(
        config.copyWith(
          customSources: [
            const CustomApiSource(
              id: 'inactive',
              name: '备用来源',
              url: 'https://example.com/data',
              fields: [],
              enabled: false,
            ),
          ],
        ),
      );
      await tester.pump();
      expect(transport.requests.length, 1);
      final forced = service.refresh(force: true);
      await tester.pump();
      expect(transport.requests.length, 1);
      clock = now.add(const Duration(seconds: 2));
      transport.requests[0].response.complete(document('7'));
      await forced;
      expect(service.exchangeRates['CNY'], 7);
      expect(service.ratesFetchedAt, clock);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets(
    'successful fetch survives brief failure and ages without idle notifications',
    (tester) async {
      var clock = now;
      final transport = ControlledTransport();
      final service = MarketDataService(
        customConfig,
        SettingsSecrets(),
        transport: transport,
        now: () => clock,
      );
      try {
        await service.refresh();
        expect(service.lastSuccessfulFetchAt['custom:metrics'], now);
        expect(service.quotes['custom:metrics']!.price, 42);
        var notifications = 0;
        var sawStale = false;
        service.addListener(() {
          notifications++;
          sawStale =
              sawStale || service.refreshStatus.state == RefreshState.stale;
        });
        await tester.pump(const Duration(seconds: 2));
        expect(notifications, 0);
        clock = now.add(const Duration(seconds: 5));
        transport.failing = true;
        await service.refresh(force: true);
        expect(service.refreshStatus.isLive, isTrue);
        expect(service.lastSuccessfulFetchAt['custom:metrics'], now);
        expect(service.quotes['custom:metrics']!.price, 42);
        clock = now.add(const Duration(seconds: 61));
        await tester.pump(const Duration(seconds: 1));
        expect(sawStale, isTrue);
      } finally {
        service.dispose();
      }
    },
  );

  testWidgets('all null custom fields do not create a successful update', (
    tester,
  ) async {
    final transport = ControlledTransport()..document = {'price': null};
    final service = MarketDataService(
      customConfig,
      SettingsSecrets(),
      transport: transport,
      now: () => now,
    );
    try {
      await service.refresh();
      expect(service.lastSuccessfulFetchAt, isEmpty);
      expect(service.refreshStatus.state, RefreshState.waiting);
    } finally {
      service.dispose();
    }
  });

  testWidgets(
    'expired failed FX refresh preserves cache but disables conversion',
    (tester) async {
      var clock = now;
      final transport = ControlledTransport()
        ..document = {
          'data': {
            'currency': 'USD',
            'rates': {'USD': '1', 'CNY': '7', 'USDT': '1.002'},
          },
        };
      final service = MarketDataService(
        AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          displayCurrency: 'CNY',
        ),
        SettingsSecrets(),
        transport: transport,
        now: () => clock,
      );
      try {
        await service.refresh();
        expect(service.exchangeRates['CNY'], 7);
        expect(service.ratesFetchedAt, now);
        transport.failing = true;
        clock = now.add(const Duration(seconds: 301));
        await service.refresh();
        expect(service.exchangeRates, isEmpty);
        expect(service.cachedExchangeRates['CNY'], 7);
        expect(service.ratesFetchedAt, now);
        expect(service.ratesError, isNotNull);
      } finally {
        service.dispose();
      }
    },
  );
}
