import 'package:fluent_ui/fluent_ui.dart';

import '../domain/models.dart';
import 'theme_presets.dart';

FluentThemeData buildFluentTheme(
  AppConfig config, {
  required Brightness brightness,
}) {
  final palette = resolveAppPalette(config, brightness: brightness);
  final effective = palette.background.computeLuminance() < 0.179
      ? Brightness.dark
      : Brightness.light;
  final accentText = palette.accent.computeLuminance() < 0.179
      ? Colors.white
      : Colors.black;
  final resourceFactory = effective == Brightness.dark
      ? ResourceDictionary.dark
      : ResourceDictionary.light;
  final resources = resourceFactory(
    textFillColorPrimary: palette.foreground,
    textFillColorSecondary: palette.secondary,
    textFillColorTertiary: palette.secondary.withValues(alpha: 0.8),
    textFillColorDisabled: palette.secondary.withValues(alpha: 0.5),
    textOnAccentFillColorPrimary: accentText,
    textOnAccentFillColorSecondary: accentText.withValues(alpha: 0.8),
    controlFillColorDefault: palette.surface,
    controlFillColorInputActive: palette.background,
    controlStrokeColorDefault: palette.border,
    controlStrongStrokeColorDefault: palette.secondary,
    cardStrokeColorDefault: palette.border,
    cardStrokeColorDefaultSolid: palette.border,
    dividerStrokeColorDefault: palette.border.withValues(alpha: 0.6),
    cardBackgroundFillColorDefault: palette.surface,
    cardBackgroundFillColorSecondary: palette.surface,
    solidBackgroundFillColorBase: palette.background,
    solidBackgroundFillColorSecondary: palette.surface,
    solidBackgroundFillColorTertiary: palette.surface,
    systemFillColorSuccess: palette.positive,
    systemFillColorCritical: palette.negative,
  );
  final type = Typography.fromBrightness(
    brightness: effective,
    color: palette.foreground,
  );
  TextStyle? uiText(TextStyle? style) => style?.copyWith(
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const [
      'Microsoft YaHei UI',
      'Microsoft YaHei',
      'PingFang SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
  );
  Color shade(Color target, double amount) =>
      Color.lerp(palette.accent, target, amount)!;
  return FluentThemeData(
    brightness: effective,
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.compact,
    typography: Typography.raw(
      display: uiText(type.display),
      titleLarge: uiText(type.titleLarge),
      title: uiText(type.title),
      subtitle: uiText(type.subtitle),
      bodyLarge: uiText(type.bodyLarge),
      bodyStrong: uiText(type.bodyStrong),
      body: uiText(type.body),
      caption: uiText(type.caption)?.copyWith(color: palette.secondary),
    ),
    accentColor: AccentColor.swatch({
      'darkest': shade(Colors.black, 0.3),
      'darker': shade(Colors.black, 0.2),
      'dark': shade(Colors.black, 0.1),
      'normal': palette.accent,
      'light': shade(Colors.white, 0.1),
      'lighter': shade(Colors.white, 0.2),
      'lightest': shade(Colors.white, 0.3),
    }),
    activeColor: palette.accent,
    inactiveColor: palette.secondary,
    inactiveBackgroundColor: palette.surface,
    scaffoldBackgroundColor: palette.background,
    micaBackgroundColor: palette.background,
    acrylicBackgroundColor: palette.surface,
    menuColor: palette.surface,
    cardColor: palette.surface,
    resources: resources,
    extensions: [
      MarketColors(positive: palette.positive, negative: palette.negative),
    ],
  );
}
