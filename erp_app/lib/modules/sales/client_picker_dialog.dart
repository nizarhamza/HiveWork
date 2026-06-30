import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/company.dart';
import '../../data/models/contact.dart';
import '../../data/providers/companies_provider.dart';
import '../../data/providers/contacts_provider.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_avatar.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';

// ── Result ─────────────────────────────────────────────────────────────────────

class ClientPickerResult {
  const ClientPickerResult({
    this.contactId,
    this.contactName,
    this.companyId,
    this.companyName,
  });

  final String? contactId;
  final String? contactName;
  final String? companyId;
  final String? companyName;
}

// ── Helper ─────────────────────────────────────────────────────────────────────

Future<ClientPickerResult?> showClientPicker(
  BuildContext context, {
  String? initialContactId,
  String? initialCompanyId,
}) {
  return showDialog<ClientPickerResult>(
    context: context,
    builder: (_) => ClientPickerDialog(
      initialContactId: initialContactId,
      initialCompanyId: initialCompanyId,
    ),
  );
}

// ── Dialog ─────────────────────────────────────────────────────────────────────

class ClientPickerDialog extends ConsumerStatefulWidget {
  const ClientPickerDialog({
    super.key,
    this.initialContactId,
    this.initialCompanyId,
  });

  final String? initialContactId;
  final String? initialCompanyId;

  @override
  ConsumerState<ClientPickerDialog> createState() => _ClientPickerDialogState();
}

class _ClientPickerDialogState extends ConsumerState<ClientPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _searchCtrl = TextEditingController();
  String _query = '';

  String? _contactId;
  String? _contactName;
  String? _companyId;
  String? _companyName;

  @override
  void initState() {
    super.initState();
    _contactId = widget.initialContactId;
    _companyId = widget.initialCompanyId;
    // Start on the tab that matches the current selection
    if (_companyId != null && _contactId == null) _tabs.index = 1;
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectContact(Contact c) {
    setState(() {
      _contactId   = c.id;
      _contactName = c.fullName;
      _companyId   = null;
      _companyName = null;
    });
  }

  void _selectCompany(Company c) {
    setState(() {
      _companyId   = c.id;
      _companyName = c.name;
      _contactId   = null;
      _contactName = null;
    });
  }

  void _confirm() {
    Navigator.pop(
      context,
      ClientPickerResult(
        contactId:   _contactId,
        contactName: _contactName,
        companyId:   _companyId,
        companyName: _companyName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  LinearSpacing.lg, LinearSpacing.base,
                  LinearSpacing.sm, LinearSpacing.base),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Select client', style: text.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: ext.textMuted,
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Search
            Padding(
              padding: const EdgeInsets.all(LinearSpacing.base),
              child: AppSearchField(
                hint: 'Search contacts and companies…',
                controller: _searchCtrl,
                autofocus: true,
              ),
            ),

            // ── Tabs
            TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Contacts'), Tab(text: 'Companies')],
              labelStyle: text.labelMedium,
            ),

            // ── Tab views
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ContactList(
                    query:             _query,
                    selectedContactId: _contactId,
                    onSelect:          _selectContact,
                  ),
                  _CompanyList(
                    query:             _query,
                    selectedCompanyId: _companyId,
                    onSelect:          _selectCompany,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Actions
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.lg, vertical: LinearSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_contactId != null || _companyId != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _contactId = _contactName = _companyId = _companyName = null;
                      }),
                      icon: const Icon(Icons.close, size: 13),
                      label: const Text('Clear'),
                    )
                  else
                    const SizedBox(),
                  Row(
                    children: [
                      AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: LinearSpacing.sm),
                      AppButton(
                        label: 'Confirm',
                        variant: AppButtonVariant.filled,
                        onPressed: _confirm,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contacts tab ───────────────────────────────────────────────────────────────

class _ContactList extends ConsumerWidget {
  const _ContactList({
    required this.query,
    required this.selectedContactId,
    required this.onSelect,
  });

  final String   query;
  final String?  selectedContactId;
  final ValueChanged<Contact> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contactsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data:    (contacts) {
        final filtered = query.isEmpty
            ? contacts
            : contacts.where((c) =>
                c.fullName.toLowerCase().contains(query) ||
                (c.email?.toLowerCase().contains(query) ?? false) ||
                (c.companyName?.toLowerCase().contains(query) ?? false)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text('No contacts found',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.linearExt.textMuted)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ContactTile(
            contact:    filtered[i],
            isSelected: filtered[i].id == selectedContactId,
            onTap:      () => onSelect(filtered[i]),
          ),
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  final Contact contact;
  final bool    isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
        color: isSelected ? ext.overlayActive : null,
        child: Row(
          children: [
            AppAvatar(
              name:  contact.fullName,
              color: contact.avatarColor,
              size:  AppAvatarSize.sm,
            ),
            const SizedBox(width: LinearSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.fullName,
                      style: text.bodySmall?.copyWith(color: ext.textPrimary)),
                  if (contact.companyName != null)
                    Text(contact.companyName!,
                        style: text.labelSmall?.copyWith(color: ext.textMuted)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 14, color: LinearColors.accent),
          ],
        ),
      ),
    );
  }
}

// ── Companies tab ──────────────────────────────────────────────────────────────

class _CompanyList extends ConsumerWidget {
  const _CompanyList({
    required this.query,
    required this.selectedCompanyId,
    required this.onSelect,
  });

  final String   query;
  final String?  selectedCompanyId;
  final ValueChanged<Company> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companiesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data:    (companies) {
        final filtered = query.isEmpty
            ? companies
            : companies.where((c) =>
                c.name.toLowerCase().contains(query) ||
                (c.industry?.toLowerCase().contains(query) ?? false)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text('No companies found',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.linearExt.textMuted)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _CompanyTile(
            company:    filtered[i],
            isSelected: filtered[i].id == selectedCompanyId,
            onTap:      () => onSelect(filtered[i]),
          ),
        );
      },
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({
    required this.company,
    required this.isSelected,
    required this.onTap,
  });

  final Company  company;
  final bool     isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
        color: isSelected ? ext.overlayActive : null,
        child: Row(
          children: [
            AppAvatar(
              name:  company.name,
              color: company.avatarColor,
              size:  AppAvatarSize.sm,
            ),
            const SizedBox(width: LinearSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name,
                      style: text.bodySmall?.copyWith(color: ext.textPrimary)),
                  if (company.industry != null)
                    Text(company.industry!,
                        style: text.labelSmall?.copyWith(color: ext.textMuted)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 14, color: LinearColors.accent),
          ],
        ),
      ),
    );
  }
}
