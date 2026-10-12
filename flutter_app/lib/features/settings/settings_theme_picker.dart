import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';

import '../../app/theme_presets.dart';
import '../../domain/models.dart';
import '../../l10n/l10n.dart';
import 'settings_catalog.dart';
import 'theme_editor.dart';

String _builtinThemeName(ThemePreset preset, AppLocalizations l10n) =>
    switch (preset.id) {
      'fluent' => l10n.editThemeFluent,
      'nord' => l10n.editThemeNord,
      'solarized' => l10n.editThemeSolarized,
      _ => preset.name,
    };

class SettingsThemePicker extends StatelessWidget {
  const SettingsThemePicker({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingRow(
          title: context.l10n.editThemeMode,
          control: ComboBox<String>(
            value: config.themeMode,
            isExpanded: true,
            items: [
              ComboBoxItem(
                value: 'system',
                child: Text(context.l10n.editSystem),
              ),
              ComboBoxItem(value: 'light', child: Text(context.l10n.editLight)),
              ComboBoxItem(value: 'dark', child: Text(context.l10n.editDark)),
            ],
            onChanged: (value) {
              if (value != null) onChanged(config.copyWith(themeMode: value));
            },
          ),
        ),
        _selection(context, Brightness.light),
        if (config.lightTheme == 'custom')
          _backgroundEditor(context, Brightness.light),
        _selection(context, Brightness.dark),
        if (config.darkTheme == 'custom')
          _backgroundEditor(context, Brightness.dark),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final light = ThemePalettePreview(
              palette: resolveAppPalette(config, brightness: Brightness.light),
              label: context.l10n.editLightPreview,
            );
            final dark = ThemePalettePreview(
              palette: resolveAppPalette(config, brightness: Brightness.dark),
              label: context.l10n.editDarkPreview,
            );
            if (constraints.maxWidth < 400) {
              return Column(children: [light, const SizedBox(height: 8), dark]);
            }
            return Row(
              children: [
                Expanded(child: light),
                const SizedBox(width: 8),
                Expanded(child: dark),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.l10n.editMyThemes, style: type.bodyStrong),
            Button(
              onPressed: () => _create(context),
              child: Text(context.l10n.editSaveThemeAs),
            ),
          ],
        ),
        if (config.customThemes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(context.l10n.editThemesHelp, style: type.caption),
          ),
        for (final theme in config.customThemes) ...[
          const SizedBox(height: 8),
          _savedTheme(context, theme),
        ],
      ],
    );
  }

  Widget _selection(BuildContext context, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final selected = dark ? config.darkTheme : config.lightTheme;
    final choices = <(String, String)>[
      for (final preset in themePresets)
        (preset.id, _builtinThemeName(preset, context.l10n)),
      ('custom', context.l10n.editCustomBackground),
      for (final preset in config.customThemes) (preset.id, preset.name),
    ];
    final value = choices.any((choice) => choice.$1 == selected)
        ? selected
        : 'fluent';
    return SettingRow(
      title: dark
          ? context.l10n.editDarkPalette
          : context.l10n.editLightPalette,
      control: ComboBox<String>(
        value: value,
        isExpanded: true,
        items: [
          for (final choice in choices)
            ComboBoxItem(
              value: choice.$1,
              child: Text(
                choice.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          onChanged(
            dark
                ? config.copyWith(darkTheme: value)
                : config.copyWith(lightTheme: value),
          );
        },
      ),
    );
  }

  Widget _backgroundEditor(BuildContext context, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final color = Color(
      dark ? config.backgroundColor : config.lightBackgroundColor,
    ).withValues(alpha: 1);
    return SettingRow(
      title: dark
          ? context.l10n.editDarkBackground
          : context.l10n.editLightBackground,
      control: Button(
        onPressed: () => _editBackground(context, brightness),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: FluentTheme.of(context)
                      .resources
                      .controlStrongStrokeColorDefault,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(context.l10n.editChooseColor),
          ],
        ),
      ),
    );
  }

  Future<void> _editBackground(
    BuildContext context,
    Brightness brightness,
  ) async {
    final custom = config.copyWith(lightTheme: 'custom', darkTheme: 'custom');
    final result = await showDialog<UserThemePreset>(
      context: context,
      builder: (_) => ThemeEditorDialog(
        theme: UserThemePreset(
          id: 'custom',
          name: context.l10n.editCustomBackground,
          light: resolveAppPalette(
            custom,
            brightness: Brightness.light,
          ).toData(),
          dark: resolveAppPalette(custom, brightness: Brightness.dark).toData(),
        ),
        backgroundBrightness: brightness,
      ),
    );
    if (result == null || !context.mounted) return;
    onChanged(
      brightness == Brightness.dark
          ? config.copyWith(
              backgroundColor: result.dark.background,
              darkTheme: 'custom',
            )
          : config.copyWith(
              lightBackgroundColor: result.light.background,
              lightTheme: 'custom',
            ),
    );
  }

  Widget _savedTheme(BuildContext context, UserThemePreset theme) => Row(
    children: [
      for (final palette in [theme.light, theme.dark])
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Color(palette.background),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Color(palette.border)),
            ),
            alignment: Alignment.center,
            child: Container(width: 8, height: 3, color: Color(palette.accent)),
          ),
        ),
      const SizedBox(width: 3),
      Expanded(
        child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      Tooltip(
        message: context.l10n.editThemeEditNamed(theme.name),
        child: IconButton(
          icon: const Icon(FluentIcons.edit, size: 14),
          onPressed: () => _edit(context, theme),
        ),
      ),
      Tooltip(
        message: context.l10n.editThemeCopyNamed(theme.name),
        child: IconButton(
          icon: const Icon(FluentIcons.copy, size: 14),
          onPressed: () => _create(context, source: theme),
        ),
      ),
      Tooltip(
        message: context.l10n.editThemeDeleteNamed(theme.name),
        child: IconButton(
          icon: const Icon(FluentIcons.delete, size: 14),
          onPressed: () => _delete(context, theme),
        ),
      ),
    ],
  );

  Future<void> _create(BuildContext context, {UserThemePreset? source}) async {
    final id =
        'user:${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${Random.secure().nextInt(0x7fffffff).toRadixString(36)}';
    final initial = UserThemePreset(
      id: id,
      name: source == null
          ? context.l10n.editMyTheme
          : context.l10n.editThemeCopyName(source.name),
      light:
          source?.light ??
          resolveAppPalette(config, brightness: Brightness.light).toData(),
      dark:
          source?.dark ??
          resolveAppPalette(config, brightness: Brightness.dark).toData(),
    );
    final saved = await showDialog<UserThemePreset>(
      context: context,
      builder: (_) => ThemeEditorDialog(theme: initial, isNew: true),
    );
    if (saved == null || !context.mounted) return;
    onChanged(
      config.copyWith(
        customThemes: [...config.customThemes, saved],
        lightTheme: saved.id,
        darkTheme: saved.id,
      ),
    );
  }

  Future<void> _edit(BuildContext context, UserThemePreset theme) async {
    final saved = await showDialog<UserThemePreset>(
      context: context,
      builder: (_) => ThemeEditorDialog(theme: theme),
    );
    if (saved == null || !context.mounted) return;
    onChanged(
      config.copyWith(
        customThemes: [
          for (final existing in config.customThemes)
            existing.id == saved.id ? saved : existing,
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, UserThemePreset theme) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(context.l10n.editDeleteTheme),
        content: Text(context.l10n.editThemeDeleteConfirm(theme.name)),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.editCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.editDelete),
          ),
        ],
      ),
    );
    if (remove != true || !context.mounted) return;
    onChanged(
      config.copyWith(
        customThemes: config.customThemes
            .where((item) => item.id != theme.id)
            .toList(),
        lightTheme: config.lightTheme == theme.id
            ? 'fluent'
            : config.lightTheme,
        darkTheme: config.darkTheme == theme.id ? 'fluent' : config.darkTheme,
      ),
    );
  }
}
