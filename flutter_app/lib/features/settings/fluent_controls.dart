import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// These adapters retain the editors' field metadata while the actual controls,
// keyboard interaction, focus visuals and popup surfaces come from Fluent UI.
class FTextField extends StatelessWidget {
  const FTextField({
    super.key,
    this.controller,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.keyboardType,
    this.decoration = const m.InputDecoration(),
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.readOnly = false,
    this.style,
    this.maxLength,
    this.enabled,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final m.InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool readOnly;
  final TextStyle? style;
  final int? maxLength;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) => _FieldLabel(
    decoration: decoration,
    child: f.TextBox(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      readOnly: readOnly,
      style: style,
      maxLength: maxLength,
      enabled: enabled ?? decoration.enabled,
      inputFormatters: inputFormatters,
      placeholder: decoration.hintText,
      placeholderStyle: decoration.hintStyle,
      prefix: _inputAdornment(decoration, prefix: true),
      suffix: _inputAdornment(decoration, prefix: false),
      padding: decoration.contentPadding ?? f.kTextBoxPadding,
      highlightColor: _errorColor(context, decoration),
      unfocusedColor: _errorColor(context, decoration),
    ),
  );
}

class FTextFormField extends StatefulWidget {
  const FTextFormField({
    super.key,
    this.initialValue,
    this.controller,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.keyboardType,
    this.decoration = const m.InputDecoration(),
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.readOnly = false,
    this.style,
    this.maxLength,
    this.enabled,
    this.inputFormatters,
  }) : assert(initialValue == null || controller == null);

  final String? initialValue;
  final TextEditingController? controller;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final m.InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool readOnly;
  final TextStyle? style;
  final int? maxLength;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<FTextFormField> createState() => _FTextFormFieldState();
}

class _FTextFormFieldState extends State<FTextFormField> {
  TextEditingController? _ownedController;

  TextEditingController get _controller =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue);
    }
  }

  @override
  void didUpdateWidget(FTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (widget.controller == null) {
        _ownedController = TextEditingController.fromValue(
          oldWidget.controller!.value,
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
    }
    if (widget.controller == null &&
        widget.initialValue != oldWidget.initialValue &&
        _controller.text != (widget.initialValue ?? '')) {
      final text = widget.initialValue ?? '';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FieldLabel(
    decoration: widget.decoration,
    child: f.TextFormBox(
      controller: _controller,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      readOnly: widget.readOnly,
      style: widget.style,
      maxLength: widget.maxLength,
      enabled: widget.enabled ?? widget.decoration.enabled,
      inputFormatters: widget.inputFormatters,
      placeholder: widget.decoration.hintText,
      placeholderStyle: widget.decoration.hintStyle,
      prefix: _inputAdornment(widget.decoration, prefix: true),
      suffix: _inputAdornment(widget.decoration, prefix: false),
      padding: widget.decoration.contentPadding ?? f.kTextBoxPadding,
      highlightColor: _errorColor(context, widget.decoration),
      unfocusedColor: _errorColor(context, widget.decoration),
    ),
  );
}

Color? _errorColor(BuildContext context, m.InputDecoration decoration) =>
    decoration.errorText != null || decoration.error != null
    ? f.Colors.red.defaultBrushFor(f.FluentTheme.of(context).brightness)
    : null;

Widget? _inputAdornment(m.InputDecoration decoration, {required bool prefix}) {
  final icon = prefix ? decoration.prefixIcon : decoration.suffixIcon;
  final child = prefix ? decoration.prefix : decoration.suffix;
  final text = prefix ? decoration.prefixText : decoration.suffixText;
  final content = icon ?? child ?? (text == null ? null : Text(text));
  if (content == null) return null;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: content,
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.decoration, required this.child});
  final m.InputDecoration decoration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = f.FluentTheme.of(context);
    final error =
        decoration.error ??
        (decoration.errorText == null ? null : Text(decoration.errorText!));
    final helper =
        decoration.helper ??
        (decoration.helperText == null ? null : Text(decoration.helperText!));
    Widget field = child;
    if (error != null || helper != null) {
      field = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          Semantics(
            liveRegion: error != null,
            child: DefaultTextStyle.merge(
              style: error != null
                  ? (decoration.errorStyle ??
                        theme.typography.caption?.copyWith(
                          color: _errorColor(context, decoration),
                        ))
                  : decoration.helperStyle ?? theme.typography.caption,
              child: error ?? helper!,
            ),
          ),
        ],
      );
    }
    if (decoration.label != null) {
      return f.InfoLabel.rich(
        label: WidgetSpan(child: decoration.label!),
        child: field,
      );
    }
    if (decoration.labelText?.isNotEmpty == true) {
      return f.InfoLabel(
        label: decoration.labelText!,
        labelStyle: decoration.labelStyle,
        child: field,
      );
    }
    return field;
  }
}

