import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

// All controls are thin, labelled wrappers around native M3 widgets.
// They pick up the checkboxTheme / switchTheme / etc. from ThemeData.

/// Checkbox with an inline label. Minimum tap target: 48 × 48 dp.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Semantics(
      checked: value ?? false,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!(value ?? false)),
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: WidgetStatePropertyAll(ext.overlayActive),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xs, vertical: LinearSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: value,
                  tristate: tristate,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Flexible(
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio button with an inline label.
class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Semantics(
      checked: value == groupValue,
      label: label,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: WidgetStatePropertyAll(ext.overlayActive),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xs, vertical: LinearSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: RadioGroup<T>(
                  groupValue: groupValue,
                  onChanged: onChanged,
                  child: Radio<T>(
                    value: value,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Flexible(
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch with an inline label (always 48 dp touch target).
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Semantics(
      toggled: value,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: WidgetStatePropertyAll(ext.overlayActive),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xs, vertical: LinearSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.72,
                alignment: Alignment.centerLeft,
                child: Switch(value: value, onChanged: onChanged),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Flexible(
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented control — wraps M3 [SegmentedButton].
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelect = false,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments:             segments,
      selected:             selected,
      onSelectionChanged:   onSelectionChanged,
      multiSelectionEnabled:multiSelect,
      showSelectedIcon:     false,
    );
  }
}
