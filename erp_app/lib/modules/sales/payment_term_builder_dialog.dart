import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/payment_term_template.dart';
import '../../theme/linear_tokens.dart';

/// Opens the builder and returns the [PaymentTermTemplateInput] on save,
/// or null on cancel.
Future<PaymentTermTemplateInput?> showPaymentTermBuilder(
  BuildContext context, {
  PaymentTermTemplate? initial,
}) {
  return showDialog<PaymentTermTemplateInput>(
    context: context,
    builder: (_) => _PaymentTermBuilderDialog(initial: initial),
  );
}

// ── Internal installment row state ─────────────────────────────────────────────

class _InstallmentRow {
  _InstallmentRow()
      : percentCtrl    = TextEditingController(),
        customLabelCtrl = TextEditingController(),
        labelDropdown   = kMilestoneLabels.first;

  _InstallmentRow.fromInstallment(PaymentInstallment inst)
      : percentCtrl    = TextEditingController(text: inst.percent.toString()),
        customLabelCtrl = TextEditingController(
          text: kMilestoneLabels.contains(inst.label) ? '' : inst.label,
        ),
        labelDropdown =
            kMilestoneLabels.contains(inst.label) ? inst.label : null;

  final TextEditingController percentCtrl;
  final TextEditingController customLabelCtrl;
  String? labelDropdown; // null = "Autre…" / free text

  bool get isCustom => labelDropdown == null;

  String get effectiveLabel =>
      isCustom ? customLabelCtrl.text.trim() : (labelDropdown ?? '');

  int get percent => int.tryParse(percentCtrl.text.trim()) ?? 0;

  bool get isValid => percent > 0 && percent <= 100 && effectiveLabel.isNotEmpty;

  PaymentInstallment toInstallment(int order) => PaymentInstallment(
        order:   order,
        percent: percent,
        label:   effectiveLabel,
      );

  void dispose() {
    percentCtrl.dispose();
    customLabelCtrl.dispose();
  }
}

// ── Dialog ─────────────────────────────────────────────────────────────────────

class _PaymentTermBuilderDialog extends StatefulWidget {
  const _PaymentTermBuilderDialog({this.initial});
  final PaymentTermTemplate? initial;

  @override
  State<_PaymentTermBuilderDialog> createState() =>
      _PaymentTermBuilderDialogState();
}

class _PaymentTermBuilderDialogState
    extends State<_PaymentTermBuilderDialog> {
  late final TextEditingController _nameCtrl;
  late final List<_InstallmentRow>  _rows;
  bool _nameIsAuto = true;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _rows = widget.initial!.installments
          .map(_InstallmentRow.fromInstallment)
          .toList();
      _nameCtrl   = TextEditingController(text: widget.initial!.name);
      _nameIsAuto = false;
    } else {
      _rows     = [_InstallmentRow()];
      _nameCtrl = TextEditingController();
      _nameIsAuto = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String get _autoName {
    final insts = _rows
        .asMap()
        .entries
        .map((e) => PaymentInstallment(
              order:   e.key + 1,
              percent: e.value.percent,
              label:   e.value.effectiveLabel,
            ))
        .toList();
    return PaymentTermTemplateInput.autoName(insts);
  }

  int get _total => _rows.fold(0, (s, r) => s + r.percent);

  bool get _canSave {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_rows.isEmpty || _rows.length > 5) return false;
    if (_total != 100) return false;
    return _rows.every((r) => r.isValid);
  }

  void _onInstallmentChanged() {
    setState(() {
      if (_nameIsAuto) _nameCtrl.text = _autoName;
    });
  }

  void _addRow() {
    if (_rows.length >= 5) return;
    setState(() {
      _rows.add(_InstallmentRow());
      if (_nameIsAuto) _nameCtrl.text = _autoName;
    });
  }

  void _removeRow(int index) {
    _rows[index].dispose();
    setState(() {
      _rows.removeAt(index);
      if (_nameIsAuto) _nameCtrl.text = _autoName;
    });
  }

  void _save() {
    if (!_canSave) return;
    final input = PaymentTermTemplateInput(
      name: _nameCtrl.text.trim(),
      installments: _rows
          .asMap()
          .entries
          .map((e) => e.value.toInstallment(e.key + 1))
          .toList(),
    );
    Navigator.pop(context, input);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = context.text;
    final isEdit = widget.initial != null;
    final total = _total;

    return Dialog(
      backgroundColor: ext.surfaceBase,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LinearRadii.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(LinearSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              Text(
                isEdit ? 'Edit Payment Term' : 'New Payment Term',
                style: text.titleMedium,
              ),
              const SizedBox(height: LinearSpacing.lg),

              // ── Name ───────────────────────────────────────────────────────
              Text('Name',
                  style: text.labelSmall?.copyWith(color: ext.textMuted)),
              const SizedBox(height: LinearSpacing.xs),
              _styledField(
                child: TextField(
                  controller: _nameCtrl,
                  style: text.bodySmall?.copyWith(color: ext.textPrimary),
                  decoration: InputDecoration.collapsed(
                    hintText:  'e.g. 30/70 — Deposit / Delivery',
                    hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                  ),
                  onChanged: (_) => setState(() => _nameIsAuto = false),
                ),
                ext: ext,
              ),
              const SizedBox(height: LinearSpacing.lg),

              // ── Installments header ────────────────────────────────────────
              Text('Installments',
                  style: text.labelSmall?.copyWith(color: ext.textMuted)),
              const SizedBox(height: LinearSpacing.sm),

              // ── Installment rows ───────────────────────────────────────────
              ..._rows.asMap().entries.map((entry) {
                final i   = entry.key;
                final row = entry.value;
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: LinearSpacing.sm),
                  child: _InstallmentRowWidget(
                    index:  i,
                    row:    row,
                    canRemove: _rows.length > 1,
                    ext:    ext,
                    text:   text,
                    onChanged: _onInstallmentChanged,
                    onLabelChanged: (val) {
                      setState(() {
                        row.labelDropdown = val;
                        if (_nameIsAuto) _nameCtrl.text = _autoName;
                      });
                    },
                    onRemove: () => _removeRow(i),
                  ),
                );
              }),

              // ── Add installment ────────────────────────────────────────────
              if (_rows.length < 5)
                GestureDetector(
                  onTap: _addRow,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: ext.textMuted),
                        const SizedBox(width: LinearSpacing.xs),
                        Text('Add installment',
                            style: text.bodySmall
                                ?.copyWith(color: ext.textSecondary)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: LinearSpacing.md),

              // ── Total + actions ────────────────────────────────────────────
              Row(
                children: [
                  _TotalBadge(total: total, ext: ext, text: text),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: ext.textMuted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: Text('Cancel', style: text.labelMedium),
                  ),
                  const SizedBox(width: LinearSpacing.sm),
                  FilledButton(
                    onPressed: _canSave ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: LinearColors.accent,
                      disabledBackgroundColor:
                          LinearColors.accent.withAlpha(80),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                    ),
                    child: Text('Save',
                        style: text.labelMedium
                            ?.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledField({required Widget child, required LinearExt ext}) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm, vertical: LinearSpacing.xs + 2),
        decoration: BoxDecoration(
          color: ext.surfaceRaised,
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          border: Border.all(color: ext.borderSubtle),
        ),
        child: child,
      );
}

