import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/contact.dart';
import '../../data/providers/contacts_provider.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/organisms/app_dialog.dart';
import 'company_picker_dialog.dart';
import 'contact_form_dialog.dart';
import 'custom_fields_section.dart';

const double _kPropsWidth    = 256.0;
const double _kPropsWidthMin = 180.0;
const double _kPropsWidthMax = 480.0;
const double _kSplitBreak    = 560.0;

// ── Public entry-point ─────────────────────────────────────────────────────────

class ContactDetailPane extends ConsumerStatefulWidget {
  const ContactDetailPane({
    super.key,
    required this.contact,
    this.onClose,
  });

  final Contact contact;
  final VoidCallback? onClose;

  @override
  ConsumerState<ContactDetailPane> createState() => _ContactDetailPaneState();
}

class _ContactDetailPaneState extends ConsumerState<ContactDetailPane> {
  double _propsWidth = _kPropsWidth;

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final onClose = widget.onClose;

    Future<void> update(ContactInput input) =>
        ref.read(contactsProvider.notifier).updateContact(contact.id, input);

    Future<void> delete() async {
      final confirmed = await AppDialog.confirm(
        context,
        title: 'Delete ${contact.fullName}?',
        message: 'This action cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed) {
        await ref.read(contactsProvider.notifier).delete(contact.id);
        onClose?.call();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(contact: contact, onClose: onClose, onDelete: delete),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth >= _kSplitBreak) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _RecordBody(contact: contact, onUpdate: update)),
                    ResizablePaneDivider(
                      onDrag: (delta) => setState(() {
                        // Divider is left of the props panel: drag right shrinks it.
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
                        child: _PropertiesPanel(contact: contact, onUpdate: update),
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
                    _PropertiesPanel(contact: contact, onUpdate: update),
                    const SizedBox(height: LinearSpacing.xl),
                    _NotesSection(contact: contact, onUpdate: update),
                    const SizedBox(height: LinearSpacing.xl),
                    _ActivitySection(contact: contact),
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
    required this.contact,
    required this.onDelete,
    this.onClose,
  });

  final Contact contact;
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
          _ContactAvatar(contact: contact, size: 32),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.fullName,
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_subtitle != null)
                  Text(
                    _subtitle!,
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
            onPressed: () => showContactForm(context, contact: contact),
          ),
          const SizedBox(width: LinearSpacing.sm),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete contact',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String? get _subtitle {
    final parts = [contact.title, contact.companyName].whereType<String>();
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

// ── Record body (left/main column) ─────────────────────────────────────────────

class _RecordBody extends StatelessWidget {
  const _RecordBody({required this.contact, required this.onUpdate});

  final Contact contact;
  final Future<void> Function(ContactInput) onUpdate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotesSection(contact: contact, onUpdate: onUpdate),
          const SizedBox(height: LinearSpacing.xl),
          _ActivitySection(contact: contact),
        ],
      ),
    );
  }
}

// ── Notes ──────────────────────────────────────────────────────────────────────

class _NotesSection extends StatefulWidget {
  const _NotesSection({required this.contact, required this.onUpdate});

  final Contact contact;
  final Future<void> Function(ContactInput) onUpdate;

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  late final _ctrl = TextEditingController(text: widget.contact.notes ?? '');
  bool _editing = false;
  bool _saving  = false;

