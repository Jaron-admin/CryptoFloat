# DuoMonitor usage guide

[简体中文](usage.md) · **English** · [Project home](../README.en.md)

Show market quotes, custom JSON API fields, text, and local system metrics in a floating panel and inside the primary Windows taskbar. Each display selects its own content and appearance; sources and device settings are shared.

The current release supports Windows 10/11 x64 only. macOS and Linux project scaffolds are included, but native windows, protected storage, system telemetry, and taskbar integration are incomplete. Android and iOS project targets are not included.

## Start and control the panel

Extract the entire release archive and run `duomonitor.exe`. Keep `duomonitor_taskbar.exe`, the libraries, and the `data` folder beside it. The main app manages the taskbar helper, which receives display text and style rather than API addresses or secrets. The Windows build starts as a graphical application without a command window.

Extract to a writable directory. Personal data lives in `user_data` beside the EXE by default; an unwritable folder produces an error. **Import & data location** in Settings can switch to `%APPDATA%\DuoMonitor`, with an option to copy the current data. Only one instance runs for the current Windows user in the current login session, including launches from different portable folders. Launching again brings the existing window forward and restores it if hidden in the tray. Exit the old app and back up the complete active data folder before upgrading; in portable mode, keep `user_data` beside the new app.

- Drag the title area to move the panel; drag a window edge to resize it.
- Right-click the panel for its standard Windows context menu. The native popup can extend beyond a small panel's edges.
- Double-click the panel to hide it to the system tray. Click its tray icon to restore it. Windows may place the icon under the tray's hidden-icons arrow.
- The tray context menu also provides refresh, settings, and exit actions.
- Use Settings → Window & tray to toggle Always on top.
- Drag the settings title bar to move the settings window. Narrow windows use an icon sidebar or horizontal category navigation.
- **Save** commits the draft and keeps the current Settings page open. Clicking outside or returning to the panel still saves automatically. A close request during a save waits for the current operation; failed saves keep the draft for retry. Alt+Tab and color, font, and file pickers do not close Settings.
- Only Settings has an application taskbar button. Closing Settings, including Alt+F4 or the taskbar close command, saves and returns to the panel. Closing the floating panel hides it to the tray; choose **Exit** to end the app.

Manual saving updates the page's saved status; automatic saving when leaving Settings shows a brief confirmation. Windows draws the panel and tray menus' fonts, colors, spacing, and checkmarks. Context menus support arrow keys, Enter, and Esc. Clicking outside a popup closes it, including clicks elsewhere within the panel.

## Language

Open **Settings → Appearance → Language** and choose **English**, **Simplified Chinese**, or **System**. Settings previews the language immediately; Save or leaving Settings retains the choice. The interface, messages, floating panel, and tray menus use the selected language, which is retained across restarts.

User-defined names, display text, and API response content are preserved as entered. Switching the interface language does not translate that content.

## Watchlist

Search and select symbols from the OKX, Binance, and KuCoin spot trading-pair catalogs. Search matches names, symbols, and exchange names. Catalogs list names and symbols. The app fetches the combined dependencies of both enabled displays and requests a quote once even when both displays use it.

Catalogs are cached, refreshed every 24 hours, and can be refreshed manually. If an exchange request fails, its last catalog is retained. Common stock and ETF entries are also available, and additional stock symbols can be added manually.

The watched items appear at the top of the page. Drag the handle on the left or use the move-up and move-down buttons on the right to reorder them. Long lists scroll. Closing Settings successfully saves and applies the same order to the selected display.

Selecting or deselecting an item in the trading-pair catalog keeps it at its current list position. When you reopen the Watchlist page or manually refresh the catalog, selected items move to the top.

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

<a id="taskbar"></a>

## Independent displays

The floating market panel and taskbar monitoring are enabled by default. The taskbar's default selection is CPU, memory percentage, upload, and download rates. Select **Floating panel** or **Taskbar** in Settings, then edit that display's watchlist, custom fields, templates, metrics, order, text and numeric fonts, theme, and units. Each can show different content; changing only the order does not request all quotes again.

**Display layout** supports 1–8 floating columns, with horizontal or vertical entries. When the columns exceed the available width, scroll horizontally. Labels align left; numeric values and prices align right. The numeric font control recommends monospace fonts and marks installed common monospace families.

**Price color** applies to both the floating panel and taskbar, with default theme text, theme up/down colors, green-up/red-down, and red-up/green-down options. Direction compares consecutive successful price refreshes. The first successful refresh, an unchanged price, or a failed refresh is neutral. Failures keep the last successful price as the next comparison baseline. The 24h percentage retains its own value and sign color and can be hidden independently; it does not determine the price color. Section captions identify settings shared by both displays or limited to one display.

**Taskbar layout** controls enablement, one/two rows, background, label/value spacing, item spacing and overflow behavior. Width follows actual text and verified free space without an arbitrary cap. Overflow pages keep complete columns and support the mouse wheel or automatic rotation. The interval is configurable from 2–60 seconds (default 5); hover and manual scrolling pause rotation. A single item wider than the available space is shortened, with details available on hover.

With centered Windows taskbar icons, data prefers sufficient far-left space, otherwise the widest verified gap, avoiding weather, widgets and other controls. Unreliable space detection pauses the display.

**Labels** offers short or full labels. Automatic cryptocurrency labels remove a recognized quote-currency suffix, such as BTC-USDT → BTC. **Custom labels** lets you name individual quotes, metrics, API fields, and display rows in the taskbar; leave a label blank to restore its automatic name. These labels preserve source names, field identifiers, and data. Tooltips retain original names and values.

