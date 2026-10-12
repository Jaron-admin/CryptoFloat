import 'package:fluent_ui/fluent_ui.dart';

import '../../app/theme_presets.dart';
import '../../domain/models.dart';
import '../../l10n/l10n.dart';

class ThemeEditorDialog extends StatefulWidget {
  const ThemeEditorDialog({
    super.key,
    required this.theme,
    this.isNew = false,
    this.backgroundBrightness,
  });
  final UserThemePreset theme;
  final bool isNew;
  final Brightness? backgroundBrightness;

  @override
  State<ThemeEditorDialog> createState() => _ThemeEditorDialogState();
}

class _ThemeEditorDialogState extends State<ThemeEditorDialog> {
  late final TextEditingController _name;
  late UserThemePreset _draft;
  bool _dark = false;
  String _role = 'background';
  String? _error;
  int _pickerRevision = 0;
  final Map<String, HSVColor> _hsvByRole = {};

  Map<String, String> get _roles => {
    'background': context.l10n.editRoleBackground,
    'surface': context.l10n.editRoleSurface,
    'foreground': context.l10n.editRoleForeground,
    'secondary': context.l10n.editRoleSecondary,
    'border': context.l10n.editRoleBorder,
    'accent': context.l10n.editRoleAccent,
    'positive': context.l10n.editRolePositive,
    'negative': context.l10n.editRoleNegative,
  };

  ThemePaletteData get _palette => _dark ? _draft.dark : _draft.light;
  String get _colorKey => '$_dark-$_role';
  HSVColor get _hsv => _hsvByRole[_colorKey] ?? HSVColor.fromColor(_color);
  Color get _color => Color(switch (_role) {
    'surface' => _palette.surface,
    'foreground' => _palette.foreground,
    'secondary' => _palette.secondary,
    'border' => _palette.border,
    'accent' => _palette.accent,
    'positive' => _palette.positive,
    'negative' => _palette.negative,
    _ => _palette.background,
  }).withValues(alpha: 1);

