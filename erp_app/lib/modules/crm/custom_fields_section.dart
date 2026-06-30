import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_field.dart';
import '../../data/providers/custom_fields_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/molecules/app_dropdown.dart';
import 'manage_fields_dialog.dart';

/// Renders the "Custom fields" section inside a record's properties panel.
///
/// [entityType] is 'contact' or 'company'.
/// [entityId] is the record's id (used for uniqueness checks).
/// [customFields] is the current values map from the record.
/// [onUpdate] is called with a new merged values map when the user commits a change.
class CustomFieldsSection extends ConsumerWidget {
  const CustomFieldsSection({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.customFields,
    required this.onUpdate,
  });

  final String entityType;
  final String entityId;
  final Map<String, dynamic> customFields;
  final Future<void> Function(Map<String, dynamic>) onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = context.linearExt;
    final defsAsync = ref.watch(customFieldDefsProvider(entityType));
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header row
        Text(
          'CUSTOM FIELDS',
          style: text.labelSmall?.copyWith(
            color: ext.textMuted,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: LinearSpacing.sm),
        defsAsync.when(
          loading: () => const SizedBox(
            height: 24,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          ),
          error: (e, _) => Text(
            e.toString(),
            style: text.labelSmall?.copyWith(color: LinearColors.danger),
          ),
          data: (defs) {
            if (defs.isEmpty) {
              return GestureDetector(
                onTap: () => showManageFieldsDialog(context, entityType: entityType),
                child: Text(
                  'No custom fields — tap to add',
                  style: text.bodySmall?.copyWith(
                    color: ext.textMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: defs
                  .map((def) => _FieldRow(
                        def:          def,
                        entityType:   entityType,
                        entityId:     entityId,
                        currentValue: customFields[def.fieldKey],
                        allValues:    customFields,
                        onUpdate:     onUpdate,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Manage button (gear icon) ──────────────────────────────────────────────────

class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.entityType});
  final String entityType;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Manage fields',
      child: InkWell(
        onTap: () => showManageFieldsDialog(context, entityType: entityType),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
        child: Padding(
          padding: const EdgeInsets.all(LinearSpacing.xs),
          child: Icon(
            Icons.tune_rounded,
            size: 13,
            color: context.linearExt.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Single field row ───────────────────────────────────────────────────────────

class _FieldRow extends ConsumerStatefulWidget {
  const _FieldRow({
    required this.def,
    required this.entityType,
    required this.entityId,
    required this.currentValue,
    required this.allValues,
    required this.onUpdate,
  });

  final CustomFieldDef def;
  final String entityType;
  final String entityId;
  final dynamic currentValue;
  final Map<String, dynamic> allValues;
  final Future<void> Function(Map<String, dynamic>) onUpdate;

  @override
  ConsumerState<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends ConsumerState<_FieldRow> {
  bool    _saving = false;
  String? _error;

  Future<void> _submit(dynamic newValue) async {
    // Uniqueness check for fields that require it.
    if (widget.def.isUnique && newValue != null && newValue.toString().isNotEmpty) {
      final orgId = ref.read(currentOrgIdProvider).value;
      if (orgId != null) {
        final isUnique = await ref
            .read(customFieldRepositoryProvider)
            .isValueUnique(
              orgId:      orgId,
              entityType: widget.entityType,
              fieldKey:   widget.def.fieldKey,
              value:      newValue,
              excludeId:  widget.entityId,
            );
        if (!isUnique) {
          if (mounted) {
            setState(() => _error =
                '"${widget.def.label}" must be unique — this value is already in use.');
          }
          return;
        }
      }
    }

    setState(() { _saving = true; _error = null; });
    try {
      final updated = Map<String, dynamic>.from(widget.allValues)
        ..[widget.def.fieldKey] = newValue;
      await widget.onUpdate(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;

    Widget editor;
    switch (widget.def.fieldType) {
      case CustomFieldType.text:
        editor = AppInlineEditable(
          value:       widget.currentValue?.toString() ?? '',
          placeholder: '—',
          style:       text.bodySmall,
          onSubmit:    (v) => _submit(v.trim().isEmpty ? null : v.trim()),
        );
      case CustomFieldType.number:
        editor = _NumberField(
          value:    widget.currentValue,
          onSubmit: _submit,
        );
      case CustomFieldType.select:
        editor = _SelectField(
          value:   widget.currentValue?.toString(),
          options: widget.def.options,
          onSelect: _submit,
        );
      case CustomFieldType.boolean:
        editor = _BoolField(
          value:      widget.currentValue as bool?,
          saving:     _saving,
          onChanged:  _submit,
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.def.label,
                    style: text.labelSmall?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(child: editor),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.xxs),
            Text(
              _error!,
              style: text.labelSmall?.copyWith(color: LinearColors.danger, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Per-type editors ───────────────────────────────────────────────────────────

class _NumberField extends StatefulWidget {
  const _NumberField({required this.value, required this.onSubmit});
  final dynamic value;
  final Future<void> Function(dynamic) onSubmit;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  bool _editing = false;
  late final _ctrl = TextEditingController(
    text: widget.value != null ? widget.value.toString() : '',
  );

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = widget.value != null ? widget.value.toString() : '';
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    final raw = _ctrl.text.trim();
    final num? parsed = raw.isEmpty ? null : num.tryParse(raw);
    widget.onSubmit(parsed);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    if (_editing) {
      final ext = context.linearExt;
      return TextField(
        controller: _ctrl,
        autofocus:  true,
        style:      style?.copyWith(color: ext.textPrimary),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
        ],
        onSubmitted: (_) => _submit(),
        onTapOutside: (_) => _submit(),
        decoration: InputDecoration(
          isDense: true,
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

    final ext = context.linearExt;
    final display = widget.value != null ? widget.value.toString() : '';
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
            display.isEmpty ? '—' : display,
            style: display.isEmpty
                ? style?.copyWith(color: ext.textMuted)
                : style?.copyWith(color: ext.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.options,
    required this.onSelect,
  });

  final String? value;
  final List<String> options;
  final Future<void> Function(dynamic) onSelect;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;

    if (options.isEmpty) {
      return Text('No options defined', style: text.bodySmall?.copyWith(color: ext.textMuted));
    }

    return PopupMenuButton<String?>(
      tooltip: 'Pick a value',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 160),
      onSelected: (v) => onSelect(v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          height: 32,
          child: Text('— clear —',
              style: text.bodySmall?.copyWith(color: ext.textMuted)),
        ),
        ...options.map((opt) => PopupMenuItem<String?>(
              value: opt,
              height: 32,
              child: Row(
                children: [
                  if (opt == value)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 6),
                      child: Icon(Icons.check, size: 12, color: LinearColors.accent),
                    ),
                  Text(opt,
                      style: text.bodySmall?.copyWith(
                        color: opt == value
                            ? LinearColors.accent
                            : ext.textPrimary,
                      )),
                ],
              ),
            )),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? '—',
              style: text.bodySmall?.copyWith(
                color: value != null
                    ? ext.textPrimary
                    : ext.textMuted,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 12, color: ext.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BoolField extends StatelessWidget {
  const _BoolField({
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final bool? value;
  final bool saving;
  final Future<void> Function(dynamic) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          width: 36,
          child: saving
              ? const Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                )
              : Transform.scale(
                  scale: 0.72,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value:     value ?? false,
                    onChanged: (v) => onChanged(v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
        ),
        const SizedBox(width: LinearSpacing.xs),
        Text(
          (value ?? false) ? 'Yes' : 'No',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: LinearColors.textSecondary),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CustomFieldsFormSection — used inside create/edit dialogs
// ══════════════════════════════════════════════════════════════════════════════

/// Renders custom-field inputs for use inside a form dialog.
///
/// [entityType] is 'contact' or 'company'.
/// [initialValues] is the record's existing customFields map (pass `{}` for new records).
/// [onChanged] is called every time any field value changes; receives the full updated map.
class CustomFieldsFormSection extends ConsumerStatefulWidget {
  const CustomFieldsFormSection({
    super.key,
    required this.entityType,
    required this.initialValues,
    required this.onChanged,
  });

  final String entityType;
  final Map<String, dynamic> initialValues;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  ConsumerState<CustomFieldsFormSection> createState() =>
      _CustomFieldsFormSectionState();
}

class _CustomFieldsFormSectionState
    extends ConsumerState<CustomFieldsFormSection> {
  late final Map<String, dynamic> _values = Map.from(widget.initialValues);

  void _set(String fieldKey, dynamic value) {
    setState(() {
      if (value == null ||
          (value is String && value.isEmpty)) {
        _values.remove(fieldKey);
      } else {
        _values[fieldKey] = value;
      }
    });
    widget.onChanged(Map.from(_values));
  }

  @override
  Widget build(BuildContext context) {
    final defsAsync = ref.watch(customFieldDefsProvider(widget.entityType));
    final text = Theme.of(context).textTheme;

    return defsAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, _) => const SizedBox.shrink(),
      data: (defs) {
        if (defs.isEmpty) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            const SizedBox(height: LinearSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CUSTOM FIELDS',
                    style: text.labelSmall?.copyWith(
                      color: LinearColors.textMuted,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ManageButton(entityType: widget.entityType),
              ],
            ),
            const SizedBox(height: LinearSpacing.base),
            for (final def in defs) _FormField(
              def:      def,
              value:    _values[def.fieldKey],
              onSet:    (v) => _set(def.fieldKey, v),
            ),
          ],
        );
      },
    );
  }
}

class _FormField extends StatefulWidget {
  const _FormField({
    required this.def,
    required this.value,
    required this.onSet,
  });

  final CustomFieldDef def;
  final dynamic value;
  final ValueChanged<dynamic> onSet;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late final _ctrl = TextEditingController(
    text: widget.def.fieldType != CustomFieldType.boolean
        ? (widget.value?.toString() ?? '')
        : '',
  );

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;

    switch (def.fieldType) {
      case CustomFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: LinearSpacing.base),
          child: AppTextField(
            label: def.label,
            controller: _ctrl,
            onChanged: widget.onSet,
          ),
        );

      case CustomFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: LinearSpacing.base),
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
            ],
            onChanged: (v) {
              final parsed = num.tryParse(v);
              widget.onSet(parsed ?? (v.isEmpty ? null : v));
            },
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: LinearColors.textPrimary),
            decoration: InputDecoration(labelText: def.label),
          ),
        );

      case CustomFieldType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: LinearSpacing.base),
          child: AppSelect<String>(
            label: def.label,
            value: widget.value?.toString(),
            width: double.infinity,
            options: def.options
                .map((o) => AppSelectOption(value: o, label: o))
                .toList(),
            onSelected: widget.onSet,
          ),
        );

      case CustomFieldType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: LinearSpacing.base),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  def.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: LinearColors.textPrimary),
                ),
              ),
              Transform.scale(
                scale: 0.72,
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: widget.value as bool? ?? false,
                  onChanged: widget.onSet,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        );
    }
  }
}