The fixed Settings preview renders the selected display using its current draft and available live data. Font, palette, spacing, layout and precision changes appear immediately. Save manually or leave Settings to apply them; a failed save retains the draft. **Display layout → Price display precision** offers standard or K/M/B notation and automatic or 0–8 decimals per asset: `81,678.42` can display as `81.7K`. K means thousand, M million, and B billion. Each display stores its own choices; source prices and change calculations remain unchanged. Newly added assets awaiting data show `—`. Before deleting shared sources or fields, remove references in both displays, including a disabled display.

Taskbar integration targets the standard primary Windows taskbar using a separate native text helper. Secondary taskbars and third-party replacements are outside the current scope. Windows 11 has no supported reserved slot for third-party content. The helper attempts to display only when a usable region is confirmed, without moving shell controls. Insufficient space or an unknown layout pauses it and retains settings. Settings shows the helper's reported disabled, displaying, waiting, no-space, unsupported, or error state; “Displaying” alone does not verify visible content. Different Windows versions and desktop layouts still need compatibility testing.

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

The floating panel has no persistent footer. Hover over an entry to see its update time and error information. Failed requests retain the last value and mark it as stale.

Connections follow the Windows system network settings. If a connection fails, the last data remains visible; hover over an entry for a brief error description.

The weather template uses [Open-Meteo](https://open-meteo.com/en/docs), subject to its attribution and non-commercial service terms. The repository template uses the [GitHub REST API](https://docs.github.com/en/rest/repos/repos#get-a-repository). Templates that access these services are not added on first launch automatically.

## FAQ: data, upgrades, and migration

<a id="storage"></a>

### Where is data stored? How do portable and system storage differ?

Personal data lives in `user_data` beside `duomonitor.exe` by default, or in `%APPDATA%\DuoMonitor` when system storage is selected. The active data folder contains `settings.json`; saving retains a `.bak` copy, which the app tries to recover if the main file is damaged. Catalog caches, imported icons, and protected secret files follow the selected folder. Preserve the complete active data folder when moving or backing up the app.

The current draft is saved before switching. **Copy current data** copies settings, icons, backups, caches, secrets, and logs while retaining the source folder. Conflicting destination files are preserved in `migration-backups`. Switching without copying loads the destination's settings, or defaults when empty; a failure keeps the current location. A `duomonitor_storage.json` file beside the app records the choice, with support for the old `metricperch_storage.json`. Read-only app folders use a system-folder selection record tied to that app path. Data actively stored in the old `%APPDATA%\MetricPerch` location is copied to the new system folder while retaining the original.

<a id="diagnostics"></a>

### Where are diagnostic logs stored?

Taskbar diagnostics are also stored in the active data folder, in `taskbar-bridge.log` and `taskbar-helper.log`. They contain only fixed status labels, error codes, and counts, with no quote content, API addresses, or secrets. Each log is limited to 64 KiB and keeps one rotated backup.

<a id="upgrade"></a>

### How do I upgrade without losing settings?

Exit the old version, back up the complete active data folder, and extract the new archive. In portable mode, copy `user_data` beside the new executable. For system storage, select the existing system folder in the new app's Import & data location section and choose **Switch without copying** to load the existing configuration.

Existing CryptoFloat portable settings migrate to the two-display format with an original pre-migration backup. Floating watchlists, templates, order, fonts, themes, custom titles, and icons are retained; migration adds taskbar monitoring enabled by default. MetricPerch settings remain readable, and saved titles are not replaced by the new brand. A saved explicit taskbar-off choice remains off on later starts. Configurations from a newer unsupported schema are not overwritten with defaults. Legacy single-instance and secret-reference identifiers are retained for compatibility; exit the old app before starting the renamed version.

The app remembers the selected data location. Existing portable installs continue to use their own `user_data` until a choice is saved. An active folder without settings starts with defaults. Old `%APPDATA%\CryptoFloatFlutter` and `%LOCALAPPDATA%\CryptoFloat\secrets` data is not automatically read, copied, or migrated.

<a id="secrets"></a>

### Are API keys secure? Is all configuration encrypted?

Secret request headers are encrypted locally with Windows DPAPI; settings contain references to them. Ordinary `settings.json`, caches, and logs are not encrypted as a whole, so review them before sharing. DPAPI still binds secrets to the current user and computer; enter API keys again after moving to another account or computer.

Release ZIPs contain no personal data or storage-location markers. Share the original release ZIP; copy the active data folder separately when backing up personal settings.

<a id="legacy-import"></a>

### How do I import legacy settings?

The import section on the Watchlist page accepts a legacy `crypto_config.json`. Import creates a settings draft; Save or leaving Settings commits and applies it. The old file is not modified. Compatible watchlists, ordering, fonts, and display rows can be migrated. Old API secrets must be entered again.

## Windows and displays

The app saves window size and position. The Windows runner uses PerMonitorV2 DPI awareness. If the saved monitor is disconnected or the window is completely offscreen, it returns to a visible area on the primary monitor. Behavior across mixed-DPI displays also depends on the monitor and operating-system configuration.

See the [DPI investigation](verification/dpi-investigation.md) for implementation details, live observations, and verification limits. Historical fixes are recorded in the [changelog](../CHANGELOG.md).


## Licensing and data notes

The application's own source code in the current version uses [GPL-3.0-only](../LICENSE); dependencies, icon fonts, and data services retain their own terms, described in [third-party notices](../THIRD_PARTY_NOTICES.md). Release packages include the project and full third-party license texts.

Public quotes may be delayed, rate-limited, or unavailable. “Live” means a successful fetch within the configured interval, not zero market-data latency. Prices and reference exchange rates are for informational display.
