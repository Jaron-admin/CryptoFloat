import 'package:flutter/material.dart';

import 'theme_presets.dart';
import '../domain/models.dart';

/// Explicit conventions use readable light/dark colors; theme mode keeps
/// the user's independently editable positive and negative theme colors.
MarketColors resolveMarketChangeColors(
  AppConfig config, {
  required Brightness brightness,
  required MarketColors themeColors,
}) {
  if (config.marketColorStyle == 'theme') return themeColors;
  final green = brightness == Brightness.dark
      ? const Color(0xFF65D9AA)
      : const Color(0xFF107C10);
  final red = brightness == Brightness.dark
      ? const Color(0xFFFF8391)
      : const Color(0xFFC50F1F);
  return config.marketColorStyle == 'redUp'
      ? MarketColors(positive: red, negative: green)
      : MarketColors(positive: green, negative: red);
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
