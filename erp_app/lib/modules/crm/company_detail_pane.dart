import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/company.dart';
import '../../data/models/contact.dart';
import '../../data/providers/companies_provider.dart';
import '../../data/providers/contacts_provider.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/organisms/app_dialog.dart';
import 'company_form_dialog.dart';
import 'custom_fields_section.dart';

const double _kPropsWidth    = 256.0;
const double _kPropsWidthMin = 180.0;
const double _kPropsWidthMax = 480.0;
const double _kSplitBreak    = 560.0;

// ── Public entry-point ─────────────────────────────────────────────────────────

class CompanyDetailPane extends ConsumerStatefulWidget {
  const CompanyDetailPane({
    super.key,
    required this.company,
    this.onClose,
  });

  final Company company;
  final VoidCallback? onClose;

  @override
  ConsumerState<CompanyDetailPane> createState() => _CompanyDetailPaneState();
}

class _CompanyDetailPaneState extends ConsumerState<CompanyDetailPane> {
  double _propsWidth = _kPropsWidth;

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final onClose = widget.onClose;

    Future<void> update(CompanyInput input) =>
        ref.read(companiesProvider.notifier).updateCompany(company.id, input);

    Future<void> delete() async {
      final confirmed = await AppDialog.confirm(
        context,
        title: 'Delete ${company.name}?',
        message: 'This action cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed) {
        await ref.read(companiesProvider.notifier).delete(company.id);
        onClose?.call();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(company: company, onClose: onClose, onDelete: delete),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth >= _kSplitBreak) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _RecordBody(company: company, onUpdate: update),
                    ),
                    ResizablePaneDivider(
                      onDrag: (delta) => setState(() {
                        _propsWidth = (_propsWidth - delta)
                            .clamp(_kPropsWidthMin, _kPropsWidthMax);
                      }),
                    ),
                    SizedBox(
                      width: _propsWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: context.linearExt.borderSubtle),
                          ),
                        ),
                        child: _PropertiesPanel(
                          company: company,
                          onUpdate: update,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(LinearSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PropertiesPanel(company: company, onUpdate: update),
                    const SizedBox(height: LinearSpacing.xl),
                    _NotesSection(company: company, onUpdate: update),
                    const SizedBox(height: LinearSpacing.xl),
                    _ActivitySection(company: company),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.company,
    required this.onDelete,
    this.onClose,
  });

  final Company company;
  final VoidCallback? onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      child: Row(
        children: [
          if (onClose != null) ...[
            AppIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Back to list',
              iconSize: 18,
              onPressed: onClose,
            ),
            const SizedBox(width: LinearSpacing.xs),
          ],
          _CompanyLogo(company: company, size: 32),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (company.industry != null)
                  Text(
                    company.industry!,
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          AppButton(
            label: 'Edit',
            variant: AppButtonVariant.outlined,
            size: AppButtonSize.sm,
            icon: Icons.edit_outlined,
            onPressed: () => showCompanyForm(context, company: company),
          ),
          const SizedBox(width: LinearSpacing.sm),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete company',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Record body ────────────────────────────────────────────────────────────────

class _RecordBody extends ConsumerWidget {
  const _RecordBody({required this.company, required this.onUpdate});

  final Company company;
  final Future<void> Function(CompanyInput) onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedContacts = ref
            .watch(contactsProvider)
            .value
            ?.where((c) => c.companyId == company.id)
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotesSection(company: company, onUpdate: onUpdate),
          const SizedBox(height: LinearSpacing.xl),
          if (linkedContacts.isNotEmpty) ...[
            _PeopleSection(contacts: linkedContacts),
            const SizedBox(height: LinearSpacing.xl),
          ],
          _ActivitySection(company: company),
        ],
      ),
    );
  }
}

