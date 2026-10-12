import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../platform/system_fonts.dart';
import 'theme_presets.dart';

ThemeData buildAppTheme(AppConfig config, {Brightness? brightness}) {
  final mode =
      brightness ??
      (config.themeMode == 'light' ? Brightness.light : Brightness.dark);
  final palette = resolveAppPalette(config, brightness: mode);
  final background = palette.background;
  final effective = background.computeLuminance() < 0.179
      ? Brightness.dark
      : Brightness.light;
  Color raised(double opacity) => Color.lerp(
    background,
    palette.surface,
    (opacity / 0.09).clamp(0.0, 1.0),
  )!;
  final colors =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: effective,
        surface: background,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.accent.computeLuminance() < 0.179
            ? Colors.white
            : Colors.black,
        onSurface: palette.foreground,
        onSurfaceVariant: palette.secondary,
        outline: palette.border,
        outlineVariant: palette.border.withValues(alpha: 0.65),
        primaryContainer: Color.alphaBlend(
          palette.accent.withValues(alpha: 0.2),
          background,
        ),
        secondaryContainer: Color.alphaBlend(
          palette.accent.withValues(alpha: 0.12),
          background,
        ),
        surfaceContainerLowest: background,
        surfaceContainerLow: raised(0.025),
        onPrimaryContainer: palette.foreground,
        onSecondaryContainer: palette.foreground,
        surfaceContainer: palette.surface,
        surfaceContainerHigh: raised(0.065),
        surfaceContainerHighest: raised(0.09),
      );
  final buttonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    extensions: [
      MarketColors(positive: palette.positive, negative: palette.negative),
    ],
    scaffoldBackgroundColor: background,
    fontFamily: SystemFonts.family(config.fontFamily),
    fontFamilyFallback: const [
      'Microsoft YaHei',
      'PingFang SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 44,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: raised(0.025),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      minTileHeight: 40,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    dividerColor: colors.outlineVariant,
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        colors.primary.withValues(alpha: 0.65),
      ),
      thickness: const WidgetStatePropertyAll(5),
      radius: const Radius.circular(4),
    ),
  );
}
