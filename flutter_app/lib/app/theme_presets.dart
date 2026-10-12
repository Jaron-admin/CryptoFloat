import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Semantic roles shared by Flutter controls and native Windows menus.
/// Palette references and adaptations are documented in README.md.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.foreground,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.positive,
    required this.negative,
  });
  final Color background,
      surface,
      foreground,
      secondary,
      border,
      accent,
      positive,
      negative;

  factory AppPalette.fromData(ThemePaletteData data) => AppPalette(
    background: Color(data.background).withValues(alpha: 1),
    surface: Color(data.surface).withValues(alpha: 1),
    foreground: Color(data.foreground).withValues(alpha: 1),
    secondary: Color(data.secondary).withValues(alpha: 1),
    border: Color(data.border).withValues(alpha: 1),
    accent: Color(data.accent).withValues(alpha: 1),
    positive: Color(data.positive).withValues(alpha: 1),
    negative: Color(data.negative).withValues(alpha: 1),
  );

  ThemePaletteData toData() => ThemePaletteData(
    background: background.toARGB32(),
    surface: surface.toARGB32(),
    foreground: foreground.toARGB32(),
    secondary: secondary.toARGB32(),
    border: border.toARGB32(),
    accent: accent.toARGB32(),
    positive: positive.toARGB32(),
    negative: negative.toARGB32(),
  );
}

class ThemePreset {
  const ThemePreset(this.id, this.name, this.light, this.dark);
  final String id, name;
  final AppPalette light, dark;
}

const themePresets = <ThemePreset>[
  ThemePreset(
    'fluent',
    'Fluent 蓝',
    AppPalette(
      background: Color(0xFFF3F3F3),
      surface: Color(0xFFFFFFFF),
      foreground: Color(0xFF242424),
      secondary: Color(0xFF616161),
      border: Color(0xFFD1D1D1),
      accent: Color(0xFF0F6CBD),
      positive: Color(0xFF107C10),
      negative: Color(0xFFC50F1F),
    ),
    AppPalette(
      background: Color(0xFF202020),
      surface: Color(0xFF292929),
      foreground: Color(0xFFFFFFFF),
      secondary: Color(0xFFD6D6D6),
      border: Color(0xFF525252),
      accent: Color(0xFF479EF5),
      positive: Color(0xFF65D9AA),
      negative: Color(0xFFFF8391),
    ),
  ),
  ThemePreset(
    'catppuccin',
    'Catppuccin',
    AppPalette(
      background: Color(0xFFEFF1F5),
      surface: Color(0xFFE6E9EF),
      foreground: Color(0xFF4C4F69),
      secondary: Color(0xFF5C5F77),
      border: Color(0xFFBCC0CC),
      accent: Color(0xFF8839EF),
      positive: Color(0xFF267018),
      negative: Color(0xFFC61035),
    ),
    AppPalette(
      background: Color(0xFF1E1E2E),
      surface: Color(0xFF313244),
      foreground: Color(0xFFCDD6F4),
      secondary: Color(0xFFBAC2DE),
      border: Color(0xFF585B70),
      accent: Color(0xFFCBA6F7),
      positive: Color(0xFFA6E3A1),
      negative: Color(0xFFF38BA8),
    ),
  ),
  ThemePreset(
    'nord',
    'Nord 北欧',
    AppPalette(
      background: Color(0xFFECEFF4),
      surface: Color(0xFFE5E9F0),
      foreground: Color(0xFF2E3440),
      secondary: Color(0xFF4C566A),
      border: Color(0xFFB3BECE),
      accent: Color(0xFF42658A),
      positive: Color(0xFF42652D),
      negative: Color(0xFFA32C42),
    ),
    AppPalette(
      background: Color(0xFF2E3440),
      surface: Color(0xFF3B4252),
      foreground: Color(0xFFECEFF4),
      secondary: Color(0xFFD8DEE9),
      border: Color(0xFF616E88),
      accent: Color(0xFF88C0D0),
      positive: Color(0xFFA3BE8C),
      negative: Color(0xFFF29DA7),
    ),
  ),
  ThemePreset(
    'solarized',
    'Solarized 护眼',
    AppPalette(
      background: Color(0xFFFDF6E3),
      surface: Color(0xFFEEE8D5),
      foreground: Color(0xFF52676E),
      secondary: Color(0xFF52676E),
      border: Color(0xFFA8B2AB),
      accent: Color(0xFF16689A),
      positive: Color(0xFF586900),
      negative: Color(0xFFBA2424),
    ),
    AppPalette(
      background: Color(0xFF002B36),
      surface: Color(0xFF073642),
      foreground: Color(0xFFEEE8D5),
      secondary: Color(0xFF93A1A1),
      border: Color(0xFF586E75),
      accent: Color(0xFF65B9EA),
      positive: Color(0xFFA2BE30),
      negative: Color(0xFFFF8585),
    ),
  ),
];

AppPalette resolveAppPalette(
  AppConfig config, {
  required Brightness brightness,
}) {
  final light = brightness == Brightness.light;
  final id = light ? config.lightTheme : config.darkTheme;
  final custom = config.customThemes
      .where((theme) => theme.id == id)
      .firstOrNull;
  if (custom != null) {
    return AppPalette.fromData(light ? custom.light : custom.dark);
  }
  final preset = themePresets.where((preset) => preset.id == id).firstOrNull;
  if (id != 'custom') {
    final selected = preset ?? themePresets.first;
    return light ? selected.light : selected.dark;
  }
  final background = Color(
    light ? config.lightBackgroundColor : config.backgroundColor,
  ).withValues(alpha: 1);
  final darkSurface = background.computeLuminance() < 0.179;
  final base = darkSurface ? themePresets.first.dark : themePresets.first.light;
  final foreground = darkSurface ? Colors.white : Colors.black;
  final surface = Color.alphaBlend(
    (darkSurface ? Colors.black : Colors.white).withValues(alpha: 0.045),
    background,
  );
  double contrast(Color foreground, Color background) {
    final a = foreground.computeLuminance(), b = background.computeLuminance();
    return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
  }

  Color readable(Color candidate) {
    for (var step = 0; step <= 20; step++) {
      final color = Color.lerp(candidate, foreground, step / 20)!;
      if (contrast(color, background) >= 4.5 &&
          contrast(color, surface) >= 4.5) {
        return color;
      }
    }
    return foreground;
  }

  return AppPalette(
    background: background,
    surface: surface,
    foreground: foreground,
    secondary: readable(base.secondary),
    border: Color.alphaBlend(
      base.foreground.withValues(alpha: 0.25),
      background,
    ),
    accent: readable(base.accent),
    positive: readable(base.positive),
    negative: readable(base.negative),
  );
}

class MarketColors extends ThemeExtension<MarketColors> {
  const MarketColors({required this.positive, required this.negative});
  final Color positive, negative;
  @override
  MarketColors copyWith({Color? positive, Color? negative}) => MarketColors(
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
  );
  @override
  MarketColors lerp(covariant MarketColors? other, double t) => other == null
      ? this
      : MarketColors(
          positive: Color.lerp(positive, other.positive, t)!,
          negative: Color.lerp(negative, other.negative, t)!,
        );
}

MarketColors marketColorsOf(BuildContext context) =>
    Theme.of(context).extension<MarketColors>() ??
    const MarketColors(
      positive: Color(0xFF107C10),
      negative: Color(0xFFC50F1F),
    );
