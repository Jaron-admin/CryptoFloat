# MetricPerch · 数栖

[简体中文](README.md) · **English**

Show market quotes, JSON API fields, text, and local system metrics in a floating desktop panel and the Windows taskbar. Choose content and appearance independently for each display. Built with Flutter and Material 3, with English and Simplified Chinese interfaces.

![Example MetricPerch floating panel](docs/images/panel-preview.png)

Example appearance from v1.1: customize the name, fonts, colors, transparency, and displayed content. The settings interface has changed in the current version.

### Settings preview

![Material 3 appearance settings](docs/images/settings-en.png)

The retained v1.2 screenshot illustrates the appearance; v1.3 adds display targets and system monitoring, v1.4 adds columns and entry orientation, and v1.4.1 adds Save without leaving Settings and compact taskbar options. This preview uses sample data. Watchlist selections stay in place while editing; selected items move to the top when reopening the page or refreshing the catalog.

## Download and run

Download **MetricPerch-Windows-x64-1.4.1.zip** from [Releases](https://github.com/Jaron-admin/MetricPerch/releases).

Extract the entire archive and run `metricperch.exe`. Keep `metricperch_taskbar.exe`, the accompanying libraries, and the `data` folder beside it. The taskbar helper starts and exits with the main app.

This is a portable app: settings, caches, imported icons, protected secrets, and taskbar diagnostic logs live in `user_data` beside the executable. Use a writable folder and move the whole folder together. Only one instance runs for the current Windows user in the current login session; launching again brings the existing window forward. Exit the old version before upgrading and keep your `user_data` in the new app folder. Existing CryptoFloat portable settings are migrated while preserving custom titles, icons, themes, and display content.

The current release provides a **Windows x64** build. macOS and Linux project scaffolds are included, but their native window and protected storage integrations are incomplete. Android and iOS releases are not available.

Right-click the floating panel to open Settings. Select **Settings → Appearance → Language** to use English, Simplified Chinese, or the system language. Floating panel transparency is also available under Appearance.

## Features

- The floating market panel and taskbar monitoring start enabled; the taskbar's default selection is CPU, memory percentage, upload, and download rates.
- Each display independently selects quotes, API fields, text templates, and system metrics, with its own order, fonts, colors, and units. Data sources and device choices are shared.
- Transparent taskbar background, compact one/two-row layouts, maximum width, and item spacing. Choose short or custom labels; hover for original names and values.
- CPU, memory, GPU, video memory, network rates, and disk read/write rates, with a 1–60 second sample interval and automatic or manual device selection.
- Cryptocurrency, US stock, and selected mainland China stock quotes, with prices, changes, units, and update status.
- Searchable OKX, Binance, and KuCoin trading-pair catalogs. Reorder your watchlist by dragging or using move-up and move-down buttons.
- Custom HTTPS JSON APIs, fields, and display templates. Built-in quotes and free-form text can appear together.
- Unit aliases, reference exchange-rate conversion, and custom multipliers. Starter templates cover weather, exchange rates, public repository statistics, and text reminders.
- Light, dark, and system themes, multiple named color presets, and a visual color picker.
- Custom system fonts, numeric fonts, transparency, text size, spacing, app name, and icon.
- A 1–8 column floating layout with horizontal or vertical entries. Hide the 24h percentage and use customizable rising/falling price colors.
- Context menu, always-on-top window, double-click to hide to the tray, click to restore, and per-monitor DPI support.
- English and Simplified Chinese interfaces, with manual or system language selection.

Select **Floating panel** or **Taskbar** in Settings before editing its content and appearance. **Display layout** controls columns, entry orientation, and change display. **Taskbar layout** controls its own enable switch, maximum width, one/two rows, transparent background, item spacing, and labels. Short content uses less width. Custom labels affect only the taskbar and preserve the source data. Devices and the sample interval apply to both displays.

**Save** commits changes and keeps Settings open. Clicking outside Settings or returning to the panel still saves automatically and briefly confirms success. A close request during a save waits for that operation; a failed save keeps the draft for retry. Alt+Tab and color, font, or file pickers do not close Settings. Only Settings has an application taskbar button. Closing Settings saves and returns to the panel; closing the floating panel hides it to the tray. Use **Exit** to end the app.

Taskbar integration targets the standard primary Windows taskbar. It attempts to display only when a usable region can be confirmed and has enough room. Unsupported layouts, insufficient space, and an unavailable taskbar pause the display; Settings shows the helper's reported state. v1.4 fixes the reproduced Windows 11 composition issue that hid taskbar content, with visible metrics confirmed on one real desktop setup. Other configurations still need testing; the reported state alone does not verify visible content. Windows 11 has no supported third-party reserved slot, so every layout cannot be guaranteed. Taskbar content provides a context menu with settings, refresh, show floating panel, disable taskbar, and exit actions. The tray remains a way to restore the floating panel.

Missing metrics and samples establishing a baseline show `—`; only valid zero values show `0`. Automatic network selection uses active physical interfaces; manual selection can include virtual interfaces. GPU usage represents the busiest engine on the selected adapter; a memory percentage is unavailable when its capacity cannot be established. Rates need a new baseline after startup, resume, or a device change. Compatibility with the real taskbar still requires validation for the particular Windows version and desktop layout.

With centered Windows taskbar icons, data uses the far-left available space while avoiding weather and widgets; insufficient room on that side pauses the display. Left-aligned Windows taskbars use the right-side gap.

v1.4.1 corrects a DPI transition that reused the old display's minimum size and changed the window's logical width; the native regression passes. See the [DPI investigation](docs/verification/dpi-investigation.md) for live observations and verification limits.

## Data and settings

Without `user_data`, the app starts with default settings. It does not automatically read or migrate old data from the Windows user profile, and leaves those files unchanged. Subsequent launches reuse this portable copy's `user_data`. To share the app, use the release ZIP or remove `user_data` from your sharing copy first.

Secret request headers are protected using Windows DPAPI for the current user. Enter those secrets again after moving to another computer or Windows account. Connections follow the Windows system network settings.

Public data may be delayed, rate-limited, or temporarily unavailable. “Live” means the app fetched data successfully within the configured interval; it does not guarantee zero market-data latency. Prices and exchange rates are for reference.

See the [usage and build guide](flutter_app/README.en.md) for details.

See the [changelog](CHANGELOG.md) for this release.

## Build from source

Use Flutter 3.47.5 / Dart 3.13.4 and the Visual Studio desktop development with C++ toolchain. Follow the [Flutter Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).

```powershell
git clone https://github.com/Jaron-admin/MetricPerch.git
cd MetricPerch/flutter_app
flutter pub get
flutter build windows --release
```

To create a release folder and ZIP containing the usage guides and licenses:

```powershell
./tool/build_windows.ps1 -PackageName MetricPerch-Windows-x64-1.4.1
```

## License

MetricPerch's own source code is licensed under the [MIT License](LICENSE). You may use, modify, distribute, and use it commercially while retaining the license and copyright notice.

Dependencies and fonts retain their own licenses. See [Third-party notices](THIRD_PARTY_NOTICES.md). Release packages include the project license and full third-party license texts.
