# CryptoFloat

[简体中文](README.md) · **English**

A customizable floating desktop panel for market quotes, JSON APIs, and text. Built with Flutter and Material 3, with English and Simplified Chinese interfaces.

![Example CryptoFloat floating panel](docs/images/panel-preview.png)

Example appearance from v1.1: customize the name, fonts, colors, transparency, and displayed content. The settings interface has changed in the current version.

### Settings in v1.2

![Material 3 appearance settings](docs/images/settings-en.png)

Compact navigation, searchable settings, and grouped forms. This preview uses sample data. Watchlist selections stay in place while editing; selected items move to the top when reopening the page or refreshing the catalog.

## Download and run

Download **CryptoFloat-Windows-x64-1.2.0.zip** from [Releases](https://github.com/Jaron-admin/CryptoFloat/releases).

Extract the entire archive and run `cryptofloat.exe`. Keep the accompanying libraries and `data` folder beside the executable.

This is a portable app: settings, caches, imported icons, and protected secrets live in `user_data` beside the executable. Use a writable folder and move the whole folder together. Only one instance runs for the current Windows user in the current login session; launching again brings the existing window forward. Exit v1.1 or earlier before upgrading.

The current release provides a **Windows x64** build. macOS and Linux project scaffolds are included, but their native window and protected storage integrations are incomplete. Android and iOS releases are not available.

Right-click the floating panel to open Settings. Select **Settings → Appearance → Language** to use English, Simplified Chinese, or the system language. Floating panel transparency is also available under Appearance.

## Features

- Cryptocurrency, US stock, and selected mainland China stock quotes, with prices, changes, units, and update status.
- Searchable OKX, Binance, and KuCoin trading-pair catalogs. Reorder your watchlist by dragging or using move-up and move-down buttons.
- Custom HTTPS JSON APIs, fields, and display templates. Built-in quotes and free-form text can appear together.
- Unit aliases, reference exchange-rate conversion, and custom multipliers. Starter templates cover weather, exchange rates, public repository statistics, and text reminders.
- Light, dark, and system themes, multiple named color presets, and a visual color picker.
- Custom system fonts, numeric fonts, transparency, text size, spacing, app name, and icon.
- Context menu, always-on-top window, double-click to hide to the tray, click to restore, and per-monitor DPI support.
- English and Simplified Chinese interfaces, with manual or system language selection.

## Data and settings

Without `user_data`, the app starts with default settings. It does not automatically read or migrate old data from the Windows user profile, and leaves those files unchanged. Subsequent launches reuse this portable copy's `user_data`. To share the app, use the release ZIP or remove `user_data` from your sharing copy first.

Secret request headers are protected using Windows DPAPI for the current user. Enter those secrets again after moving to another computer or Windows account. Connections follow the Windows system network settings.

Public data may be delayed, rate-limited, or temporarily unavailable. “Live” means the app fetched data successfully within the configured interval; it does not guarantee zero market-data latency. Prices and exchange rates are for reference.

See the [usage and build guide](flutter_app/README.en.md) for details.

## Build from source

Use Flutter 3.47.5 / Dart 3.13.4 and the Visual Studio desktop development with C++ toolchain. Follow the [Flutter Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).

```powershell
git clone https://github.com/Jaron-admin/CryptoFloat.git
cd CryptoFloat/flutter_app
flutter pub get
flutter build windows --release
```

To create a release folder and ZIP containing the usage guides and licenses:

```powershell
./tool/build_windows.ps1 -PackageName CryptoFloat-Windows-x64-1.2.0
```

## License

CryptoFloat's own source code is licensed under the [MIT License](LICENSE). You may use, modify, distribute, and use it commercially while retaining the license and copyright notice.

Dependencies and fonts retain their own licenses. See [Third-party notices](THIRD_PARTY_NOTICES.md). Release packages include the project license and full third-party license texts.
