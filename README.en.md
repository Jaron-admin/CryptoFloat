<div align="center">

<h1>DuoMonitor</h1>
<p>Live market quotes and system status in a Windows floating panel and taskbar</p>

[![Release](https://img.shields.io/github/v/release/Jaron-admin/DuoMonitor)](https://github.com/Jaron-admin/DuoMonitor/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Jaron-admin/DuoMonitor/total)](https://github.com/Jaron-admin/DuoMonitor/releases)
[![License](https://img.shields.io/github/license/Jaron-admin/DuoMonitor)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)

[简体中文](README.md) · **English** · [Download](https://github.com/Jaron-admin/DuoMonitor/releases/latest) · [User guide](docs/usage.en.md) · [Changelog](CHANGELOG.md)

</div>

> **Screenshots coming soon:** taskbar display / floating desktop panel.
<!-- TODO: Replace the text with user-supplied captures at docs/images/taskbar.png and docs/images/panel.png. -->

## ✨ Core features

- Monitor CPU, memory, GPU, network rates, disk activity, and other system metrics in the taskbar.
- Follow cryptocurrency, US stock, and selected mainland China stock quotes, with independent content and layouts for each display.
- Combine custom HTTPS JSON APIs, fields, and text templates with built-in quotes.
- Run without installation using portable or system storage, with API secrets protected locally by Windows DPAPI.
- Choose English or Chinese, light/dark themes, system fonts, transparency, and multiple columns.

## 📦 Download and install

1. Download `DuoMonitor-Windows-x64-<version>.zip` from [Releases](https://github.com/Jaron-admin/DuoMonitor/releases/latest).
2. Extract the entire folder, including the libraries, `data`, and taskbar helper.
3. Run `duomonitor.exe`.

**Requirements: Windows 10/11 x64. macOS / Linux are not currently supported.**

## 🧭 Feature details

Right-click the panel or tray icon to open Settings. Double-click the panel to hide it; click the tray icon to restore it.
Select Floating panel or Taskbar in Settings before editing that display's content and appearance.

See the [user guide](docs/usage.en.md) for data sources, independent layouts, custom APIs, system monitoring, and window controls.

## ❓ Frequently asked questions

### What if Windows says it protected my PC?

The application is currently unsigned. Confirm that the download came from this repository and check the release's SHA-256 before choosing More info → Run anyway.

### Where are settings and data stored?

The default is `user_data` beside the executable. Settings → Import & data location can switch to `%APPDATA%\DuoMonitor`.
The app remembers this choice: portable data moves with its folder, while system data stays separate from the app directory. See the [storage FAQ](docs/usage.en.md#storage).

### How do I upgrade without losing settings?

Exit the old version, back up the active data folder, and extract the whole new archive. For portable mode, copy `user_data` beside the new executable; for system mode, select the existing system data location in the new app and choose **Switch without copying**.
Enter API keys again after moving to another computer or Windows account. See [upgrades and migration](docs/usage.en.md#upgrade).

### What if the taskbar display is missing or looks wrong?

Check that taskbar display is enabled and enough free space is available. Integration targets the standard primary Windows taskbar; uncertain layouts pause the display.
Use the floating panel while checking the [taskbar guide](docs/usage.en.md#taskbar). Include your Windows version, scaling settings, and a screenshot when reporting a problem.

### Are API keys secure?

Secret request headers are encrypted with Windows DPAPI and referenced by settings. They are tied to the current user and computer.
Ordinary settings, caches, and logs are not encrypted as a whole; review them before sharing. See [secret storage](docs/usage.en.md#secrets).

## 🛠 Build from source

Use Flutter 3.47.5 / Dart 3.13.4 and the Visual Studio desktop development with C++ toolchain on Windows:

```powershell
git clone https://github.com/Jaron-admin/DuoMonitor.git
cd DuoMonitor/flutter_app
./tool/build_windows.ps1
```

See the [development guide](flutter_app/README.en.md) for setup, build parameters, and test commands.

## 🤝 Contributing

[Issues and suggestions](https://github.com/Jaron-admin/DuoMonitor/issues) and pull requests are welcome. Start with the [contributing guide](CONTRIBUTING.md).
Report security issues privately as described in the [security policy](SECURITY.md).

## 📄 License

[MIT](LICENSE) · Dependency, font, and data-service terms are described in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
