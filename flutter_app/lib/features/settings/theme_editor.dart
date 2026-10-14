import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _channels = <String, TextEditingController>{
    for (final key in ['hex', 'r', 'g', 'b']) key: TextEditingController(),
  };
  final _invalidChannels = <String>{};
  final Map<String, HSVColor> _hsvByRole = {};
  late UserThemePreset _draft;
  bool _dark = false;
  String _role = 'background';
  String? _error;

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
    _syncChannels();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _channels.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncChannels({String? except}) {
    final argb = _color.toARGB32();
    final values = {
      'hex': argb.toRadixString(16).substring(2).toUpperCase(),
      'r': ((argb >> 16) & 0xff).toString(),
      'g': ((argb >> 8) & 0xff).toString(),
      'b': (argb & 0xff).toString(),
    };
    for (final entry in values.entries) {
      if (entry.key == except) continue;
      final controller = _channels[entry.key]!;
      if (controller.text != entry.value) {
        controller.value = TextEditingValue(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
        );
      }
      _invalidChannels.remove(entry.key);
    }
  }

  void _setColor(Color color, {HSVColor? hsv, String? editingChannel}) {
    final previous = _hsv;
    final converted = HSVColor.fromColor(color);
    // Keep hue and saturation through RGB black, preserving the editing
    // coordinates when brightness is moved down to zero and back up.
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
      _syncChannels(except: editingChannel);
    });
  }

  void _setHsv(HSVColor color) => _setColor(color.toColor(), hsv: color);

  void _editChannel(String channel, String text) {
    if (channel == 'hex') {
      final value = text.trim().replaceFirst(RegExp(r'^#'), '');
      if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) {
        setState(() => _invalidChannels.add(channel));
        return;
      }
      _invalidChannels.remove(channel);
      _setColor(
        Color(0xff000000 | int.parse(value, radix: 16)),
        editingChannel: channel,
      );
      return;
    }
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > 255) {
      setState(() => _invalidChannels.add(channel));
      return;
    }
    final argb = _color.toARGB32();
    final red = channel == 'r' ? value : ((argb >> 16) & 0xff);
    final green = channel == 'g' ? value : ((argb >> 8) & 0xff);
    final blue = channel == 'b' ? value : (argb & 0xff);
    _invalidChannels.remove(channel);
    _setColor(Color.fromARGB(255, red, green, blue), editingChannel: channel);
  }

  void _changeSelection({bool? dark, String? role}) {
    setState(() {
      _dark = dark ?? _dark;
      _role = role ?? _role;
      _syncChannels();
    });
  }

  void _save() {
    if (_invalidChannels.isNotEmpty) return;
    final name = _name.text.trim();
    if (name.isEmpty && widget.backgroundBrightness == null) {
      setState(() => _error = context.l10n.editThemeNameRequired);
      return;
    }
    Navigator.pop(context, _draft.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final title = widget.backgroundBrightness != null
        ? context.l10n.editThemeBackgroundTitle(
            _dark ? context.l10n.editDark : context.l10n.editLight,
          )
        : widget.isNew
        ? context.l10n.editThemeNew
        : context.l10n.editThemeEdit;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: math.max(
            160,
            viewport.height - MediaQuery.viewInsetsOf(context).bottom - 32,
          ),
        ),
        child: SizedBox(
          width: math.min(760, math.max(0, viewport.width - 32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.backgroundBrightness == null) ...[
                        TextField(
                          key: const ValueKey('theme-name'),
                          controller: _name,
                          maxLength: 60,
                          decoration: InputDecoration(
                            labelText: context.l10n.editThemeName,
                            hintText: context.l10n.editThemeNameHint,
                            errorText: _error,
                            counterText: '',
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SegmentedButton<bool>(
                              key: const ValueKey('theme-brightness'),
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: false,
                                  icon: const Icon(Icons.light_mode_outlined),
                                  label: Text(context.l10n.editLight),
                                ),
                                ButtonSegment(
                                  value: true,
                                  icon: const Icon(Icons.dark_mode_outlined),
                                  label: Text(context.l10n.editDark),
                                ),
                              ],
                              selected: {_dark},
                              onSelectionChanged: (values) =>
                                  _changeSelection(dark: values.single),
                            ),
                            SizedBox(
                              width: 210,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('theme-role-$_role'),
                                initialValue: _role,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: context.l10n.editColorRole,
                                ),
                                items: [
                                  for (final role in _roles.entries)
                                    DropdownMenuItem(
                                      value: role.key,
                                      child: Text(role.value),
                                    ),
                                ],
                                onChanged: (value) =>
                                    _changeSelection(role: value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final picker = _picker();
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
                                'hue',
                                context.l10n.editHue,
                                _hsv.hue,
                                360,
                                (value) => _setHsv(_hsv.withHue(value % 360)),
                                hue: true,
                              ),
                              _hsvSlider(
                                'saturation',
                                context.l10n.theme120Saturation,
                                _hsv.saturation * 100,
                                100,
                                (value) =>
                                    _setHsv(_hsv.withSaturation(value / 100)),
                              ),
                              _hsvSlider(
                                'brightness',
                                context.l10n.editBrightness,
                                _hsv.value * 100,
                                100,
                                (value) => _setHsv(_hsv.withValue(value / 100)),
                              ),
                            ],
                          );
                          if (constraints.maxWidth < 580) {
                            return Column(
                              children: [
                                picker,
                                const SizedBox(height: 18),
                                preview,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: picker),
                              const SizedBox(width: 24),
                              Expanded(child: preview),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.editCancel),
                    ),
                    FilledButton(
                      key: const ValueKey('theme-save'),
                      onPressed: _invalidChannels.isEmpty ? _save : null,
                      child: Text(
                        widget.backgroundBrightness == null
                            ? context.l10n.editSaveTheme
                            : context.l10n.editApplyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: 1.4,
        child: _ColorSpectrum(value: _hsv, onChanged: _setHsv),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Semantics(
            label: context.l10n.theme120ColorValue,
            value: '#${_channels['hex']!.text}',
            child: Container(
              key: const ValueKey('theme-color-preview'),
              width: 48,
              height: 44,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('theme-hex'),
              controller: _channels['hex'],
              maxLength: 7,
              decoration: InputDecoration(
                labelText: 'HEX',
                prefixText: '# ',
                counterText: '',
                errorText: _invalidChannels.contains('hex')
                    ? context.l10n.theme120InvalidHex
                    : null,
              ),
              onChanged: (value) => _editChannel('hex', value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final channel in ['r', 'g', 'b']) ...[
            if (channel != 'r') const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey('theme-$channel'),
                controller: _channels[channel],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 3,
                decoration: InputDecoration(
                  labelText: channel.toUpperCase(),
                  counterText: '',
                  errorText: _invalidChannels.contains(channel)
                      ? context.l10n.theme120InvalidRgb
                      : null,
                  errorMaxLines: 3,
                ),
                onChanged: (value) => _editChannel(channel, value),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  Widget _hsvSlider(
    String key,
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged, {
    bool hue = false,
  }) {
    final suffix = hue ? '°' : '%';
    final valueLabel = value.round().toString() + suffix;
    final slider = Slider(
      key: ValueKey('theme-$key-slider'),
      value: value.clamp(0, max),
      min: 0,
      max: max,
      divisions: max.toInt(),
      label: valueLabel,
      semanticFormatterCallback: (value) => '$label ${value.round()}$suffix',
      onChanged: onChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (hue)
          Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 5,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    gradient: LinearGradient(
                      colors: [
                        Color(0xffff0000),
                        Color(0xffffff00),
                        Color(0xff00ff00),
                        Color(0xff00ffff),
                        Color(0xff0000ff),
                        Color(0xffff00ff),
                        Color(0xffff0000),
                      ],
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  secondaryActiveTrackColor: Colors.transparent,
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                  trackGap: 0,
                ),
                child: slider,
              ),
            ],
          )
        else
          slider,
      ],
    );
  }
}

class _ColorSpectrum extends StatefulWidget {
  const _ColorSpectrum({required this.value, required this.onChanged});
  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  @override
  State<_ColorSpectrum> createState() => _ColorSpectrumState();
}

class _ColorSpectrumState extends State<_ColorSpectrum> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _setPosition(Offset position, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _focus.requestFocus();
    widget.onChanged(
      widget.value
          .withSaturation((position.dx / size.width).clamp(0, 1))
          .withValue((1 - position.dy / size.height).clamp(0, 1)),
    );
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final amount = HardwareKeyboard.instance.isShiftPressed ? 0.1 : 0.01;
    final value = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => widget.value.withSaturation(
        (widget.value.saturation - amount).clamp(0, 1),
      ),
      LogicalKeyboardKey.arrowRight => widget.value.withSaturation(
        (widget.value.saturation + amount).clamp(0, 1),
      ),
      LogicalKeyboardKey.arrowUp => widget.value.withValue(
        (widget.value.value + amount).clamp(0, 1),
      ),
      LogicalKeyboardKey.arrowDown => widget.value.withValue(
        (widget.value.value - amount).clamp(0, 1),
      ),
      _ => null,
    };
    if (value == null) return KeyEventResult.ignored;
    widget.onChanged(value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.theme120Spectrum,
    hint: context.l10n.theme120SpectrumHint,
    value:
        '${(widget.value.saturation * 100).round()}% / '
        '${(widget.value.value * 100).round()}%',
    child: Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      onFocusChange: (value) => setState(() => _focused = value),
      child: LayoutBuilder(
        builder: (context, constraints) => MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: GestureDetector(
            key: const ValueKey('theme-spectrum'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _setPosition(details.localPosition, constraints.biggest),
            onPanStart: (details) =>
                _setPosition(details.localPosition, constraints.biggest),
            onPanUpdate: (details) =>
                _setPosition(details.localPosition, constraints.biggest),
            child: CustomPaint(
              painter: _SpectrumPainter(
                widget.value,
                focused: _focused,
                focusColor: Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter(
    this.value, {
    required this.focused,
    required this.focusColor,
  });
  final HSVColor value;
  final bool focused;
  final Color focusColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final center = Offset(
      (value.saturation * size.width).clamp(7, math.max(7, size.width - 7)),
      ((1 - value.value) * size.height).clamp(7, math.max(7, size.height - 7)),
    );
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = Colors.black.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
    if (focused) {
      canvas.drawRRect(
        rounded.deflate(1),
        Paint()
          ..color = focusColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) =>
      value != oldDelegate.value ||
      focused != oldDelegate.focused ||
      focusColor != oldDelegate.focusColor;
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: palette.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: palette.border.withValues(alpha: .6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.secondary, fontSize: 12)),
        const SizedBox(height: 14),
        Text(
          'DuoMonitor',
          style: TextStyle(
            color: palette.foreground,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('BTC', style: TextStyle(color: palette.accent)),
              Text('83,477.99', style: TextStyle(color: palette.foreground)),
              Text('+2.8%', style: TextStyle(color: palette.positive)),
              Text('−1.2%', style: TextStyle(color: palette.negative)),
            ],
          ),
        ),
      ],
    ),
  );
}
