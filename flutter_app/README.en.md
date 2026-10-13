# MetricPerch · 数栖 1.3.0 · Portable Windows app

[简体中文](README.md) · **English**

Show market quotes, custom JSON API fields, text, and local system metrics in a floating panel and inside the primary Windows taskbar. Each display selects its own content and appearance; sources and device settings are shared.

The current release supports Windows x64. macOS and Linux project scaffolds are included, but native windows, protected storage, system telemetry, and taskbar integration are incomplete. Android and iOS project targets are not included.

## Start and control the panel

Extract the entire release archive and run `metricperch.exe`. Keep `metricperch_taskbar.exe`, the libraries, and the `data` folder beside it. The main app manages the taskbar helper, which receives display text and style rather than API addresses or secrets. The Windows build starts as a graphical application without a command window.

Extract to a writable directory. Personal data lives in `user_data` beside the EXE; an unwritable folder produces an error. Only one instance runs for the current Windows user in the current login session, including launches from different portable folders. Launching again brings the existing window forward and restores it if hidden in the tray. Exit the old app and back up `user_data` before upgrading.

- Drag the title area to move the panel; use the bottom-right corner to resize it.
- Right-click the panel for its context menu. The native popup can extend beyond a small panel's edges.
- Double-click the panel to hide it to the system tray. Click its tray icon to restore it. Windows may place the icon under the tray's hidden-icons arrow.
- The tray context menu also provides refresh, settings, and exit actions.
- Drag the settings title bar to move the settings window. Narrow windows use an icon sidebar or horizontal category navigation.
- Settings are edited as a draft. Save applies the changes and returns to the active panel. Returning with unsaved edits offers save, discard, or continue editing.

Context menus support arrow keys, Enter, and Esc. Clicking outside a popup closes it, including clicks elsewhere within the panel.

## Language

Open **Settings → Appearance → Language** and choose **English**, **Simplified Chinese**, or **System**. Save to apply the selection to the interface, messages, floating panel, and tray menus. The selection is retained across restarts.

User-defined names, display text, and API response content are preserved as entered. Switching the interface language does not translate that content.

## Watchlist

Search and select symbols from the OKX, Binance, and KuCoin spot trading-pair catalogs. Search matches names, symbols, and exchange names. Catalogs list names and symbols. The app fetches the combined dependencies of both enabled displays and requests a quote once even when both displays use it.

Catalogs are cached, refreshed every 24 hours, and can be refreshed manually. If an exchange request fails, its last catalog is retained. Common stock and ETF entries are also available, and additional stock symbols can be added manually.

The watched items appear at the top of the page. Drag the handle on the left or use the move-up and move-down buttons on the right to reorder them. Long lists scroll. Saving applies the same order to the selected display.

Selecting or deselecting an item in the trading-pair catalog keeps it at its current list position. When you reopen the Watchlist page, selected items move to the top of the catalog.

## Custom content and display rows

Add an HTTPS GET endpoint that returns JSON, read its fields, and choose what to show. Fields can have custom names and units. API key headers are protected using Windows DPAPI for the current user; settings store references to the protected values.

Custom APIs support HTTPS GET JSON only. Redirects and common secret query parameters in URLs are rejected. Put API keys in protected request headers.

The Display layout page supports built-in quote rows and custom display rows together. You can also hide built-in quote rows. Combine text with selected fields, change the row order, and choose decimal formatting. The editor preview and floating panel use the same rendering rules.

Starter templates include city weather, reference exchange rates, public GitHub repository statistics, a compact quote line, and a text reminder. Adding a template appends to the draft and keeps existing content. Its fields and text remain editable.

## Appearance

**Floating panel transparency** is at the top of Appearance. A value of 0% means fully opaque. Text and numeric fonts are selected separately from system fonts. Font previews include letters and numbers. Text size, spacing, the panel name, and its icon can also be customized.

Theme modes include light, dark, and system. Light and dark palettes are stored separately. Built-in pairs include Fluent Blue, Catppuccin, Nord, and Solarized. Custom background colors remain available.

Save the current colors as a new named theme to keep multiple presets. Each preset contains light and dark palettes and can be edited, copied, or deleted. The visual color picker has a color spectrum, hue and brightness sliders, RGB and HEX inputs, and a preview. Editable roles include background, cards, text, secondary text, borders, accent, positive values, and negative values.

Choose a built-in icon, emoji, or local image. The picker previews the icon. Imported images are limited to 1 MB and stored as a private PNG copy without changing the original. The panel name and icon can be hidden separately.