// ── Installment row widget ─────────────────────────────────────────────────────

class _InstallmentRowWidget extends StatelessWidget {
  const _InstallmentRowWidget({
    required this.index,
    required this.row,
    required this.canRemove,
    required this.ext,
    required this.text,
    required this.onChanged,
    required this.onLabelChanged,
    required this.onRemove,
  });

  final int             index;
  final _InstallmentRow row;
  final bool            canRemove;
  final LinearExt       ext;
  final TextTheme       text;
  final VoidCallback    onChanged;
  final ValueChanged<String?> onLabelChanged;
  final VoidCallback    onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Row number
        SizedBox(
          width: 24,
          child: Text(
            '#${index + 1}',
            style: text.bodySmall?.copyWith(color: ext.textMuted),
          ),
        ),
        const SizedBox(width: LinearSpacing.xs),

        // Percent input
        SizedBox(
          width: 56,
          child: _FieldBox(
            ext: ext,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.percentCtrl,
                    style: text.bodySmall?.copyWith(color: ext.textPrimary),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MaxValueFormatter(99),
                    ],
                    decoration: InputDecoration.collapsed(
                      hintText: '0',
                      hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                Text('%',
                    style: text.bodySmall?.copyWith(color: ext.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: LinearSpacing.sm),

        // Label dropdown (or text field when "Autre…")
        Expanded(
          child: row.isCustom
              ? _FieldBox(
                  ext: ext,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.customLabelCtrl,
                          style: text.bodySmall
                              ?.copyWith(color: ext.textPrimary),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Custom label…',
                            hintStyle: text.bodySmall
                                ?.copyWith(color: ext.textMuted),
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onLabelChanged(kMilestoneLabels.first),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(Icons.close,
                              size: 13, color: ext.textMuted),
                        ),
                      ),
                    ],
                  ),
                )
              : _FieldBox(
                  ext: ext,
                  child: DropdownButton<String?>(
                    value: row.labelDropdown,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    dropdownColor: ext.surfaceBase,
                    style:
                        text.bodySmall?.copyWith(color: ext.textPrimary),
                    items: [
                      ...kMilestoneLabels.map(
                        (lbl) => DropdownMenuItem<String?>(
                          value: lbl,
                          child: Text(lbl,
                              style: text.bodySmall
                                  ?.copyWith(color: ext.textPrimary)),
                        ),
                      ),
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Autre…',
                            style: text.bodySmall
                                ?.copyWith(color: ext.textMuted)),
                      ),
                    ],
                    onChanged: onLabelChanged,
                  ),
                ),
        ),
        const SizedBox(width: LinearSpacing.sm),

        // Remove button
        SizedBox(
          width: 20,
          child: canRemove
              ? GestureDetector(
                  onTap: onRemove,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(Icons.close, size: 15, color: ext.textMuted),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Total badge ────────────────────────────────────────────────────────────────

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({
    required this.total,
    required this.ext,
    required this.text,
  });

  final int      total;
  final LinearExt ext;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final ok    = total == 100;
    final color = ok ? LinearColors.success : LinearColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.info_outline,
          size: 14,
          color: color,
        ),
        const SizedBox(width: LinearSpacing.xs),
        Text(
          'Total: $total%${ok ? '' : ' (must be 100%)'}',
          style: text.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

// ── Shared bordered field box ──────────────────────────────────────────────────

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, required this.ext});
  final Widget    child;
  final LinearExt ext;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm, vertical: LinearSpacing.xs + 2),
        decoration: BoxDecoration(
          color:        ext.surfaceRaised,
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          border:       Border.all(color: ext.borderSubtle),
        ),
        child: child,
      );
}

// ── Input formatter: clamp to max value ───────────────────────────────────────

class _MaxValueFormatter extends TextInputFormatter {
  const _MaxValueFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final n = int.tryParse(newValue.text);
    if (n != null && n > max) return oldValue;
    return newValue;
  }
}
