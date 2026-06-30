import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_field.dart';
import '../../data/providers/custom_fields_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_controls.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/molecules/app_dropdown.dart';
import '../../ui/organisms/app_dialog.dart';

/// Opens the manage-custom-fields sheet.
Future<void> showManageFieldsDialog(
  BuildContext context, {
  required String entityType, // 'contact' | 'company'
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ManageFieldsDialog(entityType: entityType),
  );
}

class ManageFieldsDialog extends ConsumerStatefulWidget {
  const ManageFieldsDialog({super.key, required this.entityType});
  final String entityType;

  @override
  ConsumerState<ManageFieldsDialog> createState() => _ManageFieldsDialogState();
}

class _ManageFieldsDialogState extends ConsumerState<ManageFieldsDialog> {
  bool _adding = false;

  void _openAddForm() => setState(() => _adding = true);
  void _closeAddForm() => setState(() => _adding = false);

  String get _entityLabel =>
      widget.entityType == 'contact' ? 'Contact' : 'Company';

  @override
  Widget build(BuildContext context) {
    final defsAsync = ref.watch(customFieldDefsProvider(widget.entityType));

    return AppDialog(
      title: 'Custom fields · $_entityLabel',
      width: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          defsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(LinearSpacing.lg),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => _ErrorRow(e.toString()),
            data: (defs) => defs.isEmpty && !_adding
                ? _EmptyState(onAdd: _openAddForm)
                : _DefList(
                    defs:       defs,
                    entityType: widget.entityType,
                  ),
          ),
          if (_adding) ...[
            if (defsAsync.value?.isNotEmpty == true)
              const Divider(height: LinearSpacing.xl),
            _AddFieldForm(
              entityType: widget.entityType,
              nextSortOrder: (defsAsync.value?.length ?? 0),
              onSaved: _closeAddForm,
              onCancel: _closeAddForm,
            ),
          ],
        ],
      ),
      actions: [
        if (!_adding)
          AppButton(
            label: 'Add field',
            variant: AppButtonVariant.outlined,
            icon: Icons.add,
            onPressed: _openAddForm,
          ),
      ],
    );
  }
}

// ── Field list ─────────────────────────────────────────────────────────────────

class _DefList extends ConsumerWidget {
  const _DefList({required this.defs, required this.entityType});
  final List<CustomFieldDef> defs;
  final String entityType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: defs.map((def) => _DefRow(def: def, entityType: entityType)).toList(),
    );
  }
}

class _DefRow extends ConsumerWidget {
  const _DefRow({required this.def, required this.entityType});
  final CustomFieldDef def;
  final String entityType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;

    Future<void> delete() async {
      final confirmed = await AppDialog.confirm(
        context,
        title: 'Delete "${def.label}"?',
        message:
            'The field definition will be removed. Stored values are kept in the database '
            'but will no longer appear in the UI.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed) return;
      try {
        await ref
            .read(customFieldDefsProvider(entityType).notifier)
            .remove(def.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: LinearColors.danger,
            ),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
      child: Row(
        children: [
          Icon(def.fieldType.icon, size: 14, color: ext.textMuted),
          const SizedBox(width: LinearSpacing.sm),
          Expanded(
            child: Text(
              def.label,
              style: text.bodySmall?.copyWith(color: ext.textPrimary),
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          _TypeBadge(def.fieldType),
          if (def.isUnique) ...[
            const SizedBox(width: LinearSpacing.xs),
            _UniqueBadge(),
          ],
          const SizedBox(width: LinearSpacing.sm),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete field',
            iconSize: 15,
            onPressed: delete,
          ),
        ],
      ),
    );
  }
}

// ── Add-field form ─────────────────────────────────────────────────────────────

class _AddFieldForm extends ConsumerStatefulWidget {
  const _AddFieldForm({
    required this.entityType,
    required this.nextSortOrder,
    required this.onSaved,
    required this.onCancel,
  });

  final String entityType;
  final int nextSortOrder;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<_AddFieldForm> createState() => _AddFieldFormState();
}

class _AddFieldFormState extends ConsumerState<_AddFieldForm> {
  final _labelCtrl   = TextEditingController();
  final _optionsCtrl = TextEditingController();
  CustomFieldType _type     = CustomFieldType.text;
  bool            _isUnique = false;
  bool            _saving   = false;
  String?         _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label is required');
      return;
    }
    final fieldKey = CustomFieldDefInput.keyFromLabel(label);
    if (fieldKey.isEmpty) {
      setState(() => _error = 'Label must contain at least one letter or number');
      return;
    }

    final orgId = ref.read(currentOrgIdProvider).value;
    if (orgId == null) {
      setState(() => _error = 'No organisation selected');
      return;
    }

    final options = _type == CustomFieldType.select
        ? _optionsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    setState(() { _saving = true; _error = null; });

    try {
      await ref
          .read(customFieldDefsProvider(widget.entityType).notifier)
          .add(CustomFieldDefInput(
            orgId:      orgId,
            entityType: widget.entityType,
            label:      label,
            fieldKey:   fieldKey,
            fieldType:  _type,
            options:    options,
            isUnique:   _isUnique,
            sortOrder:  widget.nextSortOrder,
          ));
      widget.onSaved();
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ADD A FIELD',
          style: text.labelSmall?.copyWith(
            color: context.linearExt.textMuted,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: LinearSpacing.base),
        AppTextField(
          label: 'Label',
          controller: _labelCtrl,
          autofocus: true,
          errorText: _error,
        ),
        const SizedBox(height: LinearSpacing.base),
        AppSelect<CustomFieldType>(
          label: 'Type',
          value: _type,
          width: double.infinity,
          options: CustomFieldType.values
              .map((t) => AppSelectOption(value: t, label: t.label))
              .toList(),
          onSelected: (v) {
            if (v != null) setState(() { _type = v; _error = null; });
          },
        ),
        if (_type == CustomFieldType.select) ...[
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Options (comma-separated)',
            hint: 'e.g. Bronze, Silver, Gold',
            controller: _optionsCtrl,
          ),
        ],
        const SizedBox(height: LinearSpacing.base),
        AppCheckbox(
          value: _isUnique,
          onChanged: (v) => setState(() => _isUnique = v ?? false),
          label: 'Require unique values across all records',
        ),
        const SizedBox(height: LinearSpacing.base),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              onPressed: _saving ? null : widget.onCancel,
            ),
            const SizedBox(width: LinearSpacing.sm),
            AppButton(
              label: 'Add field',
              variant: AppButtonVariant.filled,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Badges ─────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);
  final CustomFieldType type;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: type.label,
      color: LinearColors.accent.withValues(alpha: 0.15),
      textColor: LinearColors.accent,
    );
  }
}

class _UniqueBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: 'Unique',
      color: LinearColors.success.withValues(alpha: 0.12),
      textColor: LinearColors.success,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.textColor});
  final String label;
  final Color  color;
  final Color  textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: textColor, fontSize: 10),
      ),
    );
  }
}

// ── Empty & error states ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune_rounded, size: 28, color: context.linearExt.textMuted),
          const SizedBox(height: LinearSpacing.sm),
          Text(
            'No custom fields yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: LinearSpacing.xs),
          AppButton(
            label: 'Add your first field',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: LinearColors.danger),
      ),
    );
  }
}
