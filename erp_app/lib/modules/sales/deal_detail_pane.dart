import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/deal.dart';
import '../../data/providers/deals_provider.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/organisms/app_dialog.dart';
import 'deal_form_dialog.dart';

/// Opens the deal record as a centred wide dialog (same pattern as the quote form).
Future<void> showDealDetail(BuildContext context, String dealId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DealDetailDialog(dealId: dealId),
  );
}

class _DealDetailDialog extends ConsumerWidget {
  const _DealDetailDialog({required this.dealId});
  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealsProvider).value ?? [];
    final deal  = deals.where((d) => d.id == dealId).firstOrNull;

    if (deal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 860, maxHeight: maxH),
        child: DealDetailPane(
          deal: deal,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

const double _kPropsWidth    = 256.0;
const double _kPropsWidthMin = 180.0;
const double _kPropsWidthMax = 440.0;
const double _kSplitBreak    = 560.0;

class DealDetailPane extends ConsumerStatefulWidget {
  const DealDetailPane({
    super.key,
    required this.deal,
    this.onClose,
  });

  final Deal deal;
  final VoidCallback? onClose;

  @override
  ConsumerState<DealDetailPane> createState() => _DealDetailPaneState();
}

class _DealDetailPaneState extends ConsumerState<DealDetailPane> {
  double _propsWidth = _kPropsWidth;

  Future<void> _update(DealInput input) =>
      ref.read(dealsProvider.notifier).updateDeal(widget.deal.id, input);

  Future<void> _delete() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete "${widget.deal.title}"?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(dealsProvider.notifier).delete(widget.deal.id);
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DealHeader(deal: deal, onClose: widget.onClose, onDelete: _delete),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth >= _kSplitBreak) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _RecordBody(deal: deal, onUpdate: _update)),
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
                        child: _PropertiesPanel(deal: deal, onUpdate: _update),
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
                    _PropertiesPanel(deal: deal, onUpdate: _update),
                    const SizedBox(height: LinearSpacing.xl),
                    _NotesSection(deal: deal, onUpdate: _update),
                    const SizedBox(height: LinearSpacing.xl),
                    _ActivitySection(deal: deal),
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

class _DealHeader extends StatelessWidget {
  const _DealHeader({required this.deal, required this.onDelete, this.onClose});

  final Deal deal;
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
          _StageDot(stage: deal.stage, size: 10),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deal.title, style: text.titleLarge, overflow: TextOverflow.ellipsis),
                if (deal.companyName != null || deal.contactName != null)
                  Text(
                    [deal.companyName, deal.contactName]
                        .whereType<String>()
                        .join(' · '),
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
            onPressed: () => showDealForm(context, deal: deal),
          ),
          const SizedBox(width: LinearSpacing.sm),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete deal',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Record body ────────────────────────────────────────────────────────────────

class _RecordBody extends StatelessWidget {
  const _RecordBody({required this.deal, required this.onUpdate});
  final Deal deal;
  final Future<void> Function(DealInput) onUpdate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotesSection(deal: deal, onUpdate: onUpdate),
          const SizedBox(height: LinearSpacing.xl),
          _ActivitySection(deal: deal),
        ],
      ),
    );
  }
}

// ── Notes ──────────────────────────────────────────────────────────────────────

class _NotesSection extends StatefulWidget {
  const _NotesSection({required this.deal, required this.onUpdate});
  final Deal deal;
  final Future<void> Function(DealInput) onUpdate;

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  late final _ctrl = TextEditingController(text: widget.deal.notes ?? '');
  bool _editing = false;
  bool _saving  = false;

