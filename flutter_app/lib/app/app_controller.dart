import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../data/config_store.dart';
import '../data/storage_location.dart';
import '../domain/refresh_price.dart';
import '../data/asset_catalog_service.dart';
import '../data/http_transport.dart';
import '../data/market_data_service.dart';
import '../data/system_metrics_service.dart';
import '../domain/display_snapshot.dart';
import '../domain/refresh_status.dart';
import '../domain/models.dart';
import '../platform/taskbar_host.dart';
import 'theme_presets.dart';
import 'market_change_colors.dart';
import '../platform/floating_window_host.dart';
import '../platform/secret_store.dart';
import '../platform/system_proxy.dart';
import '../platform/tray_host.dart';
import '../platform/context_menu_host.dart';

class AppController extends ChangeNotifier {
  AppController({
    required AppConfig config,
    required this.store,
    required this.host,
    required this.secrets,
    this.startupMessage,
    AssetCatalogService? assetCatalog,
    this.dataRoot,
    this.storageMode = DataStorageMode.portable,
  }) : _config = config {
    catalog =
        assetCatalog ??
        AssetCatalogService(
          transport: HttpTransport(
            systemProxyResolver: PlatformSystemProxyResolver(),
          ),
          cacheDirectory: File(store.configPath).parent.path,
        );
    catalog.addListener(notifyListeners);
    data = MarketDataService(
      config,
      secrets,
      systemProxyResolver: PlatformSystemProxyResolver(),
    )..addListener(_onData);
    metrics.addListener(_metricsChanged);
    taskbar.addListener(notifyListeners);
    unawaited(configureMonitoring());
    if (taskbar.supported) {
      _taskbarTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(publishTaskbar()),
      );
      unawaited(publishTaskbar());
    }
    unawaited(data.refresh(force: true));
    _boundsTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(rememberBounds()),
    );
  }
  final ConfigStore store;
  final DataRoot? dataRoot;
  DataStorageMode storageMode;
  RefreshPriceMemory _prices = const RefreshPriceMemory();
  PriceTick priceTickFor(String assetId) => _prices.tickFor(assetId);

  void rememberQuotes(Map<String, MarketQuote> quotes) {
    final next = _prices.observeAll(quotes);
    if (identical(next, _prices)) return;
    _prices = next;
    if (!_disposed) notifyListeners();
  }

  void _onData() {
    if (_disposed) return;
    _prices = _prices.observeAll(data.quotes);
    notifyListeners();
  }

  Future<void> switchStorage(
    DataStorageMode mode, {
    required bool migrate,
  }) async {
    final root = dataRoot;
    if (root == null) throw const FormatException('storage_mode_unwritable');
    final directory = await migrateDataStorage(
      root: root,
      from: storageMode,
      to: mode,
      migrate: migrate,
    );
    store.useDirectory(directory);
    storageMode = mode;
    if (!_disposed) notifyListeners();
  }
  final FloatingWindowHost host;
  final SecretStore secrets;
  final TrayHost tray = TrayHost();
  final ContextMenuHost menus = ContextMenuHost();
  final SystemMetricsService metrics = SystemMetricsService();
  final TaskbarHost taskbar = TaskbarHost();
  late final MarketDataService data;
  late final AssetCatalogService catalog;
  AppConfig _config;
  AppConfig get config => _config;
  AppConfig? _appearancePreview;
  AppConfig get appearanceConfig => _appearancePreview ?? _config;

  void previewAppearance(AppConfig value) {
    _appearancePreview = value;
    notifyListeners();
  }

  void clearAppearancePreview() {
    if (_appearancePreview == null) return;
    _appearancePreview = null;
    notifyListeners();
  }

  String? startupMessage;
  bool settingsOpen = false;
  Future<bool> Function()? beforeExit;
  bool _saving = false;
  bool _disposed = false;
  Timer? _boundsTimer;
  Timer? _taskbarTimer;

  Map<String, MarketQuote> get displayQuotes => withSystemQuote(
    data.quotes,
    metrics.snapshot,
    _config.systemMonitor.intervalSeconds,
  );

  RefreshStatus refreshStatusFor(AppConfig view) =>
      displayRefreshStatus(view, data.lastSuccessfulFetchAt, metrics.snapshot);

  void _metricsChanged() {
    if (_disposed) return;
    notifyListeners();
    unawaited(publishTaskbar());
  }

  Future<void> configureMonitoring() => metrics.configure(
    enabled:
        settingsOpen ||
        DisplayDependencies.forConfig(_config).metricIds.isNotEmpty,
    intervalSeconds: _config.systemMonitor.intervalSeconds,
    networkAdapterId: _config.systemMonitor.networkAdapterId,
    gpuAdapterId: _config.systemMonitor.gpuAdapterId,
    diskId: _config.systemMonitor.diskId,
  );

  Future<void> publishTaskbar() async {
    if (_disposed || !taskbar.supported) return;
    final view = _config.displayFor(DisplayTarget.taskbar);
    final brightness = switch (view.themeMode) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    final palette = resolveAppPalette(view, brightness: brightness);
    Color cellColor(DisplayText cell) {
      final assetId = cell.id.startsWith('asset:')
          ? cell.id.substring('asset:'.length)
          : '';
      return taskbarPriceColor(
        cellId: cell.id,
        stale: cell.stale,
        priceColorMode: _config.priceColorMode,
        tick: _prices.tickFor(assetId),
        foreground: palette.foreground,
        secondary: palette.secondary,
        brightness: brightness,
        themeColors: MarketColors(
          positive: palette.positive,
          negative: palette.negative,
        ),
      );
    }

    final chinese =
        _config.language == 'zh' ||
        (_config.language == 'system' &&
            WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
                'zh');
    final cells = buildDisplayTexts(
      view,
      data.quotes,
      metrics.snapshot,
      rates: data.exchangeRates,
    );
    await taskbar.update(
      buildTaskbarFrame(
        config: _config.taskbar,
        chinese: chinese,
        cells: cells,
        assets: view.assets,
        background: palette.background.toARGB32(),
        foreground: palette.foreground.toARGB32(),
        colorFor: (cell) => cellColor(cell).toARGB32(),
      ),
    );
  }

  Future<void> apply(AppConfig value) async {
    if (_saving) throw StateError('设置正在保存，请稍候。');
    _saving = true;
    try {
      final next = value.copyWith(windowBounds: _config.windowBounds);
      await store.save(next);
      _config = next;
      _appearancePreview = null;
      data.updateConfig(next);
      unawaited(configureMonitoring());
      unawaited(publishTaskbar());
      startupMessage = null;
      // Settings and secret ownership are committed before optional host work.
      try {
        await host.setAlwaysOnTop(next.alwaysOnTop);
      } catch (_) {
        startupMessage = '设置已保存；窗口置顶未能应用，重新打开可重试。';
      }
      try {
        await host.setOpacity(next.opacity);
      } catch (_) {
        startupMessage = '设置已保存；窗口透明度未能应用，重新打开可重试。';
      }
      notifyListeners();
    } finally {
      _saving = false;
    }
  }

  Future<void> rememberBounds() async {
    if (_saving || settingsOpen || _disposed || !host.supported) return;
    _saving = true;
    try {
      final bounds = await host.getBounds();
      if (bounds == null || _disposed) return;
      final before = _config.windowBounds;
      if (before != null &&
          encodeJson(before.toJson()) == encodeJson(bounds.toJson())) {
        return;
      }
      _config = _config.copyWith(windowBounds: bounds);
      await store.save(_config);
    } catch (_) {
      // Position persistence must never interrupt the visible price panel.
    } finally {
      _saving = false;
    }
  }

  Future<void> close() async {
    final guard = beforeExit;
    if (guard != null) {
      await tray.show();
      if (!await guard()) return;
    }
    await rememberBounds();
    await host.close();
  }

  Future<void> hideToTray() async {
    await rememberBounds();
    if (!await tray.hide() && !_disposed) {
      startupMessage = '暂时无法创建托盘图标，窗口保持显示。请稍后重试。';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _boundsTimer?.cancel();
    _taskbarTimer?.cancel();
    metrics.removeListener(_metricsChanged);
    metrics.dispose();
    taskbar.removeListener(notifyListeners);
    taskbar.dispose();
    data.removeListener(notifyListeners);
    data.dispose();
    catalog.removeListener(notifyListeners);
    catalog.dispose();
    tray.dispose();
    super.dispose();
  }
}
