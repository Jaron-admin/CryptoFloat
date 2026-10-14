import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_controller.dart';
import 'app/theme.dart';
import 'data/config_store.dart';
import 'data/storage_location.dart';
import 'domain/models.dart';
import 'features/panel/panel_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/storage_recovery.dart';
import 'platform/floating_window_host.dart';
import 'platform/dpi_diagnostics_host.dart';
import 'platform/secret_store.dart';
import 'platform/system_fonts.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = DataRoot.resolve(
    executable: Platform.resolvedExecutable,
    operatingSystem: Platform.operatingSystem,
    environment: Platform.environment,
  );
  DataStorageMode storageMode;
  try {
    storageMode = await initializeDataStorage(root);
  } catch (_) {
    final host = FloatingWindowHost();
    try {
      await host.initialize();
      await host.setSettingsMode(true);
    } catch (_) {}
    runApp(StorageRecoveryApp(root: root, onRecovered: main));
    return;
  }
  final store = ConfigStore(directory: root.directoryFor(storageMode));
  var config = AppConfig.defaults;
  String? startupMessage;
  try {
    config = await store.load();
    startupMessage = store.loadWarning;
  } catch (_) {
    startupMessage = '设置文件无法读取，已使用默认布局。原文件仍保留。';
  }
  try {
    await store.prepare();
  } catch (_) {
    startupMessage = 'portable_directory_unwritable';
  }
  final host = FloatingWindowHost();
  try {
    await Future.wait([
      SystemFonts.ensureLoaded(config.fontFamily),
      SystemFonts.ensureLoaded(config.numberFontFamily),
    ]);
  } catch (_) {
    startupMessage = '已保存的字体无法加载，请在外观设置中重新选择字体。';
  }
  try {
    await host.initialize(
      bounds: config.windowBounds,
      alwaysOnTop: config.alwaysOnTop,
      opacity: config.opacity,
    );
  } catch (_) {
    startupMessage = '窗口设置未能应用，可继续使用并在设置中重试。';
  }
  final controller = AppController(
    config: config,
    store: store,
    host: host,
    secrets: PlatformSecretStore(),
    startupMessage: startupMessage,
    dataRoot: root,
    storageMode: storageMode,
  );
  runApp(CryptoFloatApp(controller: controller));
}

class CryptoFloatApp extends StatefulWidget {
  const CryptoFloatApp({super.key, required this.controller});
  final AppController controller;
  @override
  State<CryptoFloatApp> createState() => _CryptoFloatAppState();
}

class _CryptoFloatAppState extends State<CryptoFloatApp> {
  bool _settings = false;
  int _settingsSection = 0;
  bool _savedNoticePending = false;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _settingsCloseRequests = StreamController<void>.broadcast();
  StreamSubscription<String>? _traySubscription;
  StreamSubscription<String>? _taskbarSubscription;
  StreamSubscription<void>? _outsideClickSubscription;

  @override
  void initState() {
    super.initState();
    _outsideClickSubscription = widget.controller.tray.settingsOutsideClicks
        .listen((_) {
          if (_settings) _settingsCloseRequests.add(null);
        });
    _taskbarSubscription = widget.controller.taskbar.actions.listen((
      action,
    ) async {
      switch (action) {
        case 'settings':
          await widget.controller.tray.show();
          if (!_settings) await _showSettings(true);
        case 'show':
          await widget.controller.tray.show();
        case 'refresh':
          unawaited(widget.controller.data.refresh(force: true));
          unawaited(widget.controller.metrics.refresh());
        case 'disable':
          final config = widget.controller.config;
          try {
            await widget.controller.apply(
              config.copyWith(taskbar: config.taskbar.copyWith(enabled: false)),
            );
          } catch (_) {
            if (!_settings) await _showSettings(true);
          }
        case 'exit':
          await widget.controller.close();
      }
    });
    if (!widget.controller.config.floatingEnabled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.controller.hideToTray(),
      );
    }
    _traySubscription = widget.controller.tray.actions.listen((action) {
      switch (action) {
        case 'settings':
          if (!_settings) unawaited(_showSettings(true));
        case 'refresh':
          unawaited(widget.controller.metrics.refresh());
          unawaited(widget.controller.data.refresh(force: true));
        case 'exit':
          unawaited(widget.controller.close());
        case 'windowClose':
          if (_settings) {
            _settingsCloseRequests.add(null);
          } else {
            unawaited(widget.controller.hideToTray());
          }
        // Native code restores the same view, preserving any settings draft.
        case 'show':
          break;
      }
    });
  }

  Future<void> _showSettings(bool value, [int section = 0]) async {
    if (value) await widget.controller.rememberBounds();
    widget.controller.settingsOpen = value;
    unawaited(widget.controller.configureMonitoring());
    try {
      await widget.controller.host.setSettingsMode(value);
    } catch (_) {
      // The portable UI remains usable without a platform window adapter.
    }
    if (mounted) {
      setState(() {
        _settings = value;
        _settingsSection = section;
      });
      if (!value && _savedNoticePending) {
        _savedNoticePending = false;
        if (!widget.controller.config.floatingEnabled) {
          final language = widget.controller.config.language;
          unawaited(
            widget.controller.tray.notifySettingsSaved(
              chinese:
                  language == 'zh' ||
                  (language == 'system' &&
                      WidgetsBinding
                              .instance
                              .platformDispatcher
                              .locale
                              .languageCode ==
                          'zh'),
            ),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final messenger = _messengerKey.currentState;
            if (!mounted || messenger == null) return;
            final chinese =
                Localizations.localeOf(messenger.context).languageCode == 'zh';
            messenger.showSnackBar(
              SnackBar(
                content: Text(chinese ? '设置已保存' : 'Settings saved'),
                duration: const Duration(seconds: 2),
              ),
            );
          });
        }
      }
      if (!value && !widget.controller.config.floatingEnabled) {
        unawaited(widget.controller.hideToTray());
      }
    }
  }

  @override
  void dispose() {
    unawaited(_traySubscription?.cancel());
    unawaited(_taskbarSubscription?.cancel());
    unawaited(_outsideClickSubscription?.cancel());
    unawaited(_settingsCloseRequests.close());
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final config = widget.controller.appearanceConfig;
      return MaterialApp(
        title: 'DuoMonitor',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        locale: config.language == 'system' ? null : Locale(config.language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildAppTheme(config, brightness: Brightness.light),
        darkTheme: buildAppTheme(config, brightness: Brightness.dark),
        themeMode: switch (config.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        builder: (context, child) {
          final theme = Theme.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(
                widget.controller.menus.updateAppearance(theme, context.l10n),
              );
            }
          });
          return DpiDiagnosticsHost(
            fontSize: config.fontSize,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: _settings
            ? SettingsPage(
                controller: widget.controller,
                initialSection: _settingsSection,
                outsideClicks: _settingsCloseRequests.stream,
                onSaved: () => _savedNoticePending = true,
                onClose: () => _showSettings(false),
              )
            : PanelPage(
                controller: widget.controller,
                onSettings: (section) => _showSettings(true, section),
              ),
      );
    },
  );
}
