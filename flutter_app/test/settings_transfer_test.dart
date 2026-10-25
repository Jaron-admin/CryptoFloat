import 'dart:async';
import 'dart:convert';

import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/data/config_transfer.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/fluent_controls.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';

class _Files extends FileSelectorPlatform {
  Completer<XFile?>? _result;
  Completer<XFile?> get result => _result ??= Completer<XFile?>();
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) => result.future;
}

class _MemoryFile extends XFile {
  _MemoryFile(this.text) : super('memory.json');
  final String text;
  @override
  Future<int> length() async => utf8.encode(text).length;
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => text;
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byKey(const ValueKey('settings-more')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

Future<AppController> _open(
  WidgetTester tester,
  SettingsStore store, {
  AppConfig? config,
  Stream<void>? outside,
  VoidCallback? onClose,
  int section = 0,
}) async {
  tester.view.physicalSize = const Size(1100, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = settingsController(
    store,
    SettingsHost(),
    config: config ?? AppConfig.defaults.copyWith(language: 'en'),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(controller.config),
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(
        controller: controller,
        onClose: onClose ?? () {},
        outsideClicks: outside,
        initialSection: section,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  late FileSelectorPlatform original;
  late _Files files;
  setUp(() {
    original = FileSelectorPlatform.instance;
    files = _Files();
    FileSelectorPlatform.instance = files;
  });
  tearDown(() => FileSelectorPlatform.instance = original);

  testWidgets(
    'file picker owns draft until canceled and then releases close guard',
    (tester) async {
      final outside = StreamController<void>();
      addTearDown(outside.close);
      var closes = 0;
      final store = SettingsStore();
      final controller = await _open(
        tester,
        store,
        outside: outside.stream,
        onClose: () => closes++,
      );
      await _menu(tester, 'Import settings…');
      outside.add(null);
      await tester.pumpAndSettle();
      expect(closes, 0);
      expect(store.saved, isNull);
      files.result.complete(null);
      await tester.pumpAndSettle();
      outside.add(null);
      await tester.pumpAndSettle();
      expect(closes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'invalid import preserves the unsaved draft and can still save it',
    (tester) async {
      final store = SettingsStore();
      final controller = await _open(tester, store);
      tester
          .widget<FDropdown<String>>(find.byKey(const ValueKey('language-en')))
          .onChanged!('zh');
      await tester.pumpAndSettle();
      final malformed = AppConfig.defaults.toJson();
      (malformed['appearance'] as Map)['fontSize'] = 'invalid';
      files.result.complete(_MemoryFile(jsonEncode(malformed)));
      await _menu(tester, 'Import settings…');
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(store.saved?.language, 'zh');
      expect(store.saved?.fontSize, 15);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'successful shared import restores both displays and keeps local settings',
    (tester) async {
      final store = SettingsStore();
      final controller = await _open(
        tester,
        store,
        config: AppConfig.defaults.copyWith(
          language: 'en',
          headerImagePath: 'icons/keep-local.png',
          proxyHost: 'local-proxy',
          systemMonitor: const SystemMonitorSettings(
            networkAdapterId: 'local-adapter',
          ),
          taskbar: AppConfig.defaults.taskbar.copyWith(
            profile: DisplayProfile.taskbarDefaults.copyWith(
              headerImagePath: 'icons/taskbar-local.png',
            ),
          ),
        ),
      );
      final shared = exportSettings(
        AppConfig.defaults.copyWith(
          language: 'en',
          fontSize: 27,
          taskbar: AppConfig.defaults.taskbar.copyWith(
            profile: DisplayProfile.taskbarDefaults.copyWith(fontSize: 18),
          ),
        ),
      );
      files.result.complete(_MemoryFile(jsonEncode(shared.json)));
      await _menu(tester, 'Import settings…');
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(store.saved?.fontSize, 27);
      expect(store.saved?.taskbar.profile.fontSize, 18);
      expect(store.saved?.headerImagePath, 'icons/keep-local.png');
      expect(
        store.saved?.taskbar.profile.headerImagePath,
        'icons/taskbar-local.png',
      );
      expect(store.saved?.proxyHost, 'local-proxy');
      expect(store.saved?.systemMonitor.networkAdapterId, 'local-adapter');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'reset refreshes target and removes visible taskbar alias draft',
    (tester) async {
      final store = SettingsStore();
      final controller = await _open(
        tester,
        store,
        section: 2,
        config: AppConfig.defaults.copyWith(
          language: 'en',
          taskbar: AppConfig.defaults.taskbar.copyWith(
            labelAliases: {'metric:cpu.usage': 'Private CPU'},
          ),
        ),
      );
      final target = find.byKey(const ValueKey('display-target-selector'));
      tester.widget<SegmentedButton<DisplayTarget>>(target).onSelectionChanged!(
        {DisplayTarget.taskbar},
      );
      await tester.pumpAndSettle();
      final aliases = find.byKey(const ValueKey('taskbar-aliases'));
      await tester.ensureVisible(aliases);
      await tester.tap(aliases);
      await tester.pumpAndSettle();
      expect(find.text('Private CPU'), findsWidgets);
      await _menu(tester, 'Reset everything…');
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<DisplayTarget>>(target).selected, {
        DisplayTarget.floating,
      });
      tester.widget<SegmentedButton<DisplayTarget>>(target).onSelectionChanged!(
        {DisplayTarget.taskbar},
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(aliases);
      await tester.tap(aliases);
      await tester.pumpAndSettle();
      expect(find.text('Private CPU'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(store.saved?.taskbar.labelAliases, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
