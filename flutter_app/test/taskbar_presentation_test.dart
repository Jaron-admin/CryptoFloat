import 'dart:convert';

import 'package:cryptofloat/domain/display_snapshot.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const eth = DisplayText(
    'ETH-USDT',
    '2,000',
    id: 'asset:OKX:ETH-USDT',
    unit: 'USDT',
    change: 2.5,
  );
  test(
    'crypto labels shorten by asset metadata while equities remain intact',
    () {
      expect(taskbarCellLabel(eth), 'ETH');
      expect(
        taskbarCellLabel(
          const DisplayText('ETHUSDT', '2000', id: 'asset:BINANCE:ETHUSDT'),
        ),
        'ETH',
      );
      const equity = Asset(
        id: 'YAHOO:BRK-B',
        provider: 'YAHOO',
        symbol: 'BRK-B',
        name: 'Berkshire',
        kind: MarketKind.equity,
        currency: 'USD',
      );
      expect(
        taskbarCellLabel(
          const DisplayText('BRK-B', '20', id: 'asset:YAHOO:BRK-B'),
          assets: [equity],
        ),
        'BRK-B',
      );
      expect(
        taskbarCellLabel(
          const DisplayText('300750.SZ', '20', id: 'asset:YAHOO:300750.SZ'),
        ),
        '300750.SZ',
      );
      expect(
        taskbarCellLabel(eth, config: const TaskbarConfig(labelMode: 'full')),
        'ETH-USDT',
      );
      expect(eth.label, 'ETH-USDT');
      expect(eth.id, 'asset:OKX:ETH-USDT');
    },
  );

  test(
    'aliases override short or full labels for assets metrics fields and rows',
    () {
      const aliases = TaskbarConfig(
        labelMode: 'full',
        labelAliases: {
          'asset:OKX:ETH-USDT': ' Ether ',
          'metric:cpu.usage': 'Proc',
          'field:custom:weather|temperature': 'Outdoor',
          'row:custom-title': 'Note',
        },
      );
      expect(taskbarCellLabel(eth, config: aliases), 'Ether');
      expect(
        taskbarCellLabel(
          const DisplayText('CPU', '10', id: 'metric:cpu.usage'),
          config: aliases,
        ),
        'Proc',
      );
      expect(
        taskbarCellLabel(
          const DisplayText(
            'Temperature',
            '20',
            id: 'field:custom:weather|temperature',
          ),
          config: aliases,
        ),
        'Outdoor',
      );
      expect(
        taskbarCellText(
          const DisplayText('', 'My text', id: 'row:custom-title'),
          showChangePercent: false,
          config: aliases,
        ),
        'Note My text',
      );
      expect(
        taskbarCellLabel(
          eth,
          config: const TaskbarConfig(
            labelAliases: {'asset:OKX:ETH-USDT': ' \n '},
          ),
        ),
        'ETH',
      );
    },
  );

  test(
    'compact cell text keeps value units percentage and full tooltip separate',
    () {
      const alias = TaskbarConfig(
        labelAliases: {'asset:OKX:ETH-USDT': 'Ether'},
      );
      expect(
        taskbarCellText(eth, showChangePercent: true, config: alias),
        'Ether 2,000 USDT +2.50%',
      );
      expect(
        taskbarCellText(eth, showChangePercent: false, config: alias),
        'Ether 2,000 USDT',
      );
      expect(
        taskbarCellTooltip(eth, chinese: false),
        'ETH-USDT 2,000 USDT +2.50%',
      );
      expect(
        taskbarCellTooltip(
          const DisplayText('CPU', '10', unit: '%', stale: true),
          chinese: false,
        ),
        'CPU 10% · Awaiting update',
      );
      expect(
        taskbarCellTooltip(
          const DisplayText('BTC', '—', change: double.nan),
          chinese: true,
        ),
        'BTC —',
      );
    },
  );

  test('native frame carries bounded layout and aliased text without source identifiers', () {
    const config = TaskbarConfig(
      itemGap: 900,
      transparentBackground: false,
      labelAliases: {'asset:OKX:ETH-USDT': 'Ether'},
      profile: DisplayProfile(showChangePercent: false),
    );
    final frame = buildTaskbarFrame(
      config: config,
      chinese: false,
      cells: [eth],
      background: 0xff001122,
      foreground: 0xffaabbcc,
      colorFor: (_) => 0xff123456,
    );
    expect(frame['transparentBackground'], false);
    expect(frame['itemGap'], 24);
    expect(frame['background'], 0xff001122);
    expect(frame['cells'], [
      {
        'text': 'Ether 2,000 USDT',
        'tooltip': 'ETH-USDT 2,000 USDT +2.50%',
        'color': 0xff123456,
        'label': 'Ether',
        'value': '2,000 USDT',
        'suffix': '',
        'suffixColor': 0xffaabbcc,
      },
    ]);
    expect(jsonEncode(frame), isNot(contains('asset:OKX:ETH-USDT')));
    final defaults = buildTaskbarFrame(
      config: const TaskbarConfig(),
      chinese: true,
      cells: [],
      background: 0,
      foreground: 0,
    );
    expect(defaults['transparentBackground'], true);
    expect(defaults['itemGap'], 6);
  });

  test(
    'legacy taskbar config gains compact defaults without dropping its profile',
    () {
      final old = {
        'enabled': false,
        'width': 420,
        'lineCount': 1,
        'profile': const DisplayProfile(
          selectedAssetIds: ['OKX:ETH-USDT'],
          selectedCustomFieldIds: ['custom:weather|temperature'],
          fontSize: 14,
        ).toJson(),
      };
      final restored = TaskbarConfig.fromJson(old).toJson();
      expect(restored['labelMode'], 'short');
      expect(restored['labelAliases'], isEmpty);
      expect(restored['itemGap'], 6);
      expect(restored['transparentBackground'], true);
      for (final key in old.keys) {
        expect(restored[key], old[key]);
      }
    },
  );

  test('taskbar labels spacing and transparency survive serialized reload', () {
    final input = {
      'labelMode': 'full',
      'labelAliases': {
        'asset:OKX:ETH-USDT': 'Ethereum',
        'metric:cpu.usage': 'Processor',
        'field:custom:weather|temperature': 'Outdoors',
      },
      'itemGap': 3,
      'transparentBackground': false,
    };
    final original = TaskbarConfig.fromJson(input);
    final roundTrip = TaskbarConfig.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    ).toJson();
    for (final key in input.keys) {
      expect(roundTrip[key], input[key]);
    }
  });

  test(
    'invalid presentation values are bounded and aliases stay plain text',
    () {
      final restored = TaskbarConfig.fromJson({
        'labelMode': 'unsupported',
        'itemGap': 900,
        'transparentBackground': 'yes',
        'labelAliases': {
          'metric:cpu.usage': '  CPU\n\t load\u0000 ',
          'field:custom:a|b': ' ',
          '': 'empty key',
          5: 'not a string key',
          'row:x': 42,
        },
      }).toJson();
      expect(restored['labelMode'], 'short');
      expect(restored['itemGap'], 24);
      expect(restored['transparentBackground'], true);
      expect(restored['labelAliases'], {'metric:cpu.usage': 'CPU load'});
      expect(TaskbarConfig.fromJson({'itemGap': -2}).toJson()['itemGap'], 0);
      expect(
        TaskbarConfig.fromJson({'itemGap': double.nan}).toJson()['itemGap'],
        6,
      );
      expect(
        TaskbarConfig.fromJson({'itemGap': double.infinity})
            .toJson()['itemGap'],
        6,
      );
      expect(TaskbarConfig.fromJson({'itemGap': 5.8}).toJson()['itemGap'], 5);
    },
  );

  test(
    'taskbar presentation edit keeps floating selection and text independent',
    () {
      final original = AppConfig.defaults.copyWith(
        selectedAssetIds: ['OKX:BTC-USDT'],
        headerName: 'Floating title',
      );
      final nextTaskbar = TaskbarConfig.fromJson({
        ...original.taskbar.toJson(),
        'labelAliases': {'asset:OKX:ETH-USDT': 'Ether'},
        'itemGap': 2,
        'transparentBackground': false,
        'profile': const DisplayProfile(selectedAssetIds: ['OKX:ETH-USDT'])
            .toJson(),
      });
      final edited = original.withDisplay(
        DisplayTarget.taskbar,
        original
            .displayFor(DisplayTarget.taskbar)
            .copyWith(taskbar: nextTaskbar),
      );
      expect(edited.selectedAssetIds, original.selectedAssetIds);
      expect(edited.headerName, 'Floating title');
      expect(edited.taskbar.toJson()['labelAliases'], {
        'asset:OKX:ETH-USDT': 'Ether',
      });
      expect(edited.taskbar.toJson()['itemGap'], 2);
      expect(
        AppConfig.fromJson(edited.toJson()).taskbar.toJson(),
        edited.taskbar.toJson(),
      );
      expect(
        const DisplayText('ETH-USDT', '2000', id: 'asset:OKX:ETH-USDT').label,
        'ETH-USDT',
      );
    },
  );
}
