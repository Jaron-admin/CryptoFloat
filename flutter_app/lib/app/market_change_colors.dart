import 'package:flutter/material.dart';

import 'theme_presets.dart';
import '../domain/models.dart';
import '../domain/refresh_price.dart';

/// Explicit conventions use readable light/dark colors; theme mode keeps
/// the user's independently editable positive and negative theme colors.
MarketColors marketColorsForStyle(
  String style, {
  required Brightness brightness,
  required MarketColors themeColors,
}) {
  if (style == 'theme' || style == 'plain') return themeColors;
  final green = brightness == Brightness.dark
      ? const Color(0xFF65D9AA)
      : const Color(0xFF107C10);
  final red = brightness == Brightness.dark
      ? const Color(0xFFFF8391)
      : const Color(0xFFC50F1F);
  return style == 'redUp'
      ? MarketColors(positive: red, negative: green)
      : MarketColors(positive: green, negative: red);
}

MarketColors resolveMarketChangeColors(
  AppConfig config, {
  required Brightness brightness,
  required MarketColors themeColors,
}) => marketColorsForStyle(
  config.marketColorStyle,
  brightness: brightness,
  themeColors: themeColors,
);

/// Colors a price from the last successful refresh. The first sample and
/// plain mode stay on the theme text color.
Color priceTickColor({
  required String priceColorMode,
  required PriceTick tick,
  required Color neutral,
  required Brightness brightness,
  required MarketColors themeColors,
}) {
  if (priceColorMode == 'plain' || tick == PriceTick.neutral) return neutral;
  final colors = marketColorsForStyle(
    priceColorMode,
    brightness: brightness,
    themeColors: themeColors,
  );
  return tick == PriceTick.up ? colors.positive : colors.negative;
}

Color taskbarPriceColor({
  required String cellId,
  required bool stale,
  required String priceColorMode,
  required PriceTick tick,
  required Color foreground,
  required Color secondary,
  required Brightness brightness,
  required MarketColors themeColors,
}) {
  if (stale) return secondary;
  if (!cellId.startsWith('asset:')) return foreground;
  return priceTickColor(
    priceColorMode: priceColorMode,
    tick: tick,
    neutral: foreground,
    brightness: brightness,
    themeColors: themeColors,
  );
}

Color marketChangeColor(BuildContext context, AppConfig config, num? change) {
  if (change == null || !change.isFinite || change == 0) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  final colors = resolveMarketChangeColors(
    config,
    brightness: Theme.of(context).brightness,
    themeColors: marketColorsOf(context),
  );
  return change > 0 ? colors.positive : colors.negative;
}
