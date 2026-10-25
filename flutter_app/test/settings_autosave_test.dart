import 'dart:async';

import 'package:cryptofloat/app/theme.dart';
import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/features/settings/settings_page.dart';
import 'package:cryptofloat/features/settings/source_editor.dart';
import 'package:cryptofloat/platform/secret_store.dart';
import 'package:cryptofloat/main.dart';
import 'package:cryptofloat/l10n/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_fakes.dart';
import 'support/settings_navigation.dart';

class _Store extends SettingsStore {
  bool fail = false;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<void> save(AppConfig config) async {
    writes++;
    await gate?.future;
    if (fail) throw const FormatException('portable_directory_unwritable');
    await super.save(config);
  }
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('panel-title')),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('设置…'));
  await tester.pumpAndSettle();
}

Future<void> changeFont(
  WidgetTester tester, [
  String family = 'Consolas',
]) async {
  await tester.tap(find.text('外观').first);
  await tester.pumpAndSettle();
  final choose = settingsFontPicker(numbers: true);
  await revealSetting(tester, choose);
  await tester.tap(choose);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(family)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'manual save blocks keyboard edits until it completes (failure=$fail)',
      (tester) async {
        final gate = Completer<void>();
        final store = _Store()
          ..gate = gate
          ..fail = fail;
        final controller = settingsController(
          store,
          SettingsHost(),
          config: AppConfig.defaults.copyWith(
            selectedAssetIds: [],
            language: 'zh',
          ),
        );
        final name = find.byKey(const ValueKey('header-name'));
        final editableName = find.descendant(
          of: name,
          matching: find.byType(EditableText),
        );
        Future<bool> tabToName() async {
          for (var i = 0; i < 120; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            if (tester.widget<EditableText>(editableName).focusNode.hasFocus) {
              return true;
            }
          }
          return false;
        }

        try {
          await tester.pumpWidget(CryptoFloatApp(controller: controller));
          await tester.pumpAndSettle();
          await openSettings(tester);
          await tester.tap(find.text('外观').first);
          await tester.pumpAndSettle();
          await revealSetting(tester, name);
          await tester.enterText(name, 'Committed name');
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('settings-save')));
          await tester.pump();
          expect(store.writes, 1);

          final focusedDuringSave = await tabToName();
          if (focusedDuringSave) {
            tester.testTextInput.enterText('Input during save');
            await tester.pump();
          }
          expect(
            focusedDuringSave,
            isFalse,
            reason: 'Tab must not reopen an editable field during a commit.',
          );
          expect(controller.appearanceConfig.headerName, 'Committed name');

          gate.complete();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          expect(store.saved?.headerName, fail ? isNull : 'Committed name');
          if (fail) expect(find.textContaining('保存失败'), findsOneWidget);

          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          expect(await tabToName(), isTrue);
          tester.testTextInput.enterText('Next draft');
          await tester.pump();
          expect(controller.appearanceConfig.headerName, 'Next draft');
          store.fail = false;
          await tester.tap(find.byKey(const ValueKey('settings-save')));
          await tester.pumpAndSettle();
          expect(store.saved?.headerName, 'Next draft');
          expect(store.writes, 2);
        } finally {
          if (!gate.isCompleted) gate.complete();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }

  testWidgets('manual save stays open and later edits still autosave', (
    tester,
  ) async {
    final store = _Store();
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await changeFont(tester);
    expect(find.text('放弃更改'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-save')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(store.saved?.numberFontFamily, 'Consolas');
    expect(store.writes, 1);
    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('设置已保存'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('settings-save')))
          .onPressed,
      isNull,
    );
    await changeFont(tester, 'Segoe UI');
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(store.writes, 2);
    expect(store.saved?.numberFontFamily, 'Segoe UI');
    expect(find.byType(SettingsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final fail in [false, true]) {
    testWidgets('outside close waits for manual save (failure=$fail)', (
      tester,
    ) async {
      final outside = StreamController<void>.broadcast();
      final store = _Store()
        ..gate = Completer<void>()
        ..fail = fail;
      final controller = settingsController(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'zh',
        ),
      );
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          theme: buildAppTheme(controller.config, brightness: Brightness.light),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsPage(
            controller: controller,
            initialSection: 1,
            outsideClicks: outside.stream,
            onClose: () => closes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await changeFont(tester);
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pump();
      expect(store.writes, 1);
      outside.add(null);
      outside.add(null);
      await tester.pump();
      expect(closes, 0);
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(closes, fail ? 0 : 1);
      expect(store.writes, 1);
      if (fail) {
        expect(find.textContaining('保存失败'), findsOneWidget);
        expect(controller.appearanceConfig.numberFontFamily, 'Consolas');
        store.fail = false;
        await tester.tap(find.byKey(const ValueKey('settings-save')));
        await tester.pumpAndSettle();
        expect(closes, 0);
        expect(store.saved?.numberFontFamily, 'Consolas');
        outside.add(null);
        await tester.pumpAndSettle();
        expect(closes, 1);
        expect(store.writes, 2);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await outside.close();
    });
  }

  testWidgets(
    'native close leaves settings or hides panel; explicit exit quits',
    (tester) async {
      final calls = <String>[];
      const channel = MethodChannel('cryptofloat/platform');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'window.getFontData') throw MissingPluginException();
        return call.method == 'window.hideToTray' ? true : null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final store = _Store()..fail = true;
      final host = _CloseHost();
      final controller = settingsController(
        store,
        host,
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'zh',
        ),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      Future<void> action(String action) async {
        final reply = Completer<void>();
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'cryptofloat/platform',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('tray.action', action),
          ),
          (_) => reply.complete(),
        );
        await reply.future;
        await tester.pumpAndSettle();
      }

      await action('settings');
      await changeFont(tester);
      await action('windowClose');
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.textContaining('保存失败'), findsOneWidget);
      expect(host.closes, 0);
      store.fail = false;
      await action('windowClose');
      expect(find.byType(SettingsPage), findsNothing);
      expect(store.saved?.numberFontFamily, 'Consolas');
      expect(host.closes, 0);
      calls.clear();
      await action('windowClose');
      expect(calls, contains('window.hideToTray'));
      expect(host.closes, 0);
      await action('exit');
      expect(host.closes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'manual save deletes old secrets only after commit and preserves the new reference',
    (tester) async {
      CustomApiSource source(String key) => CustomApiSource(
        id: 'example',
        name: 'Example API',
        url: 'https://example.com/data',
        enabled: false,
        secretHeaderRefs: {'Authorization': key},
        fields: const [CustomField(id: 'value', label: 'Value', path: 'value')],
      );
      final store = _Store()..fail = true;
      final secrets = _RecordingSecrets(store);
      final controller = AppController(
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'zh',
          customSources: [source('old')],
        ),
        store: store,
        host: SettingsHost(),
        secrets: secrets,
        assetCatalog: SettingsCatalog(),
      );
      await tester.pumpWidget(CryptoFloatApp(controller: controller));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.text('显示').first);
      await tester.pumpAndSettle();
      final edit = find.byTooltip('编辑').first;
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      // Model the editor's completed result; this test owns the settings commit,
      // not secure storage I/O or the source editor's individual form fields.
      Navigator.of(tester.element(find.byType(SourceEditor)))
          .pop(SourceEditResult(source('new'), {'new', 'unused'}));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(secrets.deleted, isEmpty);
      expect(
        controller
            .config
            .customSources
            .single
            .secretHeaderRefs['Authorization'],
        'old',
      );
      store.fail = false;
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(secrets.deleted, unorderedEquals(['old', 'unused']));
      expect(secrets.deletedBeforeCommit, false);
      expect(
        controller
            .config
            .customSources
            .single
            .secretHeaderRefs['Authorization'],
        'new',
      );
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.tap(find.byTooltip('返回悬浮窗'));
      await tester.pumpAndSettle();
      expect(store.writes, 2);
      expect(secrets.deleted, isNot(contains('new')));
      expect(find.text('设置已保存'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'outside clicks ignore active editor then save after editor closes',
    (tester) async {
      final outside = StreamController<void>.broadcast();
      final store = _Store();
      final controller = settingsController(
        store,
        SettingsHost(),
        config: AppConfig.defaults.copyWith(
          selectedAssetIds: [],
          language: 'zh',
        ),
      );
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          theme: buildAppTheme(controller.config, brightness: Brightness.light),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsPage(
            controller: controller,
            initialSection: 1,
            outsideClicks: outside.stream,
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choose = settingsFontPicker(numbers: true);
      await revealSetting(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      outside.add(null);
      await tester.pumpAndSettle();
      expect(closed, false);
      expect(store.writes, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Consolas'));
      await tester.pumpAndSettle();
      // Losing focus alone does not generate an outside-click event.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(closed, false);
      outside.add(null);
      outside.add(null);
      await tester.pumpAndSettle();
      expect(closed, true);
      expect(store.writes, 1);
      expect(store.saved?.numberFontFamily, 'Consolas');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await outside.close();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('unchanged settings close without another write', (tester) async {
    final store = _Store();
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    expect(find.byType(SettingsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing settings saves once and briefly confirms success', (
    tester,
  ) async {
    final store = _Store();
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('保存并返回'), findsNothing);
    await changeFont(tester);
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(store.saved?.numberFontFamily, 'Consolas');
    expect(store.writes, 1);
    expect(find.text('设置已保存'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('设置已保存'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('save failure retains draft and retry succeeds', (tester) async {
    final store = _Store()..fail = true;
    final controller = settingsController(
      store,
      SettingsHost(),
      config: AppConfig.defaults.copyWith(selectedAssetIds: [], language: 'zh'),
    );
    await tester.pumpWidget(CryptoFloatApp(controller: controller));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await changeFont(tester);
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(store.saved, isNull);
    expect(controller.appearanceConfig.numberFontFamily, 'Consolas');
    store.fail = false;
    await tester.tap(find.byTooltip('返回悬浮窗'));
    await tester.pumpAndSettle();
    expect(store.saved?.numberFontFamily, 'Consolas');
    expect(find.byType(SettingsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _CloseHost extends SettingsHost {
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
  }
}

class _RecordingSecrets implements SecretStore {
  _RecordingSecrets(this.store);
  final SettingsStore store;
  final deleted = <String>[];
  bool deletedBeforeCommit = false;
  @override
  Future<String?> read(String key) async => 'synthetic';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {
    if (store.saved == null) deletedBeforeCommit = true;
    deleted.add(key);
  }
}
