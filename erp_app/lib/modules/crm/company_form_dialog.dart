import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/company.dart';
import '../../data/providers/companies_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/molecules/app_dropdown.dart';
import '../../ui/organisms/app_dialog.dart';
import 'custom_fields_section.dart';

/// Opens the create/edit company dialog. Returns true if a company was saved.
Future<bool> showCompanyForm(BuildContext context, {Company? company}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => CompanyFormDialog(company: company),
      ) ??
      false;
}

class CompanyFormDialog extends ConsumerStatefulWidget {
  const CompanyFormDialog({super.key, this.company});
  final Company? company;

  @override
  ConsumerState<CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends ConsumerState<CompanyFormDialog> {
  bool get _isEdit => widget.company != null;

  late final _nameCtrl     = TextEditingController(text: widget.company?.name     ?? '');
  late final _industryCtrl = TextEditingController(text: widget.company?.industry ?? '');
  late final _websiteCtrl  = TextEditingController(text: widget.company?.website  ?? '');
  late final _phoneCtrl    = TextEditingController(text: widget.company?.phone    ?? '');
  late final _emailCtrl    = TextEditingController(text: widget.company?.email    ?? '');
  late final _taxIdCtrl    = TextEditingController(text: widget.company?.taxId    ?? '');
  late final _addressCtrl  = TextEditingController(text: widget.company?.address  ?? '');
  late final _notesCtrl    = TextEditingController(text: widget.company?.notes    ?? '');
  late CompanyStatus _status        = widget.company?.status ?? CompanyStatus.prospect;
  late String?       _employeeRange = widget.company?.employeeRange;
  late Map<String, dynamic> _customFields =
      Map.from(widget.company?.customFields ?? {});
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _industryCtrl.dispose();
    _websiteCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxIdCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _trim(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Company name is required');
      return;
    }

    final orgId = ref.read(currentOrgIdProvider).value;
    if (orgId == null) {
      setState(() => _error = 'No organisation selected');
      return;
    }

    final base  = widget.company?.toInput();
    final input = CompanyInput(
      orgId:         orgId,
      name:          name,
      status:        _status,
      industry:      _trim(_industryCtrl),
      website:       _trim(_websiteCtrl),
      phone:         _trim(_phoneCtrl),
      email:         _trim(_emailCtrl),
      taxId:         _trim(_taxIdCtrl),
      address:       _trim(_addressCtrl),
      notes:         _trim(_notesCtrl),
      employeeRange: _employeeRange,
      tags:          base?.tags ?? [],
      customFields:  _customFields,
    );

    setState(() { _loading = true; _error = null; });
    try {
      if (_isEdit) {
        await ref.read(companiesProvider.notifier).updateCompany(widget.company!.id, input);
      } else {
        await ref.read(companiesProvider.notifier).create(input);
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
      title: _isEdit ? 'Edit company' : 'New company',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Company name',
            controller: _nameCtrl,
            autofocus: true,
            errorText:
                _error != null && _nameCtrl.text.isEmpty ? _error : null,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Industry',
            controller: _industryCtrl,
          ),
          const SizedBox(height: LinearSpacing.base),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Website',
                  controller: _websiteCtrl,
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: AppTextField(
                  label: 'Phone',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Email',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'MF (matricule fiscal)',
            controller: _taxIdCtrl,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Address',
            controller: _addressCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: LinearSpacing.base),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppSelect<CompanyStatus>(
                  label: 'Status',
                  value: _status,
                  width: double.infinity,
                  options: const [
                    AppSelectOption(value: CompanyStatus.prospect, label: 'Prospect'),
                    AppSelectOption(value: CompanyStatus.active,   label: 'Active'),
                    AppSelectOption(value: CompanyStatus.inactive, label: 'Inactive'),
                  ],
                  onSelected: (v) { if (v != null) setState(() => _status = v); },
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: AppSelect<String>(
                  label: 'Employees',
                  value: _employeeRange,
                  width: double.infinity,
                  options: kEmployeeRanges
                      .map((r) => AppSelectOption(value: r, label: r))
                      .toList(),
                  onSelected: (v) => setState(() => _employeeRange = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Notes',
            controller: _notesCtrl,
            maxLines: 3,
          ),
          CustomFieldsFormSection(
            entityType:    'company',
            initialValues: widget.company?.customFields ?? {},
            onChanged:     (v) => _customFields = v,
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
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          onPressed: _loading ? null : () => Navigator.pop(context, false),
        ),
        AppButton(
          label: _isEdit ? 'Save changes' : 'Create company',
          variant: AppButtonVariant.filled,
          loading: _loading,
          onPressed: _save,
        ),
      ],
    );
  }
}