  @override
  void didUpdateWidget(_NotesSection old) {
    super.didUpdateWidget(old);
    if (!_editing && old.contact.notes != widget.contact.notes) {
      _ctrl.text = widget.contact.notes ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notes = _ctrl.text.trim();
    await widget.onUpdate(
      widget.contact.toInput().copyWith(notes: notes.isEmpty ? null : notes),
    );
    if (mounted) setState(() { _editing = false; _saving = false; });
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
                style: text.bodyMedium?.copyWith(color: ext.textPrimary),
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
                      ? Text(
                          'Click to add notes…',
                          style: text.bodyMedium,
                        )
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

// ── Activity feed ──────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final entries = <_ActivityEntry>[
      _ActivityEntry(
        icon: Icons.person_add_alt_outlined,
        text: 'Contact created',
        time: _fmtDate(contact.createdAt),
      ),
      if (contact.notes?.isNotEmpty == true &&
          contact.updatedAt != contact.createdAt)
        _ActivityEntry(
          icon: Icons.edit_note_outlined,
          text: 'Notes updated',
          time: _fmtDate(contact.updatedAt),
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
            width: 28, height: 28,
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
              style: text.bodySmall?.copyWith(
                color: ext.textSecondary,
              ),
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: ext.textPrimary,
          ),
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

// ── Properties panel (right sidebar) ──────────────────────────────────────────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.contact, required this.onUpdate});

  final Contact  contact;
  final Future<void> Function(ContactInput) onUpdate;

  Future<void> _updateCustomFields(Map<String, dynamic> fields) =>
      onUpdate(contact.toInput().copyWith(customFields: fields));

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
              status: contact.status,
              onChanged: (s) =>
                  onUpdate(contact.toInput().copyWith(status: s)),
            ),
          ),
          _PropRow(
            label: 'Company',
            child: _CompanyPickerRow(contact: contact, onUpdate: onUpdate),
          ),
          _PropRow(
            label: 'Email',
            child: AppInlineEditable(
              value: contact.email ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                contact.toInput().copyWith(email: v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ),
          _PropRow(
            label: 'Phone',
            child: AppInlineEditable(
              value: contact.phone ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                contact.toInput().copyWith(phone: v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ),
          _PropRow(
            label: 'Title',
            child: AppInlineEditable(
              value: contact.title ?? '',
              placeholder: '—',
              style: Theme.of(context).textTheme.bodySmall,
              onSubmit: (v) => onUpdate(
                contact.toInput().copyWith(title: v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ),
          _PropRow(
            label: 'Tags',
            child: _TagsEditor(
              tags: contact.tags,
              onUpdate: (tags) =>
                  onUpdate(contact.toInput().copyWith(tags: tags)),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          CustomFieldsSection(
            entityType:   'contact',
            entityId:     contact.id,
            customFields: contact.customFields,
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
              _fmtDate(contact.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _PropRow(
            label: 'By',
            child: Text(
              contact.createdByName ?? '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: contact.createdByName != null
                        ? ext.textPrimary
                        : ext.textMuted,
                  ),
            ),
          ),
          _PropRow(
            label: 'Updated',
            child: Text(
              _fmtDate(contact.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _PropRow(
            label: 'By',
            child: Text(
              contact.updatedByName ?? '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: contact.updatedByName != null
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

  final ContactStatus status;
  final ValueChanged<ContactStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ContactStatus>(
      tooltip: 'Change status',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 140),
      itemBuilder: (_) => ContactStatus.values
          .map(
            (s) => PopupMenuItem<ContactStatus>(
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
  final ContactStatus status;

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
            width: 6, height: 6,
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

// ── Company picker row ─────────────────────────────────────────────────────────

class _CompanyPickerRow extends StatelessWidget {
  const _CompanyPickerRow({required this.contact, required this.onUpdate});
  final Contact contact;
  final Future<void> Function(ContactInput) onUpdate;

  Future<void> _pick(BuildContext context) async {
    final result = await showCompanyPicker(
      context,
      currentCompanyId: contact.companyId,
    );
    if (result.cleared) {
      await onUpdate(contact.toInput().copyWith(companyId: null));
    } else if (result.company != null) {
      await onUpdate(
          contact.toInput().copyWith(companyId: result.company!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _pick(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                contact.companyName ?? 'Link company…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: contact.companyName != null
                          ? ext.textPrimary
                          : ext.textMuted,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 12, color: ext.textMuted),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    Text(
                      'Add',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: ext.textMuted),
                    ),
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
      padding: const EdgeInsetsDirectional.only(start: 6, end: 2, top: 2, bottom: 2),
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

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact, this.size = 32});
  final Contact contact;
  final double  size;

  @override
  Widget build(BuildContext context) {
    if (contact.avatarUrl != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(contact.avatarUrl!),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: contact.avatarColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        contact.initials,
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
