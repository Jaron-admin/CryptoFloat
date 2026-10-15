# DuoMonitor development guide

[简体中文](README.md) · **English**

For installation and everyday use, see the [root README](../README.en.md) and [user guide](../docs/usage.en.md).

## Build from source

Use Flutter 3.47.5 / Dart 3.13.4 on Windows 10/11 x64, with Visual Studio desktop development with C++, MSVC, CMake, and the Windows SDK. See the [Flutter Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).

```powershell
git clone https://github.com/Jaron-admin/DuoMonitor.git
cd DuoMonitor/flutter_app
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
./tool/build_windows.ps1 -PackageName DuoMonitor-Windows-x64-1.6.0
```

Output is written under `dist/`. The package contains `duomonitor.exe`, `duomonitor_taskbar.exe`, Chinese and English usage guides, the changelog, the project license, and third-party license texts. Packaging starts in a new staging directory and copies only allowlisted executables, libraries, and Flutter resources; it excludes `user_data`, logs, and temporary test files. A missing required helper fails packaging. An existing target directory or ZIP causes an error: choose a new `-PackageName` instead. Existing app directories are never overwritten or emptied. Debugging information is kept in a separate directory; distribute the generated ZIP. If Flutter is not on PATH, pass its command path with `-Flutter`.

Build public releases from a neutral path and inspect the final bundle for personal paths and sensitive data. You can map the source root to an unused drive letter with `subst M: <source-root>` and build from `M:\flutter_app`; remove it afterward with `subst M: /D`. Mapping reduces build-path exposure but does not replace a privacy audit of the final ZIP and a SHA256 checksum. Keep the debug-symbol directory out of the release upload.

If Windows symbolic-link permissions are unavailable, the script creates plugin directory junctions within generated project folders. Building for macOS or Linux requires the corresponding platform's toolchain and completion of window, protected-storage, and font-resource integration.

## License

DuoMonitor's own source code uses the [MIT License](../LICENSE). Use, modification, distribution, and commercial use are permitted while retaining the license and copyright notice.

Dependencies, icon fonts, and external data remain subject to their own licenses and service terms. See [Third-party notices](../THIRD_PARTY_NOTICES.md). Windows release packages keep Flutter's `data/flutter_assets/NOTICES.Z` and include its uncompressed contents as `THIRD_PARTY_LICENSES.txt`.

## Prepare plugin links

If `flutter pub get` reports missing plugin symlink permissions, run the existing helper and retry:

```powershell
./tool/prepare_plugin_links.ps1
flutter pub get
```

## Native checks

Run native checks separately from Flutter tests, substituting the actual MSVC tools directory:

```powershell
./tool/test_taskbar_host.ps1 -CompilerRoot '<MSVC Tools version directory>' -CompileHelper
./tool/test_monitor_channel.ps1 -CompilerRoot '<MSVC Tools version directory>'
```

Other scripts are in `tool/` and `windows/runner/tests/`. Hidden-window and offscreen checks do not replace live Explorer, multi-monitor, or scaling acceptance checks, which need an authorized desktop environment. See the existing [verification records](../docs/verification).

## Packaged documents and checksums

Usage documents are packaged from `docs/usage.md` / `docs/usage.en.md`; developer instructions are separate. `-Flutter` accepts a Flutter command path. The example version in `-PackageName` comes from `pubspec.yaml`, excluding its `+build` suffix. The script creates a ZIP without SHA-256; the release workflow or `Get-FileHash -Algorithm SHA256` generates the checksum.

## Directory layout

| Directory | Purpose |
| --- | --- |
| `lib/app/`, `lib/features/` | Application and settings UI |
| `lib/domain/`, `lib/data/` | Models, market data, and storage |
| `lib/platform/` | Platform calls; see [platform boundary](lib/platform/README.md) |
| `lib/l10n/` | English and Chinese resources |
| `assets/`, `test/` | Icons/resources and Flutter tests |
| `windows/runner/` | Windows integration; see [taskbar guide](windows/runner/TASKBAR.md) |
| `tool/` | Build and native-check scripts |
| `linux/`, `macos/` | Retained, unsupported platform scaffolds |

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the contribution process.