The settings interface uses Flutter Material 3. Native windows, the tray, and cross-window context menus are handled by the platform layer. Color palettes refer to [Microsoft Fluent](https://fluent2.microsoft.design/color), [Catppuccin](https://catppuccin.com/palette/), [Nord](https://www.nordtheme.com/docs/colors-and-palettes/), and [Solarized](https://ethanschoonover.com/solarized/), with some accent and price-change colors adjusted for small-text contrast.

## Independent displays

The floating market panel and taskbar monitoring are enabled by default. The taskbar initially shows CPU, memory percentage, upload, and download rates. Select **Floating panel** or **Taskbar** in Settings, then edit that display's watchlist, custom fields, templates, metrics, order, text and numeric fonts, theme, and units. Each can show different content; changing only the order does not request all quotes again.

**Taskbar layout** has its own enable switch, width, and one or two rows. Floating transparency applies only to the floating panel; the taskbar uses its own palette, and Settings stays opaque. Preview draft changes in Settings. Save applies them together after a successful save; cancelling restores the original settings, and a failed save retains the draft. Before deleting shared sources or fields, remove references in both displays, including a disabled display.

The first release targets the standard primary Windows taskbar using a separate native text helper. Secondary taskbars and third-party replacements are outside the current scope. Windows 11 has no supported reserved slot for third-party content. Display starts only when a usable region is confirmed, without moving shell controls. Insufficient space or an unknown layout pauses it and retains settings. Settings shows the actual disabled, displaying, waiting, no-space, unsupported, or error state.

Right-click taskbar content to open Settings, refresh, show the floating panel, disable taskbar display, or exit. The helper exits with the main app and removes content when disconnected. It rediscovers the taskbar after restarts, theme/DPI changes, or auto-hide changes. Real desktop compatibility needs separate validation; isolated local tests do not verify every Windows taskbar layout.

## Local system monitoring

In **System monitor**, select and reorder metrics for the current display. Available metrics cover CPU, memory and GPU usage, used/total memory and video memory, shared GPU memory, upload/download, and disk read/write rates. Device choices and the sample interval apply to both displays: the default is 1 second, configurable from 1 to 60 seconds. Network and GPU selection can be automatic or manual; disks can use the total or one device.

- CPU measures total processor usage; memory uses Windows physical memory status.
- Network rates use differences in cumulative interface bytes over time. Automatic mode includes active physical interfaces to avoid counting a VPN and its physical transport twice; manual mode can select a virtual interface.
- GPU usage is the busiest aggregated engine on the chosen adapter, whose model is shown. It is not a sum of every engine. Video memory usage is measured for the whole adapter, with capacity from its description. Integrated graphics or unknown capacity do not produce a fabricated percentage.
- Disk rates use either the total or one disk instance, without adding both together.

Unavailable counters or devices show `—`; only valid zero samples show `0`. Rate samples establish a new baseline after startup, resume, device changes, or a counter rollback. Each display evaluates freshness using its own dependencies. Collection needs no additional driver or administrator permission; GPU and video memory counter availability can vary by hardware.

## Data sources, units, and refresh

Built-in cryptocurrency sources use public OKX, Binance, and KuCoin endpoints. Binance uses its read-only market-data domain. US stock, ETF, and selected mainland China stock presets use Yahoo Finance's public chart endpoint. That endpoint is not a guaranteed official public API and may be delayed, rate-limited, or unavailable.

Quote rows display their quote currency, such as USDT, BTC, USD, or CNY. Custom fields accept any unit. API text is kept as returned; choose an explicit decimal format when you want to format a numeric string.

Units can use full codes, abbreviations such as USDT → U, or custom labels. Changing a label alone does not change the value. Currency conversion supports USD, CNY, EUR, GBP, HKD, JPY, USDT, and USDC using Coinbase reference rates based on USD, refreshed every five minutes. USDT and USDC are not assumed to equal USD. Missing or stale rates leave the original value and unit intact.

Custom conversions use an original unit, a target unit, and a fixed multiplier. Manual multipliers take precedence. Conversions requiring an offset, such as Celsius to Fahrenheit, cannot be represented by a multiplier alone.

Cryptocurrency quotes refresh about every 15 seconds by default, and Yahoo quotes about every 60 seconds. Custom API intervals range from 15 to 3,600 seconds. Sources refresh independently. A failure retains the last value and marks it as stale; a tooltip provides update information and a brief reason.

The floating panel's lower-left status shows the automatic refresh interval. Green “Live” means its dependencies were successfully fetched within their respective intervals. Otherwise the status reports the last update or that the app is waiting for its first update. This uses the local fetch time; a separate tooltip can show the upstream timestamp. “Live” does not guarantee zero market-data latency. An unrelated source used only by the other display does not affect this status.

Connections follow the Windows system network settings. If a connection fails, the last data remains visible with a short status message.

The weather template uses [Open-Meteo](https://open-meteo.com/en/docs), subject to its attribution and non-commercial service terms. The repository template uses the [GitHub REST API](https://docs.github.com/en/rest/repos/repos#get-a-repository). Templates that access these services are not added on first launch automatically.

## Settings, storage, and import

All personal data lives in `user_data` beside `metricperch.exe`. Settings use `user_data/settings.json`; saving retains a `.bak` copy, which the app tries to recover if the main file is damaged. Catalog caches, imported icons, and protected secret files also live in this directory. Keep the whole directory when moving or backing up the app.

Existing CryptoFloat portable settings migrate to the two-display format with an original pre-migration backup. Floating watchlists, templates, order, fonts, themes, custom titles, and icons are retained; migration adds taskbar monitoring enabled by default. A saved explicit taskbar-off choice remains off on later starts. Configurations from a newer unsupported schema are not overwritten with defaults. Legacy single-instance and secret-reference identifiers are retained for compatibility; exit the old app before starting the renamed version.

Without `user_data`, the app starts with default settings. It does not automatically read, copy, or migrate the old Windows profile data. The old `%APPDATA%\CryptoFloatFlutter` and `%LOCALAPPDATA%\CryptoFloat\secrets` remain unchanged. Windows DPAPI still binds secrets to the current user and computer; enter API keys again after moving to another account or computer.

Release ZIPs contain no personal data. To share the app, use the original release ZIP or remove `user_data` from a separate sharing copy of your app folder.

The import section on the Watchlist page accepts a legacy `crypto_config.json`. Import creates a settings draft; Save applies it. The old file is not modified. Compatible watchlists, ordering, fonts, and display rows can be migrated. Old API secrets must be entered again.

The app saves window size and position. The Windows runner uses PerMonitorV2 DPI awareness. If the saved monitor is disconnected or the window is completely offscreen, it returns to a visible area on the primary monitor. Behavior across mixed-DPI displays also depends on the monitor and operating-system configuration.

## Build from source

Use Flutter 3.47.5 / Dart 3.13.4 on Windows x64, with Visual Studio desktop development with C++, MSVC, CMake, and the Windows SDK. See the [Flutter Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).

```powershell
git clone https://github.com/Jaron-admin/MetricPerch.git
cd MetricPerch/flutter_app
flutter pub get
flutter run -d windows
```

Development checks and a release build:

```powershell
flutter analyze
flutter test
flutter build windows --release
```

Create a distributable folder and ZIP:

```powershell
./tool/build_windows.ps1 -PackageName MetricPerch-Windows-x64-1.3.0
```

Output is written under `dist/`. The package contains `metricperch.exe`, `metricperch_taskbar.exe`, Chinese and English usage guides, the changelog, the project license, and third-party license texts. Packaging starts in a new staging directory and copies only allowlisted executables, libraries, and Flutter resources; it excludes `user_data`, logs, and temporary test files. A missing required helper fails packaging. An existing target directory or ZIP causes an error: choose a new `-PackageName` instead. Existing app directories are never overwritten or emptied. Debugging information is kept in a separate directory; distribute the generated ZIP. If Flutter is not on PATH, pass its command path with `-Flutter`.

Build public releases from a neutral path and inspect the final bundle for personal paths and sensitive data. You can map the source root to an unused drive letter with `subst M: <source-root>` and build from `M:\flutter_app`; remove it afterward with `subst M: /D`. Mapping reduces build-path exposure but does not replace a privacy audit of the final ZIP and a SHA256 checksum. Keep the debug-symbol directory out of the release upload.

If Windows symbolic-link permissions are unavailable, the script creates plugin directory junctions within generated project folders. Building for macOS or Linux requires the corresponding platform's toolchain and completion of window, protected-storage, and font-resource integration.

## License

MetricPerch's own source code uses the [MIT License](../LICENSE). Use, modification, distribution, and commercial use are permitted while retaining the license and copyright notice.

Dependencies, icon fonts, and external data remain subject to their own licenses and service terms. See [Third-party notices](../THIRD_PARTY_NOTICES.md). Windows release packages keep Flutter's `data/flutter_assets/NOTICES.Z` and include its uncompressed contents as `THIRD_PARTY_LICENSES.txt`.
