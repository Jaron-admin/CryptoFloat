import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart' as f;

import 'app/app_controller.dart';
import 'app/theme.dart';
import 'app/fluent_theme.dart';
import 'data/config_store.dart';
import 'domain/models.dart';
import 'features/panel/panel_page.dart';
import 'features/settings/settings_page.dart';
import 'platform/floating_window_host.dart';
import 'platform/secret_store.dart';
import 'platform/system_fonts.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ConfigStore();
  var config = AppConfig.defaults;
  String? startupMessage;
  try {
    config = await store.load();
    startupMessage = store.loadWarning;
  } catch (_) {
    startupMessage = '设置文件无法读取，已使用默认布局。原文件仍保留。';
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
  StreamSubscription<String>? _traySubscription;

  @override
  void initState() {
    super.initState();
    _traySubscription = widget.controller.tray.actions.listen((action) {
      switch (action) {
        case 'settings':
          if (!_settings) unawaited(_showSettings(true));
        case 'refresh':
          unawaited(widget.controller.data.refresh(force: true));
        case 'exit':
          unawaited(widget.controller.close());
        // Native code restores the same view, preserving any settings draft.
        case 'show':
          break;
      }
    });
  }

  Future<void> _showSettings(bool value, [int section = 0]) async {
    if (value) await widget.controller.rememberBounds();
    widget.controller.settingsOpen = value;
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
    }
  }

  @override
  void dispose() {
    unawaited(_traySubscription?.cancel());
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final config = widget.controller.appearanceConfig;
      return MaterialApp(
        title: 'CryptoFloat',
        debugShowCheckedModeBanner: false,
        locale: config.language == 'system' ? null : Locale(config.language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          f.FluentLocalizations.delegate,
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
          return f.FluentTheme(
            data: buildFluentTheme(
              config,
              brightness: switch (config.themeMode) {
                'light' => Brightness.light,
                'dark' => Brightness.dark,
                _ => MediaQuery.platformBrightnessOf(context),
              },
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: _settings
            ? SettingsPage(
                controller: widget.controller,
                initialSection: _settingsSection,
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
