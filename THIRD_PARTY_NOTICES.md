# Third-party notices

The root `LICENSE` applies to CryptoFloat's own source code and original project assets. Third-party code, fonts, and other resources retain their respective copyright notices and license terms.

## Software dependencies

The resolved dependency versions are recorded in `flutter_app/pubspec.lock`. Key components include:

| Component | License | Upstream |
| --- | --- | --- |
| Flutter framework and Flutter SDK packages | BSD-3-Clause, with separately licensed third-party components | [Flutter license](https://github.com/flutter/flutter/blob/master/LICENSE) |
| fluent_ui 4.16.1 | BSD-3-Clause; see the separate font information below | [Package license](https://pub.dev/packages/fluent_ui/versions/4.16.1/license) |
| file_selector 1.1.0 and its platform implementations | BSD-3-Clause | [Package license](https://pub.dev/packages/file_selector/versions/1.1.0/license) |
| math_expressions 3.2.0 | MIT | [Package license](https://pub.dev/packages/math_expressions/versions/3.2.0/license) |
| petitparser 7.0.2 | MIT | [Package license](https://pub.dev/packages/petitparser/versions/7.0.2/license) |
| scroll_pos 0.5.0 | MIT | [Package license](https://pub.dev/packages/scroll_pos/versions/0.5.0/license) |

This table is an overview, not a replacement for the full terms. Flutter collects framework, engine, and package license texts into `data/flutter_assets/NOTICES.Z` in the Windows release. The packaging script preserves that file and adds its uncompressed contents as `THIRD_PARTY_LICENSES.txt` at the top level of the release folder. Retain these notices when redistributing a build.

## Fonts and icons

The `fluent_ui` dependency includes the following Microsoft font resources:

- `FluentIcons.ttf`: identified by its font metadata as **Fabric MDL2 Assets**, copyright © 2017 Microsoft Corporation. All rights reserved.
- `SegoeIcons.ttf`: identified by its font metadata as **Segoe Fluent Icons**, copyright © 2024 Microsoft Corporation. All rights reserved.

These Microsoft resources are not relicensed under CryptoFloat's MIT license or the Flutter component's BSD license. Microsoft's [font-icons-mdl2 license](https://github.com/microsoft/fluentui/blob/master/packages/font-icons-mdl2/LICENSE) refers font and icon use to the [Microsoft Fabric Assets License Agreement](https://aka.ms/fluentui-assets-license). Review those terms for your use and distribution.

Microsoft's [Segoe Fluent Icons guidance](https://learn.microsoft.com/en-us/windows/apps/design/iconography/segoe-fluent-icons-font) permits downloading the font on other platforms for design and development, but states that it may not be shipped to another platform. CryptoFloat currently distributes a Windows build only. A release for macOS, Linux, Android, iOS, or the web must replace these resources or obtain an applicable redistribution license before shipping them; cross-platform Flutter source support does not confer font redistribution rights.

Flutter also supplies **Material Icons**, copyright © 2019 Google LLC. All rights reserved. The Flutter SDK used for this release supplies the font with the [Creative Commons Attribution 4.0 International license](licenses/MaterialIcons.txt); that exact license text is included in `licenses/MaterialIcons.txt` in the source and release packages. The release build may subset the font to include only glyphs used by the app. See the [Material Icons project](https://github.com/google/material-design-icons) for the upstream resource.

System text fonts selected by name are provided by the operating system and are not copied into CryptoFloat's source repository.

## Design references and external data

Theme presets refer to the color palettes of [Microsoft Fluent](https://fluent2.microsoft.design/color), [Catppuccin](https://github.com/catppuccin/palette), [Nord](https://github.com/nordtheme/nord), and [Solarized](https://github.com/altercation/solarized). These project names identify the references; they do not imply endorsement.

Market data, weather, exchange rates, and repository information are retrieved from external providers. The project license does not grant rights to those providers' data or services. Their terms, attribution requirements, and usage limits continue to apply. In particular, the weather template identifies [Open-Meteo](https://open-meteo.com/en/terms) as its data provider.
