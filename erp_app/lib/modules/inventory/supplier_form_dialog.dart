import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/supplier.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/organisms/app_dialog.dart';

Future<bool> showSupplierForm(BuildContext context, {Supplier? supplier}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => SupplierFormDialog(supplier: supplier),
      ) ??
      false;
}

class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({super.key, this.supplier});
  final Supplier? supplier;

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  bool get _isEdit => widget.supplier != null;

  late final _nameCtrl         = TextEditingController(text: widget.supplier?.name         ?? '');
  late final _taxIdCtrl        = TextEditingController(text: widget.supplier?.taxId        ?? '');
  late final _currencyCtrl     = TextEditingController(text: widget.supplier?.currency     ?? '');
  late final _paymentTermsCtrl = TextEditingController(text: widget.supplier?.paymentTerms ?? '');

  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _currencyCtrl.dispose();
    _paymentTermsCtrl.dispose();
    super.dispose();
  }

  String? _trim(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Supplier name is required');
      return;
    }

    final orgId = ref.read(currentOrgIdProvider).value;
    if (orgId == null) {
      setState(() => _error = 'No organisation selected');
      return;
    }

    final input = SupplierInput(
      orgId:        orgId,
      name:         name,
      taxId:        _trim(_taxIdCtrl),
      currency:     _trim(_currencyCtrl),
      paymentTerms: _trim(_paymentTermsCtrl),
    );

    setState(() { _loading = true; _error = null; });
    try {
      if (_isEdit) {
        await ref.read(suppliersProvider.notifier).updateSupplier(widget.supplier!.id, input);
      } else {
        await ref.read(suppliersProvider.notifier).create(input);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppDialog(
      title: _isEdit ? 'Edit supplier' : 'New supplier',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label:      'Supplier name',
            controller: _nameCtrl,
            autofocus:  true,
            errorText:  _error != null && _nameCtrl.text.isEmpty ? _error : null,
          ),
          const SizedBox(height: LinearSpacing.base),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(label: 'Tax ID', controller: _taxIdCtrl),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: AppTextField(
                  label:      'Currency',
                  controller: _currencyCtrl,
                  hint:       'e.g. EUR',
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label:      'Payment terms',
            controller: _paymentTermsCtrl,
            hint:       'e.g. Net 30',
          ),
          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.sm),
            Text(
              _error!,
              style: text.labelSmall?.copyWith(color: LinearColors.danger),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label:     'Cancel',
          variant:   AppButtonVariant.ghost,
          onPressed: _loading ? null : () => Navigator.pop(context, false),
        ),
        AppButton(
          label:     _isEdit ? 'Save changes' : 'Create supplier',
          variant:   AppButtonVariant.filled,
          loading:   _loading,
          onPressed: _save,
        ),
      ],
    );
  }
}