  @override
  void didUpdateWidget(_NotesSection old) {
    super.didUpdateWidget(old);
    if (!_editing && old.deal.notes != widget.deal.notes) {
      _ctrl.text = widget.deal.notes ?? '';
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
      widget.deal.toInput().copyWith(notes: notes.isEmpty ? null : notes),
    );
    if (mounted) setState(() { _editing = false; _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
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
                    borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
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
                    onPressed: _saving ? null : () => setState(() => _editing = false),
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
                      : Text(_ctrl.text, style: text.bodyMedium?.copyWith(color: ext.textPrimary)),
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
  const _ActivitySection({required this.deal});
  final Deal deal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Activity'),
        const SizedBox(height: LinearSpacing.sm),
        _ActivityRow(
          icon: Icons.handshake_outlined,
          text: 'Deal created',
          time: _fmtDate(deal.createdAt),
        ),
        if (deal.notes?.isNotEmpty == true && deal.updatedAt != deal.createdAt)
          _ActivityRow(
            icon: Icons.edit_note_outlined,
            text: 'Notes updated',
            time: _fmtDate(deal.updatedAt),
          ),
        const SizedBox(height: LinearSpacing.sm),
        const _CommentInput(),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.icon, required this.text, required this.time});
  final IconData icon;
  final String   text;
  final String   time;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: ext.surfaceBase, shape: BoxShape.circle,
              border: Border.all(color: ext.borderSubtle),
            ),
            child: Icon(icon, size: 13, color: ext.textMuted),
          ),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: ext.textSecondary)),
          ),
          Text(time, style: Theme.of(context).textTheme.labelSmall),
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
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return TextField(
      controller: _ctrl,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ext.textPrimary),
      maxLines: null,
      onSubmitted: (_) => _ctrl.clear(),
      decoration: const InputDecoration(
        hintText: 'Add a comment…',
        contentPadding: EdgeInsets.symmetric(
          horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
      ),
    );
  }
}

// ── Properties panel ───────────────────────────────────────────────────────────

class _PropertiesPanel extends ConsumerWidget {
  const _PropertiesPanel({required this.deal, required this.onUpdate});
  final Deal deal;
  final Future<void> Function(DealInput) onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Properties'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Stage',
            child: _StageSelector(
              stage: deal.stage,
              onChanged: (s) => onUpdate(deal.toInput().copyWith(stage: s)),
            ),
          ),

          _PropRow(
            label: 'Value',
            child: Text(
              deal.displayValue,
              style: text.bodySmall?.copyWith(color: ext.textPrimary),
            ),
          ),

          _PropRow(
            label: 'Company',
            child: Text(
              deal.companyName ?? '—',
              style: text.bodySmall?.copyWith(
                color: deal.companyName != null ? ext.textPrimary : ext.textMuted),
            ),
          ),
          _PropRow(
            label: 'Contact',
            child: Text(
              deal.contactName ?? '—',
              style: text.bodySmall?.copyWith(
                color: deal.contactName != null ? ext.textPrimary : ext.textMuted),
            ),
          ),
          if (deal.probability != null)
            _PropRow(
              label: 'Prob.',
              child: Text('${deal.probability}%',
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (deal.closeDate != null)
            _PropRow(
              label: 'Closes',
              child: Text(_fmtDate(deal.closeDate!),
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          _PropRow(
            label: 'Owner',
            child: Text(
              deal.ownerName ?? '—',
              style: text.bodySmall?.copyWith(
                color: deal.ownerName != null ? ext.textPrimary : ext.textMuted),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Dates'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(label: 'Created', child: Text(_fmtDate(deal.createdAt), style: text.bodySmall)),
          _PropRow(
            label: 'By',
            child: Text(
              deal.createdByName ?? '—',
              style: text.bodySmall?.copyWith(
                color: deal.createdByName != null ? ext.textPrimary : ext.textMuted),
            ),
          ),
          _PropRow(label: 'Updated', child: Text(_fmtDate(deal.updatedAt), style: text.bodySmall)),
        ],
      ),
    );
  }
}

// ── Stage selector ─────────────────────────────────────────────────────────────

class _StageSelector extends StatelessWidget {
  const _StageSelector({required this.stage, required this.onChanged});
  final DealStage stage;
  final ValueChanged<DealStage> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DealStage>(
      tooltip: 'Change stage',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 160),
      itemBuilder: (_) => DealStage.values.map((s) => PopupMenuItem<DealStage>(
            value: s,
            height: 32,
            child: Row(
              children: [
                _StageDot(stage: s, size: 6),
                const SizedBox(width: LinearSpacing.sm),
                Text(s.label,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.linearExt.textPrimary)),
              ],
            ),
          )).toList(),
      onSelected: onChanged,
      child: _StagePill(stage: stage),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});
  final DealStage stage;

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StageDot(stage: stage, size: 6),
          const SizedBox(width: 4),
          Text(stage.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 11, color: color),
        ],
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.stage, this.size = 8});
  final DealStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.linearExt.textMuted,
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
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: ext.textMuted)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