  @override
  void initState() {
    super.initState();
    _draft = widget.theme;
    _dark = widget.backgroundBrightness == Brightness.dark;
    _name = TextEditingController(text: widget.theme.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setColor(Color color, {bool refreshPicker = false, HSVColor? hsv}) {
    final previous = _hsv;
    final converted = HSVColor.fromColor(color);
    // RGB black cannot retain hue or saturation; keep those editing coordinates
    // so a brightness round trip restores the same color for this palette role.
    final coordinates =
        hsv ??
        converted
            .withHue(converted.saturation == 0 ? previous.hue : converted.hue)
            .withSaturation(
              converted.value == 0 ? previous.saturation : converted.saturation,
            );
    final value = color.withValues(alpha: 1).toARGB32();
    final updated = widget.backgroundBrightness != null
        ? resolveAppPalette(
            AppConfig.defaults.copyWith(
              lightTheme: 'custom',
              darkTheme: 'custom',
              backgroundColor: value,
              lightBackgroundColor: value,
            ),
            brightness: _dark ? Brightness.dark : Brightness.light,
          ).toData()
        : switch (_role) {
            'surface' => _palette.copyWith(surface: value),
            'foreground' => _palette.copyWith(foreground: value),
            'secondary' => _palette.copyWith(secondary: value),
            'border' => _palette.copyWith(border: value),
            'accent' => _palette.copyWith(accent: value),
            'positive' => _palette.copyWith(positive: value),
            'negative' => _palette.copyWith(negative: value),
            _ => _palette.copyWith(background: value),
          };
    setState(() {
      _hsvByRole[_colorKey] = coordinates;
      _draft = _dark
          ? _draft.copyWith(dark: updated)
          : _draft.copyWith(light: updated);
      // ColorPicker 4.16 keeps its initial ColorState on external updates.
      // Recreate it only for external sliders, preserving input focus otherwise.
      if (refreshPicker) _pickerRevision++;
    });
  }

  void _setHsv(HSVColor color) =>
      _setColor(color.toColor(), refreshPicker: true, hsv: color);

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.editThemeNameRequired);
      return;
    }
    Navigator.pop(context, _draft.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    constraints: const BoxConstraints(maxWidth: 760),
    title: Text(
      widget.backgroundBrightness != null
          ? context.l10n.editThemeBackgroundTitle(
              _dark ? context.l10n.editDark : context.l10n.editLight,
            )
          : widget.isNew
          ? context.l10n.editThemeNew
          : context.l10n.editThemeEdit,
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.backgroundBrightness == null) ...[
            InfoLabel(
              label: context.l10n.editThemeName,
              child: TextBox(
                controller: _name,
                placeholder: context.l10n.editThemeNameHint,
                maxLength: 60,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: FluentTheme.of(context)
                        .resources
                        .systemFillColorCritical,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                InfoLabel(
                  label: context.l10n.editThemePalette,
                  child: SizedBox(
                    width: 140,
                    child: ComboBox<bool>(
                      value: _dark,
                      isExpanded: true,
                      items: [
                        ComboBoxItem(
                          value: false,
                          child: Text(context.l10n.editLight),
                        ),
                        ComboBoxItem(
                          value: true,
                          child: Text(context.l10n.editDark),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _dark = value);
                      },
                    ),
                  ),
                ),
                InfoLabel(
                  label: context.l10n.editColorRole,
                  child: SizedBox(
                    width: 180,
                    child: ComboBox<String>(
                      value: _role,
                      isExpanded: true,
                      items: [
                        for (final role in _roles.entries)
                          ComboBoxItem(
                            value: role.key,
                            child: Text(role.value),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _role = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final picker = ColorPicker(
                key: ValueKey('$_dark-$_role-$_pickerRevision'),
                color: _color,
                onChanged: _setColor,
                colorSpectrumShape: ColorSpectrumShape.box,
                isColorSliderVisible: false,
                isMoreButtonVisible: false,
                isHexInputVisible: true,
                isColorChannelTextInputVisible: true,
                isAlphaEnabled: false,
                isAlphaSliderVisible: false,
                isAlphaTextInputVisible: false,
              );
              final preview = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThemePalettePreview(
                    palette: AppPalette.fromData(_palette),
                    label: _dark
                        ? context.l10n.editDarkPreview
                        : context.l10n.editLightPreview,
                  ),
                  const SizedBox(height: 16),
                  _hsvSlider(
                    context.l10n.editHue,
                    _hsv.hue,
                    359,
                    (value) => _setHsv(_hsv.withHue(value)),
                  ),
                  const SizedBox(height: 8),
                  _hsvSlider(
                    context.l10n.editBrightness,
                    _hsv.value * 100,
                    100,
                    (value) => _setHsv(_hsv.withValue(value / 100)),
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    if (constraints.maxWidth < 312)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(width: 312, child: picker),
                        ),
                      )
                    else
                      picker,
                    const SizedBox(height: 16),
                    preview,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 312, child: picker),
                  const SizedBox(width: 20),
                  Expanded(child: preview),
                ],
              );
            },
          ),
        ],
      ),
    ),
    actions: [
      Button(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.editCancel),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(
          widget.backgroundBrightness == null
              ? context.l10n.editSaveTheme
              : context.l10n.editApplyColor,
        ),
      ),
    ],
  );

  Widget _hsvSlider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label  ${value.round()}${max == 359 ? '°' : '%'}'),
      Slider(
        value: value.clamp(0, max),
        min: 0,
        max: max,
        onChanged: onChanged,
      ),
    ],
  );
}

class ThemePalettePreview extends StatelessWidget {
  const ThemePalettePreview({
    super.key,
    required this.palette,
    required this.label,
  });
  final AppPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: palette.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: palette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CryptoFloat',
                style: TextStyle(
                  color: palette.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text('BTC', style: TextStyle(color: palette.accent)),
                  Text('+2.8%', style: TextStyle(color: palette.positive)),
                  Text('−1.2%', style: TextStyle(color: palette.negative)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
