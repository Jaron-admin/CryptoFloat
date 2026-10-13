import 'dart:async';

import 'package:cryptofloat/data/http_transport.dart';
import 'package:cryptofloat/data/market_data_service.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/refresh_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

class SubscriptionRequest {
  SubscriptionRequest(this.uri);
  final Uri uri;
  final response = Completer<Object?>();
}

class SubscriptionTransport extends HttpTransport {
  final requests = <SubscriptionRequest>[];
  @override
  Future<Object?> getJson(
    Uri uri,
    AppConfig config, {
    Map<String, String> headers = const {},
  }) {
    final request = SubscriptionRequest(uri);
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
  const sources = [
    CustomApiSource(
      id: 'a',
      name: 'A',
      url: 'https://example.com/a',
      fields: [CustomField(id: 'price', label: 'A', path: 'price')],
    ),
    CustomApiSource(
      id: 'b',
      name: 'B',
      url: 'https://example.com/b',
      fields: [CustomField(id: 'price', label: 'B', path: 'price')],
    ),
    CustomApiSource(
      id: 'catalog-only',
      name: 'Unused',
      url: 'https://example.com/unused',
      fields: [CustomField(id: 'price', label: 'Unused', path: 'price')],
    ),
  ];
  final selected = AppConfig.defaults.copyWith(
    selectedAssetIds: [],
    customSources: sources,
    selectedCustomFieldIds: ['custom:a|price', 'custom:b|price'],
  );

  testWidgets(
    'catalog entries are not subscriptions and sorting keeps good quotes',
    (tester) async {
      final transport = SubscriptionTransport();
      final service = MarketDataService(
        selected,
        SettingsSecrets(),
        transport: transport,
      );
      try {
        await tester.pump();
        expect(transport.requests.map((request) => request.uri.path), [
          '/a',
          '/b',
        ]);
        for (final request in transport.requests) {
          request.response.complete({'price': 42});
        }
        await tester.pump();
        final successful = service.lastSuccessfulFetchAt;
        service.updateConfig(
          selected.copyWith(
            selectedCustomFieldIds: ['custom:b|price', 'custom:a|price'],
            displayOrder: ['field:custom:b|price', 'field:custom:a|price'],
            customSources: sources.reversed.toList(),
          ),
        );
        await tester.pump();
        expect(transport.requests.length, 2);
        expect(service.quotes['custom:a']!.price, 42);
        expect(service.quotes['custom:a']!.error, isNull);
        expect(service.lastSuccessfulFetchAt, successful);
      } finally {
        service.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'changing one source retains another pending source and generation',
    (tester) async {
      final transport = SubscriptionTransport();
      final service = MarketDataService(
        selected,
        SettingsSecrets(),
        transport: transport,
      );
      try {
        await tester.pump();
        service.updateConfig(
          selected.copyWith(
            customSources: [
              sources[0],
              CustomApiSource(
                id: 'b',
                name: 'B',
                url: 'https://example.com/new-b',
                fields: sources[1].fields,
              ),
              sources[2],
            ],
          ),
        );
        await tester.pump();
        expect(transport.requests.map((request) => request.uri.path), [
          '/a',
          '/b',
          '/new-b',
        ]);
        transport.requests[0].response.complete({'price': 10});
        transport.requests[2].response.complete({'price': 20});
        await tester.pump();
        expect(service.quotes['custom:a']!.price, 10);
        expect(service.quotes['custom:b']!.price, 20);
        transport.requests[1].response.complete({'price': 999});
        await tester.pump();
        expect(service.quotes['custom:b']!.price, 20);
      } finally {
        service.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets('each display freshness only waits for its selected source', (
    tester,
  ) async {
    final config = selected.copyWith(
      selectedCustomFieldIds: ['custom:a|price'],
      taskbar: const TaskbarConfig(
        profile: DisplayProfile(selectedCustomFieldIds: ['custom:b|price']),
      ),
    );
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      transport.requests
          .firstWhere((request) => request.uri.path == '/a')
          .response
          .complete({'price': 42});
      await tester.pump();
      expect(
        service.refreshStatusFor(DisplayTarget.floating).state,
        RefreshState.live,
      );
      expect(
        service.refreshStatusFor(DisplayTarget.taskbar).state,
        RefreshState.waiting,
      );
      expect(service.refreshStatus.state, RefreshState.waiting);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets('template-only market shared by both displays is fetched once', (
    tester,
  ) async {
    const row = DisplayRow(
      id: 'template',
      segments: [
        DisplaySegment.field(assetId: 'OKX:BTC-USDT', fieldId: 'price'),
      ],
    );
    final config = selected.copyWith(
      selectedCustomFieldIds: [],
      displayRows: [row],
      taskbar: const TaskbarConfig(profile: DisplayProfile(displayRows: [row])),
    );
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      expect(transport.requests.length, 1);
      expect(transport.requests.single.uri.host, 'www.okx.com');
      transport.requests.single.response.complete({
        'code': '0',
        'data': [
          {'last': '42', 'open24h': '40'},
        ],
      });
      await tester.pump();
      expect(service.quotes['OKX:BTC-USDT']!.price, 42);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets('taskbar currency conversion uses the shared FX cache', (
    tester,
  ) async {
    final config = AppConfig.defaults.copyWith(
      selectedAssetIds: [],
      taskbar: const TaskbarConfig(
        profile: DisplayProfile(displayCurrency: 'CNY'),
      ),
    );
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      expect(transport.requests.length, 1);
      transport.requests.single.response.complete({
        'data': {
          'currency': 'USD',
          'rates': {'USD': '1', 'CNY': '7'},
        },
      });
      await tester.pump();
      expect(service.exchangeRates['CNY'], 7);
      service.updateConfig(config.copyWith(customSources: sources));
      await tester.pump();
      expect(transport.requests.length, 1);
      expect(service.exchangeRates['CNY'], 7);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });
}
