# CryptoFloat 1.2.0 · Portable Flutter desktop app

[简体中文](README.md) · **English**

CryptoFloat is a floating panel for market quotes, custom JSON API fields, and text. Data, settings, and the interface use Dart and Flutter. Native window and protected-storage integrations are isolated in `lib/platform/` and the Windows runner.

The current release supports Windows x64. macOS and Linux project scaffolds are included, but native window and protected-storage integration is incomplete. Android and iOS project targets are not included.

## Start and control the panel

Extract the entire release archive and run `cryptofloat.exe`. Keep the libraries and `data` folder beside it. The Windows build starts as a graphical application without a command window.

Extract to a writable directory. Personal data lives in `user_data` beside the EXE; an unwritable folder produces an error instead of silently saving in the Windows profile. Only one instance runs for the current Windows user in the current login session, including launches from different portable folders. Launching again brings the existing window forward and restores it if hidden in the tray. Exit v1.1 or earlier before upgrading, as those versions do not have this mechanism.

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

Search and select symbols from the OKX, Binance, and KuCoin spot trading-pair catalogs. Search matches names, symbols, and exchange names. Catalogs list names and symbols; the app fetches prices only for watched items.

Catalogs are cached, refreshed every 24 hours, and can be refreshed manually. If an exchange request fails, its last catalog is retained. Common stock and ETF entries are also available, and additional stock symbols can be added manually.

The watched items appear at the top of the page. Drag the handle on the left or use the move-up and move-down buttons on the right to reorder them. Long lists scroll. Saving applies the same order to the panel.

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

## Data sources, units, and refresh

Built-in cryptocurrency sources use public OKX, Binance, and KuCoin endpoints. Binance uses its read-only market-data domain. US stock, ETF, and selected mainland China stock presets use Yahoo Finance's public chart endpoint. That endpoint is not a guaranteed official public API and may be delayed, rate-limited, or unavailable.

Quote rows display their quote currency, such as USDT, BTC, USD, or CNY. Custom fields accept any unit. API text is kept as returned; choose an explicit decimal format when you want to format a numeric string.

Units can use full codes, abbreviations such as USDT → U, or custom labels. Changing a label alone does not change the value. Currency conversion supports USD, CNY, EUR, GBP, HKD, JPY, USDT, and USDC using Coinbase reference rates based on USD, refreshed every five minutes. USDT and USDC are not assumed to equal USD. Missing or stale rates leave the original value and unit intact.

Custom conversions use an original unit, a target unit, and a fixed multiplier. Manual multipliers take precedence. Conversions requiring an offset, such as Celsius to Fahrenheit, cannot be represented by a multiplier alone.

Cryptocurrency quotes refresh about every 15 seconds by default, and Yahoo quotes about every 60 seconds. Custom API intervals range from 15 to 3,600 seconds. Sources refresh independently. A failure retains the last value and marks it as stale; a tooltip provides update information and a brief reason.

The lower-left status shows the automatic refresh interval. Green “Live” means all sources were successfully fetched within their respective intervals. Otherwise the status reports the last update or that the app is waiting for its first update. This uses the local fetch time; a separate tooltip can show the upstream timestamp. “Live” does not guarantee zero market-data latency.

Connections follow the Windows system network settings. If a connection fails, the last data remains visible with a short status message.

The weather template uses [Open-Meteo](https://open-meteo.com/en/docs), subject to its attribution and non-commercial service terms. The repository template uses the [GitHub REST API](https://docs.github.com/en/rest/repos/repos#get-a-repository). Templates that access these services are not added on first launch automatically.

## Settings, storage, and import

All personal data lives in `user_data` beside `cryptofloat.exe`. Settings use `user_data/settings.json`; saving retains a `.bak` copy, which the app tries to recover if the main file is damaged. Catalog caches, imported icons, and protected secret files also live in this directory. Keep the whole directory when moving or backing up the app.

Without `user_data`, the app starts with default settings. It does not automatically read, copy, or migrate the old Windows profile data. The old `%APPDATA%\CryptoFloatFlutter` and `%LOCALAPPDATA%\CryptoFloat\secrets` remain unchanged. Windows DPAPI still binds secrets to the current user and computer; enter API keys again after moving to another account or computer.

Release ZIPs contain no personal data. To share the app, use the original release ZIP or remove `user_data` from a separate sharing copy of your app folder.

The import section on the Watchlist page accepts a legacy `crypto_config.json`. Import creates a settings draft; Save applies it. The old file is not modified. Compatible watchlists, ordering, fonts, and display rows can be migrated. Old API secrets must be entered again.

The app saves window size and position. The Windows runner uses PerMonitorV2 DPI awareness. If the saved monitor is disconnected or the window is completely offscreen, it returns to a visible area on the primary monitor. Behavior across mixed-DPI displays also depends on the monitor and operating-system configuration.

## Build from source

Use Flutter 3.47.5 / Dart 3.13.4 on Windows x64, with Visual Studio desktop development with C++, MSVC, CMake, and the Windows SDK. See the [Flutter Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).

```powershell
git clone https://github.com/Jaron-admin/CryptoFloat.git
cd CryptoFloat/flutter_app
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
./tool/build_windows.ps1 -PackageName CryptoFloat-Windows-x64-1.2.0
```

Output is written under `dist/`. The package contains the application, Chinese and English usage guides, the project license, and third-party license texts. Packaging starts in a new staging directory and copies only allowlisted executables, libraries, and Flutter resources; it never copies `user_data`. An existing target directory or ZIP causes an error: choose a new `-PackageName` instead. Existing app directories are never overwritten or emptied. Debugging information is kept in a separate directory; distribute the generated ZIP. If Flutter is not on PATH, pass its command path with `-Flutter`.

If Windows symbolic-link permissions are unavailable, the script creates plugin directory junctions within generated project folders. Building for macOS or Linux requires the corresponding platform's toolchain and completion of window, protected-storage, and font-resource integration.

## License

CryptoFloat's own source code uses the [MIT License](../LICENSE). Use, modification, distribution, and commercial use are permitted while retaining the license and copyright notice.

Dependencies, icon fonts, and external data remain subject to their own licenses and service terms. See [Third-party notices](../THIRD_PARTY_NOTICES.md). Windows release packages keep Flutter's `data/flutter_assets/NOTICES.Z` and include its uncompressed contents as `THIRD_PARTY_LICENSES.txt`.
