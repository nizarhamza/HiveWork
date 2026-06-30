import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// A typed option for [AppSelect].
class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// A Linear-style select / dropdown.
/// Uses [DropdownMenu] which picks up [inputDecorationTheme] from the theme.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.options,
    required this.onSelected,
    this.value,
    this.label,
    this.hint,
    this.width,
    this.enabled = true,
  });

  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onSelected;
  final T? value;
  final String? label;
  final String? hint;
  final double? width;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return SizedBox(
      width: width,
      child: DropdownMenu<T>(
        enabled:              enabled,
        label:                label != null ? Text(label!) : null,
        hintText:             hint,
        initialSelection:     value,
        onSelected:           onSelected,
        enableSearch:         false,
        inputDecorationTheme: Theme.of(context).inputDecorationTheme,
        textStyle:            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: ext.textPrimary,
                              ),
        dropdownMenuEntries: options.map((o) {
          return DropdownMenuEntry<T>(
            value:      o.value,
            label:      o.label,
            leadingIcon: o.icon != null
                ? Icon(o.icon, size: 14, color: ext.textMuted)
                : null,
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
              foregroundColor: WidgetStatePropertyAll(ext.textSecondary),
            ),
          );
        }).toList(),
      ),
    );
  }
}