class FDropdownItem<T> extends f.ComboBoxItem<T> {
  const FDropdownItem({super.key, required super.value, required super.child});
}

class FDropdown<T> extends StatefulWidget {
  const FDropdown({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.isExpanded = true,
    this.decoration = const m.InputDecoration(),
  });
  final T? initialValue;
  final List<FDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final m.InputDecoration decoration;

  @override
  State<FDropdown<T>> createState() => _FDropdownState<T>();
}

class _FDropdownState<T> extends State<FDropdown<T>> {
  T? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void didUpdateWidget(FDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) => _FieldLabel(
    decoration: widget.decoration,
    child: f.ComboBox<T>(
      value: _value,
      items: widget.items,
      isExpanded: widget.isExpanded,
      placeholder: widget.decoration.hintText == null
          ? null
          : Text(widget.decoration.hintText!),
      onChanged: widget.onChanged == null || !widget.decoration.enabled
          ? null
          : (value) {
              setState(() => _value = value);
              widget.onChanged!(value);
            },
    ),
  );
}

enum _ButtonKind { normal, filled, text }

abstract class _FluentButton extends StatelessWidget {
  const _FluentButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.kind,
    this.leading,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leading;
  final _ButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final content = leading == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading!,
              const SizedBox(width: 7),
              Flexible(child: child),
            ],
          );
    return switch (kind) {
      _ButtonKind.normal => f.Button(onPressed: onPressed, child: content),
      _ButtonKind.filled => f.FilledButton(
        onPressed: onPressed,
        child: content,
      ),
      _ButtonKind.text => f.HyperlinkButton(
        onPressed: onPressed,
        child: content,
      ),
    };
  }
}

class FButton extends _FluentButton {
  const FButton({super.key, required super.onPressed, required super.child})
    : super(kind: _ButtonKind.normal);
  const FButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
  }) : super(kind: _ButtonKind.normal, child: label, leading: icon);
}

class FFilledButton extends _FluentButton {
  const FFilledButton({
    super.key,
    required super.onPressed,
    required super.child,
  }) : super(kind: _ButtonKind.filled);
  const FFilledButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
  }) : super(kind: _ButtonKind.filled, child: label, leading: icon);
}

class FTextButton extends _FluentButton {
  const FTextButton({super.key, required super.onPressed, required super.child})
    : super(kind: _ButtonKind.text);
  const FTextButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
  }) : super(kind: _ButtonKind.text, child: label, leading: icon);
}

class FIconButton extends StatelessWidget {
  const FIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.visualDensity,
  }) : _outlined = false;

  const FIconButton.outlined({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.visualDensity,
  }) : _outlined = true;

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final m.VisualDensity? visualDensity;
  final bool _outlined;

  @override
  Widget build(BuildContext context) {
    final compact = (visualDensity?.vertical ?? 0) < 0;
    final button = _outlined
        ? f.OutlinedButton(
            onPressed: onPressed,
            style: f.ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.all(compact ? 5 : 8)),
            ),
            child: icon,
          )
        : f.IconButton(
            onPressed: onPressed,
            icon: icon,
            iconButtonMode: compact
                ? f.IconButtonMode.small
                : f.IconButtonMode.large,
          );
    return tooltip == null
        ? button
        : f.Tooltip(message: tooltip!, child: button);
  }
}