// ── People section ─────────────────────────────────────────────────────────────

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({required this.contacts});
  final List<Contact> contacts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('People (${contacts.length})'),
        const SizedBox(height: LinearSpacing.sm),
        for (final c in contacts)
          Padding(
            padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                onTap: () => context.go('/crm/contacts?contact=${c.id}'),
                overlayColor:
                    const WidgetStatePropertyAll(LinearColors.overlay),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.xs,
                    vertical: LinearSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _ContactMiniAvatar(contact: c),
                      const SizedBox(width: LinearSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.fullName,
                              style: text.bodySmall?.copyWith(
                                color: context.linearExt.textPrimary,
                              ),
                            ),
                            if (c.title != null)
                              Text(
                                c.title!,
                                style: text.labelSmall
                                    ?.copyWith(color: context.linearExt.textMuted),
                              ),
                          ],
                        ),
                      ),
                      if (c.email != null)
                        Flexible(
                          child: Text(
                            c.email!,
                            style: text.labelSmall
                                ?.copyWith(color: context.linearExt.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(width: LinearSpacing.xs),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: context.linearExt.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContactMiniAvatar extends StatelessWidget {
  const _ContactMiniAvatar({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: contact.avatarColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        contact.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Notes ──────────────────────────────────────────────────────────────────────

class _NotesSection extends StatefulWidget {
  const _NotesSection({required this.company, required this.onUpdate});

  final Company company;
  final Future<void> Function(CompanyInput) onUpdate;

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  late final _ctrl = TextEditingController(text: widget.company.notes ?? '');
  bool _editing = false;
  bool _saving  = false;

  @override
  void didUpdateWidget(_NotesSection old) {
    super.didUpdateWidget(old);
    if (!_editing && old.company.notes != widget.company.notes) {
      _ctrl.text = widget.company.notes ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notes = _ctrl.text.trim();
      await widget.onUpdate(
        widget.company.toInput().copyWith(notes: notes.isEmpty ? null : notes),
      );
      if (mounted) setState(() { _editing = false; _saving = false; });
    } catch (e) {
      // F-2: show the error instead of letting it propagate to the framework.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Notes'),
        const SizedBox(height: LinearSpacing.sm),
        if (_editing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _ctrl,
                maxLines: null,
                minLines: 3,
                autofocus: true,
                style: text.bodyMedium
                    ?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add notes…',
                  contentPadding: const EdgeInsets.all(LinearSpacing.base),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    borderSide: BorderSide(color: ext.borderBase),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    borderSide: const BorderSide(
                        color: LinearColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: LinearSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editing = false),
                  ),
                  const SizedBox(width: LinearSpacing.sm),
                  AppButton(
                    label: 'Save',
                    variant: AppButtonVariant.filled,
                    size: AppButtonSize.sm,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          )
        else
          Semantics(
            label: 'Notes — tap to edit',
            child: GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(LinearSpacing.base),
                  decoration: BoxDecoration(
                    color: ext.surfaceBase,
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    border: Border.all(color: ext.borderSubtle),
                  ),
                  child: _ctrl.text.isEmpty
                      ? Text('Click to add notes…', style: text.bodyMedium)
                      : Text(
                          _ctrl.text,
                          style: text.bodyMedium
                              ?.copyWith(color: ext.textPrimary),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Activity ───────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context) {
    final entries = [
      _ActivityEntry(
        icon: Icons.business_outlined,
        text: 'Company created',
        time: _fmtDate(company.createdAt),
      ),
      if (company.notes?.isNotEmpty == true &&
          company.updatedAt != company.createdAt)
        _ActivityEntry(
          icon: Icons.edit_note_outlined,
          text: 'Notes updated',
          time: _fmtDate(company.updatedAt),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Activity'),
        const SizedBox(height: LinearSpacing.sm),
        ...entries.map(_ActivityRow.new),
        const SizedBox(height: LinearSpacing.sm),
        const _CommentInput(),
      ],
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry({
    required this.icon,
    required this.text,
    required this.time,
  });
  final IconData icon;
  final String   text;
  final String   time;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.entry);
  final _ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ext.surfaceBase,
              shape: BoxShape.circle,
              border: Border.all(color: ext.borderSubtle),
            ),
            child: Icon(entry.icon, size: 13, color: ext.textMuted),
          ),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Text(
              entry.text,
              style: text.bodySmall
                  ?.copyWith(color: ext.textSecondary),
            ),
          ),
          Text(entry.time, style: text.labelSmall),
        ],
      ),
    );
  }
}

class _CommentInput extends StatefulWidget {
  const _CommentInput();

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return TextField(
      controller: _ctrl,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: ext.textPrimary),
      maxLines: null,
      onSubmitted: (_) => _ctrl.clear(),
      decoration: const InputDecoration(
        hintText: 'Add a comment…',
        contentPadding: EdgeInsets.symmetric(
          horizontal: LinearSpacing.base,
          vertical: LinearSpacing.sm,
        ),
      ),
    );
  }
}

// ── Properties panel ───────────────────────────────────────────────────────────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.company, required this.onUpdate});

  final Company company;
  final Future<void> Function(CompanyInput) onUpdate;

  Future<void> _updateCustomFields(Map<String, dynamic> fields) =>
      onUpdate(company.toInput().copyWith(customFields: fields));

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Properties'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Status',
            child: _StatusSelector(
              status: company.status,
              onChanged: (s) =>
                  onUpdate(company.toInput().copyWith(status: s)),
            ),
          ),
          _PropRow(
            label: 'Industry',
            child: AppInlineEditable(
              value: company.industry ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                company.toInput().copyWith(
                      industry: v.trim().isEmpty ? null : v.trim(),
                    ),
              ),
            ),
          ),
          _PropRow(
            label: 'Website',
            child: AppInlineEditable(
              value: company.website ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                company.toInput().copyWith(
                      website: v.trim().isEmpty ? null : v.trim(),
                    ),
              ),
            ),
          ),
          _PropRow(
            label: 'Phone',
            child: AppInlineEditable(
              value: company.phone ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                company.toInput().copyWith(
                      phone: v.trim().isEmpty ? null : v.trim(),
                    ),
              ),
            ),
          ),
          _PropRow(
            label: 'Email',
            child: AppInlineEditable(
              value: company.email ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                company.toInput().copyWith(
                      email: v.trim().isEmpty ? null : v.trim(),
                    ),
              ),
            ),
          ),
          if (company.employeeRange != null)
            _PropRow(
              label: 'Size',
              child: Text(
                company.employeeRange!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ext.textPrimary),
              ),
            ),
          _PropRow(
            label: 'Tags',
            child: _TagsEditor(
              tags: company.tags,
              onUpdate: (tags) =>
                  onUpdate(company.toInput().copyWith(tags: tags)),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          CustomFieldsSection(
            entityType:   'company',
            entityId:     company.id,
            customFields: company.customFields,
            onUpdate:     _updateCustomFields,
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Dates'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Created',
            child: Text(
              _fmtDate(company.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _PropRow(
            label: 'By',
            child: Text(
              company.createdByName ?? '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: company.createdByName != null
                        ? ext.textPrimary
                        : ext.textMuted,
                  ),
            ),
          ),
          _PropRow(
            label: 'Updated',
            child: Text(
              _fmtDate(company.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _PropRow(
            label: 'By',
            child: Text(
              company.updatedByName ?? '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: company.updatedByName != null
                        ? ext.textPrimary
                        : ext.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status selector ────────────────────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.status, required this.onChanged});

  final CompanyStatus status;
  final ValueChanged<CompanyStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CompanyStatus>(
      tooltip: 'Change status',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 140),
      itemBuilder: (_) => CompanyStatus.values
          .map(
            (s) => PopupMenuItem<CompanyStatus>(
              value: s,
              height: 32,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: LinearSpacing.sm),
                  Text(
                    s.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.linearExt.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onSelected: onChanged,
      child: _StatusPill(status: status),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final CompanyStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color),
          ),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 11, color: color),
        ],
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ext.textMuted,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _PropRow extends StatelessWidget {
  const _PropRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ext.textMuted,
                    ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Inline tag editor ──────────────────────────────────────────────────────────

class _TagsEditor extends StatefulWidget {
  const _TagsEditor({required this.tags, required this.onUpdate});
  final List<String> tags;
  final Future<void> Function(List<String>) onUpdate;

  @override
  State<_TagsEditor> createState() => _TagsEditorState();
}

class _TagsEditorState extends State<_TagsEditor> {
  bool _adding = false;
  final _ctrl  = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _commitAdd() async {
    final tag = _ctrl.text.trim();
    setState(() => _adding = false);
    _ctrl.clear();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    await widget.onUpdate([...widget.tags, tag]);
  }

  Future<void> _remove(String tag) =>
      widget.onUpdate(widget.tags.where((t) => t != tag).toList());

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Wrap(
      spacing: LinearSpacing.xs,
      runSpacing: LinearSpacing.xs,
      children: [
        for (final tag in widget.tags)
          _EditableTagChip(label: tag, onRemove: () => _remove(tag)),
        if (_adding)
          SizedBox(
            width: 80,
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ext.textPrimary,
                  ),
              decoration: InputDecoration(
                hintText: 'Tag…',
                hintStyle: TextStyle(color: ext.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm, vertical: 3),
              ),
              onSubmitted: (_) => _commitAdd(),
              onEditingComplete: _commitAdd,
            ),
          ),
        if (!_adding)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _adding = true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ext.overlay,
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  border: Border.all(color: ext.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 10, color: ext.textMuted),
                    const SizedBox(width: 2),
                    Text('Add',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: ext.textMuted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditableTagChip extends StatelessWidget {
  const _EditableTagChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      padding: const EdgeInsetsDirectional.only(
          start: 6, end: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: ext.surfaceRaised,
        borderRadius: BorderRadius.circular(LinearRadii.sm),
        border: Border.all(color: ext.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 2),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 10, color: ext.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.company, this.size = 32});
  final Company company;
  final double  size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: company.avatarColor,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        company.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
