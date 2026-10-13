import 'dart:math' as math;

import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Shared compact Material controls preserve drafts across live theme and locale changes.

/// Wait for the route to unmount before callers dispose editor controllers.
Future<T?> showEditorDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = m.DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

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
  Widget build(BuildContext context) => m.TextField(
    decoration: decoration,
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
  Widget build(BuildContext context) => m.TextFormField(
    decoration: widget.decoration,
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
  );
}

class FDropdownItem<T> extends m.DropdownMenuItem<T> {
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
  Widget build(BuildContext context) => m.DropdownButtonFormField<T>(
    initialValue: _value,
    items: widget.items,
    isExpanded: widget.isExpanded,
    isDense: true,
    decoration: widget.decoration,
    borderRadius: BorderRadius.circular(10),
    menuMaxHeight: 360,
    onChanged: widget.onChanged == null || !widget.decoration.enabled
        ? null
        : (value) {
            setState(() => _value = value);
            widget.onChanged!(value);
          },
  );
}

enum _ButtonKind { normal, filled, text }

abstract class _CompactButton extends StatelessWidget {
  const _CompactButton({
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
      _ButtonKind.normal => m.OutlinedButton(
        onPressed: onPressed,
        child: content,
      ),
      _ButtonKind.filled => m.FilledButton(
        onPressed: onPressed,
        child: content,
      ),
      _ButtonKind.text => m.TextButton(onPressed: onPressed, child: content),
    };
  }
}

class FButton extends _CompactButton {
  const FButton({super.key, required super.onPressed, required super.child})
    : super(kind: _ButtonKind.normal);
  const FButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
  }) : super(kind: _ButtonKind.normal, child: label, leading: icon);
}

class FFilledButton extends _CompactButton {
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

class FTextButton extends _CompactButton {
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
    final style = m.IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      padding: const EdgeInsets.all(6),
      visualDensity: visualDensity ?? m.VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return _outlined
        ? m.IconButton.outlined(
            onPressed: onPressed,
            icon: icon,
            tooltip: tooltip,
            style: style,
          )
        : m.IconButton(
            onPressed: onPressed,
            icon: icon,
            tooltip: tooltip,
            style: style,
          );
  }
}

class FSwitch extends StatelessWidget {
  const FSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) =>
      m.Switch(value: value, onChanged: onChanged);
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
  Widget build(BuildContext context) => m.Slider(
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
    builder: (context, constraints) => m.AlertDialog(
      insetPadding: EdgeInsets.zero,
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
    builder: (context, constraints) => m.Dialog(
      insetPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      ),
      child: child,
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
    return m.ListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      selected: selected,
      contentPadding:
          contentPadding ??
          EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      dense: dense,
      visualDensity: visualDensity,
      minTileHeight: 44,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selectedTileColor: m.Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: 0.45),
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
    trailing: m.Checkbox(
      value: value,
      tristate: value == null,
      onChanged: onChanged,
    ),
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
    trailing: m.Switch(value: value, onChanged: onChanged),
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
  Widget build(BuildContext context) => m.ChoiceChip(
    selected: selected,
    onSelected: onSelected,
    label: label,
    showCheckmark: false,
  );
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
  Widget build(BuildContext context) => m.ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    onExpansionChanged: onExpansionChanged,
    tilePadding: tilePadding,
    childrenPadding: childrenPadding,
    title: title,
    subtitle: subtitle,
    shape: const Border(),
    collapsedShape: const Border(),
    children: children,
  );
}
