import 'package:cryptofloat/app/app_controller.dart';
import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/data/asset_catalog_service.dart';
import 'package:cryptofloat/data/http_transport.dart';
import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/platform/floating_window_host.dart';
import 'package:cryptofloat/platform/secret_store.dart';

class SettingsStore extends ConfigStore {
  AppConfig? saved;
  @override
  Future<void> save(AppConfig config) async => saved = config;
}

/// These settings regressions do not depend on external catalog requests.
class SettingsCatalog extends AssetCatalogService {
  SettingsCatalog() : super(transport: HttpTransport(), cacheDirectory: '.');
  @override
  Future<void> refresh({bool force = false}) async {}
}

class SettingsHost implements FloatingWindowHost {
  int drags = 0;
  List<String> fonts = ['Segoe UI', 'Consolas'];
  final List<bool> modes = [];
  @override
  bool get supported => false;
  @override
  Future<void> initialize({
    WindowBounds? bounds,
    bool alwaysOnTop = true,
    double opacity = 0.96,
  }) async {}
  @override
  Future<void> setAlwaysOnTop(bool value) async {}
  @override
  Future<void> setOpacity(double value) async {}
  @override
  Future<WindowBounds?> getBounds() async => null;
  @override
  Future<void> setBounds(WindowBounds bounds) async {}
  @override
  Future<void> beginDrag() async {
    drags++;
  }

  @override
  Future<void> beginResize(String edge) async {}
  @override
  Future<void> setSettingsMode(bool enabled) async {
    modes.add(enabled);
  }

  @override
  Future<void> close() async {}
  @override
  Future<List<String>> getSystemFonts() async => fonts;
}

class SettingsSecrets implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

AppController settingsController(
  SettingsStore store,
  SettingsHost host, {
  AppConfig? config,
}) => AppController(
  config:
      config ??
      AppConfig.defaults.copyWith(selectedAssetIds: [], proxyEnabled: false),
  store: store,
  host: host,
  secrets: SettingsSecrets(),
  assetCatalog: SettingsCatalog(),
);
