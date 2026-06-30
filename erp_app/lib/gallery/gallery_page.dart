import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/widgets/linear_view_header.dart';
import '../theme/linear_tokens.dart';
import '../ui/atoms/app_avatar.dart';
import '../ui/atoms/app_badge.dart';
import '../ui/atoms/app_button.dart';
import '../ui/atoms/app_controls.dart';
import '../ui/atoms/app_pill.dart';
import '../ui/atoms/app_tag.dart';
import '../ui/atoms/app_text_field.dart';
import '../ui/molecules/app_dropdown.dart';
import '../ui/molecules/app_empty_state.dart';
import '../ui/molecules/app_form_row.dart';
import '../ui/molecules/app_skeleton.dart';
import '../ui/organisms/app_dialog.dart';
import '../ui/organisms/app_side_panel.dart';
import '../ui/organisms/app_toast.dart';

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  bool _cbValue  = true;
  bool _swValue  = false;
  String? _radioValue = 'a';
  Set<String> _segmented = {'list'};
  String _dropValue = 'active';
  bool _showPanel = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearViewHeader(
                icon: Icons.grid_view_outlined,
                title: 'Component gallery',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(LinearSpacing.xl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('Buttons', _buttons(context)),
                          _section('Status & priority pills', _pills()),
                          _section('Tags', _tags()),
                          _section('Avatars & badges', _avatars()),
                          _section('Text fields', _textFields()),
                          _section('Controls', _controls()),
                          _section('Dropdown / select', _dropdown()),
                          _section('Form layout', _formLayout()),
                          _section('Skeleton loaders', _skeletons()),
                          _section('Empty state', _emptyState()),
                          _section('Overlays', _overlays(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showPanel)
          AppSidePanel(
            title: 'Properties',
            onClose: () => setState(() => _showPanel = false),
            children: [
              SidePanelSection(
                title: 'Details',
                children: [
                  SidePanelProperty(
                    label: 'Status',
                    child: const AppStatusPill(variant: AppStatusVariant.active),
                  ),
                  SidePanelProperty(
                    label: 'Priority',
                    child: const AppPriorityPill(level: AppPriorityLevel.high),
                  ),
                  SidePanelProperty(
                    label: 'Owner',
                    child: Row(children: const [
                      AppAvatar(name: 'Nizar T', size: AppAvatarSize.sm),
                      SizedBox(width: LinearSpacing.sm),
                      Text('Nizar Thabouti',
                        style: TextStyle(fontSize: 12, color: LinearColors.textSecondary)),
                    ]),
                  ),
                ],
              ),
              SidePanelSection(
                title: 'Activity',
                children: [
                  Text('Created 2 hours ago',
                    style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: LinearSpacing.xs),
                  Text('Last updated just now',
                    style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
      ],
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _section(String title, Widget content) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: LinearColors.textMuted, letterSpacing: 0.5,
      )),
      const SizedBox(height: LinearSpacing.base),
      content,
      const SizedBox(height: LinearSpacing.xl),
      const Divider(),
      const SizedBox(height: LinearSpacing.xl),
    ],
  );

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buttons(BuildContext ctx) => Wrap(
    spacing: LinearSpacing.sm,
    runSpacing: LinearSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const AppButton(label: 'Filled', variant: AppButtonVariant.filled),
      const AppButton(label: 'Outlined'),
      const AppButton(label: 'Ghost', variant: AppButtonVariant.ghost),
      const AppButton(label: 'Danger', variant: AppButtonVariant.danger),
      const AppButton(label: 'With icon', icon: Icons.add),
      const AppButton(label: 'Loading', loading: true),
      const AppButton(label: 'Disabled'),
      AppButton(
        label: 'Small',
        size: AppButtonSize.sm,
        variant: AppButtonVariant.filled,
        onPressed: () {},
      ),
      AppButton(
        label: 'Large',
        size: AppButtonSize.lg,
        variant: AppButtonVariant.filled,
        onPressed: () {},
      ),
      const AppIconButton(icon: Icons.add, tooltip: 'Add'),
      const AppIconButton(icon: Icons.filter_list, tooltip: 'Filter', selected: true),
    ],
  );

  Widget _pills() => Wrap(
    spacing: LinearSpacing.sm,
    runSpacing: LinearSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final v in AppStatusVariant.values) AppStatusPill(variant: v),
      const Divider(),
      for (final l in AppPriorityLevel.values) AppPriorityPill(level: l),
    ],
  );

  Widget _tags() => Wrap(
    spacing: LinearSpacing.sm,
    runSpacing: LinearSpacing.sm,
    children: [
      const AppTag(label: 'Flutter'),
      const AppTag(label: 'Supabase', color: LinearColors.success),
      const AppTag(label: 'Riverpod', color: LinearColors.warning),
      AppTag(label: 'Removable', onRemove: () {}),
    ],
  );

  Widget _avatars() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: LinearSpacing.base,
        runSpacing: LinearSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final s in AppAvatarSize.values)
            AppAvatar(name: 'Nizar Thabouti', size: s),
        ],
      ),
      const SizedBox(height: LinearSpacing.base),
      const AppAvatarStack(
        names: ['Nizar T', 'Sofia R', 'Omar K', 'Amira B'],
        colors: [LinearColors.accent, LinearColors.success, LinearColors.warning, LinearColors.danger],
        maxVisible: 3,
      ),
      const SizedBox(height: LinearSpacing.base),
      Row(children: const [
        AppBadge(count: 5, child: Icon(Icons.inbox_outlined, color: LinearColors.textMuted, size: 20)),
        SizedBox(width: LinearSpacing.xl),
        AppBadge(dot: true, child: Icon(Icons.notifications_outlined, color: LinearColors.textMuted, size: 20)),
        SizedBox(width: LinearSpacing.xl),
        AppCountBadge(count: 12),
      ]),
    ],
  );

  Widget _textFields() => Column(
    children: [
      const AppTextField(label: 'Name', hint: 'Enter your name'),
      const SizedBox(height: LinearSpacing.base),
      const AppTextField(label: 'Email', errorText: 'Invalid email'),
      const SizedBox(height: LinearSpacing.base),
      const AppTextField(label: 'Notes', maxLines: 3),
      const SizedBox(height: LinearSpacing.base),
      const AppSearchField(hint: 'Search contacts…'),
      const SizedBox(height: LinearSpacing.base),
      AppInlineEditable(
        value: 'Click to edit this text',
        onSubmit: (_) {},
      ),
    ],
  );

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppCheckbox(
        value: _cbValue,
        onChanged: (v) => setState(() => _cbValue = v ?? false),
        label: 'I agree to the terms',
      ),
      const SizedBox(height: LinearSpacing.sm),
      for (final opt in [('a', 'Option A'), ('b', 'Option B'), ('c', 'Option C')])
        AppRadio<String>(
          value: opt.$1,
          groupValue: _radioValue,
          onChanged: (v) => setState(() => _radioValue = v),
          label: opt.$2,
        ),
      const SizedBox(height: LinearSpacing.sm),
      AppSwitch(
        value: _swValue,
        onChanged: (v) => setState(() => _swValue = v),
        label: 'Enable notifications',
      ),
      const SizedBox(height: LinearSpacing.base),
      AppSegmentedControl<String>(
        selected: _segmented,
        onSelectionChanged: (s) => setState(() => _segmented = s),
        segments: const [
          ButtonSegment(value: 'list',  label: Text('List'),  icon: Icon(Icons.list, size: 14)),
          ButtonSegment(value: 'board', label: Text('Board'), icon: Icon(Icons.view_kanban_outlined, size: 14)),
          ButtonSegment(value: 'table', label: Text('Table'), icon: Icon(Icons.table_chart_outlined, size: 14)),
        ],
      ),
    ],
  );

  Widget _dropdown() => AppSelect<String>(
    value: _dropValue,
    label: 'Status',
    width: 200,
    options: const [
      AppSelectOption(value: 'active',   label: 'Active'),
      AppSelectOption(value: 'lead',     label: 'Lead'),
      AppSelectOption(value: 'inactive', label: 'Inactive'),
    ],
    onSelected: (v) => setState(() => _dropValue = v ?? _dropValue),
  );

  Widget _formLayout() => Column(
    children: [
      AppFormRow(
        label: 'Company name',
        required: true,
        helper: 'Used on invoices and contracts',
        child: const AppTextField(hint: 'Enernetpro'),
      ),
      const SizedBox(height: LinearSpacing.base),
      AppFormRow(
        label: 'Website',
        child: const AppTextField(hint: 'https://'),
      ),
      const SizedBox(height: LinearSpacing.base),
      AppFormRow(
        label: 'Status',
        child: AppSelect<String>(
          value: 'active',
          width: double.infinity,
          options: const [
            AppSelectOption(value: 'active',   label: 'Active'),
            AppSelectOption(value: 'inactive', label: 'Inactive'),
          ],
          onSelected: (_) {},
        ),
      ),
    ],
  );

  Widget _skeletons() => Column(
    children: [
      Row(children: const [
        AppSkeleton(width: 28, height: 28, borderRadius: LinearRadii.pill),
        SizedBox(width: LinearSpacing.base),
        Expanded(child: AppSkeleton(width: double.infinity, height: 13)),
      ]),
      const SizedBox(height: LinearSpacing.sm),
      const AppSkeleton(width: double.infinity, height: 13),
      const SizedBox(height: LinearSpacing.xs),
      AppSkeleton.line(width: 200),
      const SizedBox(height: LinearSpacing.base),
      const AppContactRowSkeleton(),
      const AppContactRowSkeleton(),
      const AppContactRowSkeleton(),
    ],
  );

  Widget _emptyState() => SizedBox(
    height: 220,
    child: AppEmptyState(
      icon: Icons.people_outline,
      title: 'No contacts yet',
      description: 'Add your first contact to start building your CRM.',
      actionLabel: 'Add contact',
      onAction: () => ref.read(toastProvider.notifier).show(
        'Connect Supabase first',
        variant: ToastVariant.info,
      ),
    ),
  );

  Widget _overlays(BuildContext ctx) => Wrap(
    spacing: LinearSpacing.sm,
    runSpacing: LinearSpacing.sm,
    children: [
      AppButton(
        label: 'Dialog',
        onPressed: () => AppDialog.show(
          ctx,
          title: 'Edit contact',
          content: Column(children: const [
            AppTextField(label: 'Name', hint: 'Full name'),
            SizedBox(height: LinearSpacing.base),
            AppTextField(label: 'Email', hint: 'you@example.com'),
          ]),
          actions: [
            AppButton(
              label: 'Cancel', variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx),
            ),
            AppButton(
              label: 'Save', variant: AppButtonVariant.filled,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
      AppButton(
        label: 'Confirm (destructive)',
        variant: AppButtonVariant.danger,
        onPressed: () async {
          final ok = await AppDialog.confirm(
            ctx,
            title: 'Delete contact?',
            message: 'This action cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (ok && ctx.mounted) {
            ref.read(toastProvider.notifier).show(
              'Contact deleted',
              variant: ToastVariant.error,
            );
          }
        },
      ),
      AppButton(
        label: 'Side panel',
        onPressed: () => setState(() => _showPanel = !_showPanel),
      ),
      AppButton(
        label: 'Toast info',
        onPressed: () => ref.read(toastProvider.notifier).show('Saved successfully'),
      ),
      AppButton(
        label: 'Toast success',
        onPressed: () => ref.read(toastProvider.notifier).show(
          'Contact created', variant: ToastVariant.success,
        ),
      ),
      AppButton(
        label: 'Toast warning',
        onPressed: () => ref.read(toastProvider.notifier).show(
          'Unsaved changes', variant: ToastVariant.warning,
        ),
      ),
      AppButton(
        label: 'Toast error',
        onPressed: () => ref.read(toastProvider.notifier).show(
          'Failed to save', variant: ToastVariant.error,
        ),
      ),
    ],
  );
}