class FSwitch extends StatelessWidget {
  const FSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) =>
      f.ToggleSwitch(checked: value, onChanged: onChanged);
}

class FSlider extends StatelessWidget {
  const FSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
  });
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  @override
  Widget build(BuildContext context) => f.Slider(
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    label: label,
    onChanged: onChanged,
  );
}

class FAlertDialog extends StatelessWidget {
  const FAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = true,
  });
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => _DialogViewport(
    builder: (context, constraints) => f.ContentDialog(
      constraints: BoxConstraints(
        maxWidth: math.min(560, constraints.maxWidth),
        maxHeight: constraints.maxHeight,
      ),
      title: title,
      content: content == null
          ? null
          : scrollable
          ? SingleChildScrollView(child: content)
          : content,
      actions: actions?.isEmpty == true ? null : actions,
    ),
  );
}

class FDialog extends StatelessWidget {
  const FDialog({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _DialogViewport(
    builder: (context, constraints) => f.ContentDialog(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      ),
      style: const f.ContentDialogThemeData(
        padding: EdgeInsets.zero,
        bodyPadding: EdgeInsets.zero,
      ),
      content: child,
    ),
  );
}

class _DialogViewport extends StatelessWidget {
  const _DialogViewport({required this.builder});
  final Widget Function(BuildContext, BoxConstraints) builder;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: LayoutBuilder(builder: builder),
    ),
  );
}

class FListTile extends StatelessWidget {
  const FListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.contentPadding,
    this.dense = false,
    this.visualDensity,
  });
  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;
  final m.VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context) {
    final vertical = math.max(
      2.0,
      (dense ? 5.0 : 9.0) + (visualDensity?.vertical ?? 0) * 2,
    );
    final horizontal = math.max(0.0, 12 + (visualDensity?.horizontal ?? 0) * 2);
    return f.ListTile.selectable(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onPressed: onTap,
      selected: selected,
      contentPadding:
          contentPadding ??
          EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      margin: EdgeInsets.zero,
    );
  }
}

class FCheckboxListTile extends StatelessWidget {
  const FCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense = false,
    this.visualDensity,
  });
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;
  final m.VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context) => FListTile(
    title: title,
    subtitle: subtitle,
    leading: secondary,
    contentPadding: contentPadding,
    dense: dense,
    visualDensity: visualDensity,
    onTap: onChanged == null ? null : () => onChanged!(value != true),
    trailing: f.Checkbox(checked: value, onChanged: onChanged),
  );
}

class FSwitchListTile extends StatelessWidget {
  const FSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense = false,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;

  @override
  Widget build(BuildContext context) => FListTile(
    title: title,
    subtitle: subtitle,
    leading: secondary,
    contentPadding: contentPadding,
    dense: dense,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: f.ToggleSwitch(checked: value, onChanged: onChanged),
  );
}

class FChoiceChip extends StatelessWidget {
  const FChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) =>
      f.ToggleButton(checked: selected, onChanged: onSelected, child: label);
}

class FExpansionTile extends StatelessWidget {
  const FExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.tilePadding = EdgeInsets.zero,
    this.childrenPadding = const EdgeInsets.all(12),
  });
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry tilePadding;
  final EdgeInsetsGeometry childrenPadding;

  @override
  Widget build(BuildContext context) => f.Expander(
    initiallyExpanded: initiallyExpanded,
    onStateChanged: onExpansionChanged,
    header: Padding(
      padding: tilePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          title,
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            DefaultTextStyle.merge(
              style: f.FluentTheme.of(context).typography.caption,
              child: subtitle!,
            ),
          ],
        ],
      ),
    ),
    contentPadding: childrenPadding,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}
