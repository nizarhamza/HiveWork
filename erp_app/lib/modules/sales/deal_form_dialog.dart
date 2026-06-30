import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/deal.dart';
import '../../data/providers/deals_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/molecules/app_dropdown.dart';
import '../../ui/molecules/app_form_row.dart';
import '../../ui/organisms/app_dialog.dart';
import 'client_picker_dialog.dart';

Future<bool> showDealForm(BuildContext context, {Deal? deal}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => DealFormDialog(deal: deal),
      ) ??
      false;
}

class DealFormDialog extends ConsumerStatefulWidget {
  const DealFormDialog({super.key, this.deal});
  final Deal? deal;

  @override
  ConsumerState<DealFormDialog> createState() => _DealFormDialogState();
}

class _DealFormDialogState extends ConsumerState<DealFormDialog> {
  bool get _isEdit => widget.deal != null;

  late final _titleCtrl = TextEditingController(text: widget.deal?.title ?? '');
  late final _notesCtrl = TextEditingController(text: widget.deal?.notes ?? '');

  late DealStage _stage       = widget.deal?.stage ?? DealStage.lead;
  late int?      _probability = widget.deal?.probability;

  // Client
  late String? _contactId   = widget.deal?.contactId;
  late String? _contactName = widget.deal?.contactName;
  late String? _companyId   = widget.deal?.companyId;
  late String? _companyName = widget.deal?.companyName;

  String? _titleError;
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Client helpers ───────────────────────────────────────────────────────────

  Future<void> _pickClient() async {
    final result = await showClientPicker(
      context,
      initialContactId: _contactId,
      initialCompanyId: _companyId,
    );
    if (result != null) {
      setState(() {
        _contactId   = result.contactId;
        _contactName = result.contactName;
        _companyId   = result.companyId;
        _companyName = result.companyName;
      });
    }
  }

  void _clearClient() => setState(() {
        _contactId = _contactName = _companyId = _companyName = null;
      });

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }
    setState(() { _loading = true; _error = null; _titleError = null; });

    try {
      final orgId = await ref.read(currentOrgIdProvider.future);
      if (orgId == null) throw Exception('No organisation selected');

      final cleanNotes = _notesCtrl.text.trim();

      final input = (_isEdit
              ? widget.deal!.toInput()
              : DealInput(orgId: orgId, title: title))
          .copyWith(
            orgId:       orgId,
            title:       title,
            stage:       _stage,
            probability: _probability,
            notes:       cleanNotes.isEmpty ? null : cleanNotes,
            contactId:   _contactId,
            companyId:   _companyId,
          );

      if (_isEdit) {
        await ref.read(dealsProvider.notifier).updateDeal(widget.deal!.id, input);
      } else {
        await ref.read(dealsProvider.notifier).create(input);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _isEdit ? 'Edit deal' : 'New deal',
      width: 520,
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          onPressed: _loading ? null : () => Navigator.pop(context, false),
        ),
        AppButton(
          label: _isEdit ? 'Save' : 'Create deal',
          variant: AppButtonVariant.filled,
          loading: _loading,
          onPressed: _save,
        ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          AppFormRow(
            label: 'Title *',
            child: AppTextField(
              controller: _titleCtrl,
              hint: 'e.g. Acme Corp — Website Redesign',
              autofocus: true,
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: LinearSpacing.base),

          // Stage
          AppFormRow(
            label: 'Stage',
            child: AppSelect<DealStage>(
              value: _stage,
              options: DealStage.values
                  .map((s) => AppSelectOption(value: s, label: s.label))
                  .toList(),
              onSelected: (s) { if (s != null) setState(() => _stage = s); },
            ),
          ),
          const SizedBox(height: LinearSpacing.base),

          // Client
          AppFormRow(
            label: 'Client',
            child: _ClientField(
              contactId:   _contactId,
              contactName: _contactName,
              companyId:   _companyId,
              companyName: _companyName,
              onPick:      _pickClient,
              onClear:     _clearClient,
            ),
          ),
          const SizedBox(height: LinearSpacing.base),

          // Probability
          AppFormRow(
            label: 'Probability',
            child: AppSelect<int?>(
              value: _probability,
              hint: 'Not set',
              options: const [
                AppSelectOption(value: null, label: 'Not set'),
                AppSelectOption(value: 10,   label: '10%'),
                AppSelectOption(value: 25,   label: '25%'),
                AppSelectOption(value: 50,   label: '50%'),
                AppSelectOption(value: 75,   label: '75%'),
                AppSelectOption(value: 90,   label: '90%'),
                AppSelectOption(value: 100,  label: '100%'),
              ],
              onSelected: (v) => setState(() => _probability = v),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),

          // Notes
          AppFormRow(
            label: 'Notes',
            child: AppTextField(
              controller: _notesCtrl,
              hint: 'Add notes…',
              maxLines: 3,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.sm),
            Text(_error!,
                style: const TextStyle(color: LinearColors.danger, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── Client field widget ────────────────────────────────────────────────────────

class _ClientField extends StatelessWidget {
  const _ClientField({
    required this.contactId,
    required this.contactName,
    required this.companyId,
    required this.companyName,
    required this.onPick,
    required this.onClear,
  });

  final String?      contactId;
  final String?      contactName;
  final String?      companyId;
  final String?      companyName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ext         = context.linearExt;
    final hasClient   = contactId != null || companyId != null;
    final displayName = contactName ?? companyName;

    if (hasClient && displayName != null) {
      return Row(
        children: [
          Expanded(
            child: _SelectedChip(
              icon: contactId != null
                  ? Icons.person_outline
                  : Icons.business_outlined,
              label: displayName,
              onTap: onPick,
            ),
          ),
          const SizedBox(width: LinearSpacing.xs),
          Tooltip(
            message: 'Clear client',
            child: InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(LinearRadii.md),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: ext.textMuted),
              ),
            ),
          ),
        ],
      );
    }

    return AppButton(
      label: 'Select client…',
      variant: AppButtonVariant.outlined,
      icon: Icons.person_add_outlined,
      onPressed: onPick,
    );
  }
}

// ── Shared: selected-value chip ────────────────────────────────────────────────

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData     icon;
  final String       label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LinearRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: ext.borderSubtle),
          borderRadius: BorderRadius.circular(LinearRadii.md),
          color: ext.surfaceBase,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: ext.textMuted),
            const SizedBox(width: LinearSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: text.bodySmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
