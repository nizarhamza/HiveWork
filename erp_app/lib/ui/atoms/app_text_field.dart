import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// Standard text field — styled by inputDecorationTheme from the theme.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.errorText,
    this.helperText,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return TextField(
      controller:     controller,
      obscureText:    obscure,
      keyboardType:   keyboardType,
      maxLines:       maxLines,
      onChanged:      onChanged,
      autofocus:      autofocus,
      focusNode:      focusNode,
      style:          Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ext.textPrimary,
                      ),
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        errorText:  errorText,
        helperText: helperText,
        helperStyle: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// Search field with leading icon and clear button.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hint = 'Search…',
    this.onChanged,
    this.controller,
    this.autofocus = false,
    this.focusNode,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final _ctrl = widget.controller ?? TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
  }

  void _onText() {
    final has = _ctrl.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return TextField(
      controller:  _ctrl,
      autofocus:   widget.autofocus,
      focusNode:   widget.focusNode,
      onChanged:   widget.onChanged,
      style:       Theme.of(context).textTheme.bodyMedium?.copyWith(
                     color: ext.textPrimary,
                   ),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(Icons.search, size: 15, color: ext.textMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        suffixIcon: _hasText
            ? GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  widget.onChanged?.call('');
                },
                child: Icon(Icons.close, size: 14, color: ext.textMuted),
              )
            : null,
      ),
    );
  }
}

/// Click-to-edit inline field. Shows [value] as text; tapping enters edit mode.
class AppInlineEditable extends StatefulWidget {
  const AppInlineEditable({
    super.key,
    required this.value,
    required this.onSubmit,
    this.placeholder = '—',
    this.style,
  });

  final String value;
  final ValueChanged<String> onSubmit;
  final String placeholder;
  final TextStyle? style;

  @override
  State<AppInlineEditable> createState() => _AppInlineEditableState();
}

class _AppInlineEditableState extends State<AppInlineEditable> {
  bool _editing = false;
  late final _ctrl = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(AppInlineEditable old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  void _submit() {
    widget.onSubmit(_ctrl.text);
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final style = widget.style ?? Theme.of(context).textTheme.bodyMedium;

    if (_editing) {
      return TextField(
        controller: _ctrl,
        focusNode:  _focus,
        style:      style?.copyWith(color: ext.textPrimary),
        onSubmitted: (_) => _submit(),
        onTapOutside: (_) => _submit(),
        autofocus:  true,
        decoration: InputDecoration(
          isDense:         true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            borderSide: const BorderSide(color: LinearColors.accent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
          ),
        ),
      );
    }

    final display = widget.value.isEmpty ? widget.placeholder : widget.value;
    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            border: Border.all(color: Colors.transparent),
          ),
          child: Text(
            display,
            style: widget.value.isEmpty
                ? style?.copyWith(color: ext.textMuted)
                : style?.copyWith(color: ext.textPrimary),
          ),
        ),
      ),
    );
  }
}
