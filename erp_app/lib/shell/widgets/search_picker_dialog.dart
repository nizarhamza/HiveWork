import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

/// A ({value, label}) pair used by [showSearchPicker].
typedef PickerOption = ({String value, String label});

/// Opens a search dialog and returns the selected value, or null if dismissed.
Future<String?> showSearchPicker({
  required BuildContext context,
  required String title,
  required List<PickerOption> options,
  String? current,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SearchPickerDialog(
      title: title,
      options: options,
      current: current,
    ),
  );
}

class _SearchPickerDialog extends StatefulWidget {
  const _SearchPickerDialog({
    required this.title,
    required this.options,
    this.current,
  });

  final String title;
  final List<PickerOption> options;
  final String? current;

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  final _searchCtrl = TextEditingController();
  late List<PickerOption> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.options
          : widget.options
              .where((o) =>
                  o.value.toLowerCase().contains(q) ||
                  o.label.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final accent = context.colors.primary;

    return Dialog(
      backgroundColor: ext.surfaceBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        side: BorderSide(color: ext.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.md, LinearSpacing.md, LinearSpacing.xs, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: context.text.titleSmall),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        size: 16, color: ext.textMuted),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // ── Search field ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(LinearSpacing.sm),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: context.text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search…',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 16, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ),

            const Divider(height: 1),

            // ── List ────────────────────────────────────────────────────────
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(LinearSpacing.xl),
                      child: Text(
                        'No results',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall
                            ?.copyWith(color: ext.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: LinearSpacing.xs),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final opt      = _filtered[i];
                        final isSelected = opt.value == widget.current;
                        return InkWell(
                          onTap: () => Navigator.pop(context, opt.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: LinearSpacing.md,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    opt.label,
                                    style: context.text.bodySmall?.copyWith(
                                      color: isSelected
                                          ? accent
                                          : ext.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded,
                                      size: 14, color: accent),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Picker trigger button ──────────────────────────────────────────────────────

/// A button styled like an input field that opens a [showSearchPicker] dialog.
class SearchPickerField extends StatelessWidget {
  const SearchPickerField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
    this.enabled = true,
  });

  final String? value;
  final String  hint;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          enabled: enabled,
          suffixIcon: Icon(
            Icons.unfold_more_rounded,
            size: 16,
            color: enabled ? ext.textMuted : ext.textMuted.withValues(alpha: 0.5),
          ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        child: Text(
          value ?? hint,
          style: context.text.bodyMedium?.copyWith(
            color: (value != null && value!.isNotEmpty)
                ? (enabled ? ext.textPrimary : ext.textMuted)
                : ext.textMuted,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
