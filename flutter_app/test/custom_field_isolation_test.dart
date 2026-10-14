import 'package:cryptofloat/data/market_data_service.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/refresh_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'display_dependencies_polling_test.dart';
import 'support/settings_fakes.dart';

void main() {
  const source = CustomApiSource(
    id: 'weather',
    name: 'Weather',
    url: 'https://example.com/weather',
    fields: [
      CustomField(id: 'temperature', label: 'Temperature', path: 'temperature'),
      CustomField(id: 'humidity', label: 'Humidity', path: 'humidity'),
      CustomField(id: 'unused', label: 'Unused', path: 'unused'),
    ],
  );
  final config = AppConfig.defaults.copyWith(
    selectedAssetIds: [],
    customSources: [source],
    selectedCustomFieldIds: ['custom:weather|temperature'],
    taskbar: const TaskbarConfig(
      profile: DisplayProfile(
        selectedCustomFieldIds: ['custom:weather|humidity'],
      ),
    ),
  );

  test('absent title uses DuoMonitor and explicit titles stay intact', () {
    expect(AppConfig.fromJson({}).headerName, 'DuoMonitor');
    expect(
      AppConfig.fromJson({
        'appearance': {'headerName': 'CryptoFloat'},
      }).headerName,
      'CryptoFloat',
    );
    expect(
      AppConfig.fromJson({
        'appearance': {'headerName': 'My title'},
      }).headerName,
      'My title',
    );
    expect(
      AppConfig.fromJson({
        'appearance': {'headerName': ''},
      }).headerName,
      '',
    );
  });

  testWidgets('unselected malformed field cannot discard selected values', (
    tester,
  ) async {
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      transport.requests.single.response.complete({
        'temperature': 42,
        'humidity': 55,
        'unused': {},
      });
      await tester.pump();
      expect(service.quotes['custom:weather']?.field('temperature'), 42);
      expect(service.quotes['custom:weather']!.fieldErrors, isEmpty);
      expect(
        service.quotes['custom:weather']!.fieldUpdatedAt.keys,
        containsAll(['temperature', 'humidity']),
      );
      expect(
        service.customFieldSuccessfulFetchAt.keys,
        containsAll(['custom:weather|temperature', 'custom:weather|humidity']),
      );
      expect(
        service.refreshStatusFor(DisplayTarget.floating).state,
        RefreshState.live,
      );
      expect(
        service.refreshStatusFor(DisplayTarget.taskbar).state,
        RefreshState.live,
      );
      expect(transport.requests.length, 1);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets('one display malformed field keeps its valid sibling live', (
    tester,
  ) async {
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      transport.requests.single.response.complete({
        'temperature': 0,
        'humidity': {},
        'unused': 7,
      });
      await tester.pump();
      expect(service.quotes['custom:weather']?.field('temperature'), 0);
      expect(
        service.quotes['custom:weather']!.isFieldStale('temperature'),
        isFalse,
      );
      expect(
        service.quotes['custom:weather']!.isFieldStale('humidity'),
        isTrue,
      );
      expect(
        service.lastSuccessfulFetchAt['field:custom:weather|humidity'],
        isNull,
      );
      expect(
        service.refreshStatusFor(DisplayTarget.floating).state,
        RefreshState.live,
      );
      expect(
        service.refreshStatusFor(DisplayTarget.taskbar).state,
        RefreshState.waiting,
      );
      expect(transport.requests.length, 1);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets('missing selected field never inherits its sibling success', (
    tester,
  ) async {
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      transport.requests.single.response.complete({
        'temperature': null,
        'humidity': false,
        'unused': 7,
      });
      await tester.pump();
      expect(
        service.refreshStatusFor(DisplayTarget.floating).state,
        RefreshState.waiting,
      );
      expect(
        service.refreshStatusFor(DisplayTarget.taskbar).state,
        RefreshState.live,
      );
      expect(service.quotes['custom:weather']?.field('humidity'), false);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets('field failure retains own last value as sibling advances', (
    tester,
  ) async {
    var clock = DateTime(2026, 10, 13, 12);
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      config,
      SettingsSecrets(),
      transport: transport,
      now: () => clock,
    );
    try {
      await tester.pump();
      transport.requests.single.response.complete({
        'temperature': 0,
        'humidity': false,
        'unused': 7,
      });
      await tester.pump();
      clock = clock.add(const Duration(seconds: 61));
      final firstTimestamp = clock.subtract(const Duration(seconds: 61));
      final refresh = service.refresh(force: true);
      await tester.pump();
      transport.requests.last.response.complete({
        'temperature': null,
        'humidity': '',
        'unused': 7,
      });
      await refresh;
      expect(service.quotes['custom:weather']?.field('temperature'), 0);
      expect(service.quotes['custom:weather']?.field('humidity'), '');
      expect(
        service.refreshStatusFor(DisplayTarget.floating).state,
        RefreshState.stale,
      );
      expect(
        service.refreshStatusFor(DisplayTarget.taskbar).state,
        RefreshState.live,
      );
      expect(transport.requests.length, 2);
      expect(
        service.lastSuccessfulFetchAt['field:custom:weather|temperature'],
        firstTimestamp,
      );
      expect(
        service.lastSuccessfulFetchAt['field:custom:weather|humidity'],
        clock,
      );
      expect(
        service.quotes['custom:weather']!.fieldUpdatedAt['temperature'],
        firstTimestamp,
      );
      expect(
        service.quotes['custom:weather']!.fieldUpdatedAt['humidity'],
        clock,
      );
      expect(
        service.quotes['custom:weather']!.isFieldStale('temperature'),
        isTrue,
      );
      expect(
        service.quotes['custom:weather']!.isFieldStale('humidity'),
        isFalse,
      );
    } finally {
      service.dispose();
      await tester.pump();
    }
  });

  testWidgets(
    'template-only custom field is parsed without malformed siblings',
    (tester) async {
      final templateConfig = config.copyWith(
        selectedCustomFieldIds: [],
        displayRows: const [
          DisplayRow(
            id: 'template',
            segments: [
              DisplaySegment.field(
                assetId: 'custom:weather',
                fieldId: 'temperature',
              ),
            ],
          ),
        ],
        taskbar: config.taskbar.copyWith(enabled: false),
      );
      final transport = SubscriptionTransport();
      final service = MarketDataService(
        templateConfig,
        SettingsSecrets(),
        transport: transport,
      );
      try {
        await tester.pump();
        transport.requests.single.response.complete({
          'temperature': 0,
          'humidity': {},
          'unused': {},
        });
        await tester.pump();
        expect(service.quotes['custom:weather']!.field('temperature'), 0);
        expect(
          service.lastSuccessfulFetchAt['field:custom:weather|temperature'],
          isNotNull,
        );
        expect(
          service.refreshStatusFor(DisplayTarget.floating).state,
          RefreshState.live,
        );
      } finally {
        service.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets('failed configured name retains its own previous text', (
    tester,
  ) async {
    final nameConfig = config.copyWith(
      customSources: const [
        CustomApiSource(
          id: 'weather',
          name: 'Source name',
          url: 'https://example.com/weather',
          fields: [CustomField(id: 'name', label: 'Name', path: 'label')],
        ),
      ],
      selectedCustomFieldIds: ['custom:weather|name'],
      taskbar: config.taskbar.copyWith(enabled: false),
    );
    final transport = SubscriptionTransport();
    final service = MarketDataService(
      nameConfig,
      SettingsSecrets(),
      transport: transport,
    );
    try {
      await tester.pump();
      transport.requests.single.response.complete({'label': 'Previous text'});
      await tester.pump();
      final refresh = service.refresh(force: true);
      await tester.pump();
      transport.requests.last.response.complete({});
      await refresh;
      expect(service.quotes['custom:weather']!.field('name'), 'Previous text');
      expect(service.quotes['custom:weather']!.isFieldStale('name'), isTrue);
    } finally {
      service.dispose();
      await tester.pump();
    }
  });
}
