import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/company.dart';
import '../../data/models/contact.dart';
import '../../data/providers/companies_provider.dart';
import '../../data/providers/contacts_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/molecules/app_dropdown.dart';
import '../../ui/organisms/app_dialog.dart';
import 'custom_fields_section.dart';

/// Opens the create/edit contact dialog. Returns true if a contact was saved.
Future<bool> showContactForm(BuildContext context, {Contact? contact}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => ContactFormDialog(contact: contact),
      ) ??
      false;
}

class ContactFormDialog extends ConsumerStatefulWidget {
  const ContactFormDialog({super.key, this.contact});
  final Contact? contact;

  @override
  ConsumerState<ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends ConsumerState<ContactFormDialog> {
  bool get _isEdit => widget.contact != null;

  late final _firstNameCtrl = TextEditingController(text: widget.contact?.firstName ?? '');
  late final _lastNameCtrl  = TextEditingController(text: widget.contact?.lastName  ?? '');
  late final _emailCtrl     = TextEditingController(text: widget.contact?.email     ?? '');
  late final _phoneCtrl     = TextEditingController(text: widget.contact?.phone     ?? '');
  late final _titleCtrl     = TextEditingController(text: widget.contact?.title     ?? '');
  late final _notesCtrl     = TextEditingController(text: widget.contact?.notes     ?? '');
  late ContactStatus _status = widget.contact?.status ?? ContactStatus.lead;
  String? _companyId;
  String  _companyName = '';
  late Map<String, dynamic> _customFields =
      Map.from(widget.contact?.customFields ?? {});
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _companyId   = widget.contact?.companyId;
    _companyName = widget.contact?.companyName ?? '';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onCompanySelected(Company? company) {
    setState(() {
      _companyId   = company?.id;
      _companyName = company?.name ?? '';
    });
  }

  String? _trim(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) {
      setState(() => _error = 'First name is required');
      return;
    }

    final orgId = ref.read(currentOrgIdProvider).value;
    if (orgId == null) {
      setState(() => _error = 'No organisation selected');
      return;
    }

    final base  = widget.contact?.toInput();
    final input = ContactInput(
      orgId:        orgId,
      firstName:    firstName,
      lastName:     _trim(_lastNameCtrl),
      email:        _trim(_emailCtrl),
      phone:        _trim(_phoneCtrl),
      title:        _trim(_titleCtrl),
      notes:        _trim(_notesCtrl),
      status:       _status,
      companyId:    _companyId,
      tags:         base?.tags ?? [],
      customFields: _customFields,
    );

    setState(() { _loading = true; _error = null; });
    try {
      if (_isEdit) {
        await ref.read(contactsProvider.notifier).updateContact(widget.contact!.id, input);
      } else {
        await ref.read(contactsProvider.notifier).create(input);
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
      title: _isEdit ? 'Edit contact' : 'New contact',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'First name',
                  controller: _firstNameCtrl,
                  autofocus: true,
                  errorText: _error != null && _firstNameCtrl.text.isEmpty
                      ? _error
                      : null,
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: AppTextField(
                  label: 'Last name',
                  controller: _lastNameCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),
          _CompanyField(
            initialName: _companyName,
            onSelected:  _onCompanySelected,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Email',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Phone',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Job title',
            controller: _titleCtrl,
          ),
          const SizedBox(height: LinearSpacing.base),
          AppSelect<ContactStatus>(
            label: 'Status',
            value: _status,
            width: double.infinity,
            options: const [
              AppSelectOption(value: ContactStatus.lead,     label: 'Lead'),
              AppSelectOption(value: ContactStatus.active,   label: 'Active'),
              AppSelectOption(value: ContactStatus.inactive, label: 'Inactive'),
            ],
            onSelected: (v) { if (v != null) setState(() => _status = v); },
          ),
          const SizedBox(height: LinearSpacing.base),
          AppTextField(
            label: 'Notes',
            controller: _notesCtrl,
            maxLines: 3,
          ),
          CustomFieldsFormSection(
            entityType:    'contact',
            initialValues: widget.contact?.customFields ?? {},
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
          label: _isEdit ? 'Save changes' : 'Create contact',
          variant: AppButtonVariant.filled,
          loading: _loading,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Company autocomplete field ─────────────────────────────────────────────────

class _CompanyField extends ConsumerStatefulWidget {
  const _CompanyField({
    required this.initialName,
    required this.onSelected,
  });

  final String                    initialName;
  final ValueChanged<Company?>    onSelected;

  @override
  ConsumerState<_CompanyField> createState() => _CompanyFieldState();
}

class _CompanyFieldState extends ConsumerState<_CompanyField> {
  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];

    return Autocomplete<Company>(
      initialValue: TextEditingValue(text: widget.initialName),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return companies;
        return companies.where((c) => c.name.toLowerCase().contains(q));
      },
      displayStringForOption: (c) => c.name,
      fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
        final ext = context.linearExt;
        // Keep our local ctrl in sync so the parent can clear it.
        return TextField(
          controller: ctrl,
          focusNode:  focusNode,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ext.textPrimary,
              ),
          onChanged: (v) {
            if (v.isEmpty) widget.onSelected(null);
          },
          decoration: const InputDecoration(labelText: 'Company'),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final ext = context.linearExt;
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            color: ext.surfaceRaised,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LinearRadii.md),
              side: BorderSide(color: ext.borderSubtle),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 380),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final company = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(company),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LinearSpacing.base,
                        vertical:   LinearSpacing.sm,
                      ),
                      child: Text(
                        company.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.linearExt.textPrimary,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: widget.onSelected,
    );
  }
}
