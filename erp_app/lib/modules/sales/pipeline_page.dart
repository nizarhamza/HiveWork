import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/deal.dart';
import '../../data/providers/deals_provider.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import 'deal_detail_pane.dart';
import 'deal_form_dialog.dart';
import 'sales_commands.dart';

const double _kSplitBreak   = 860.0;
const double _kListWidth    = 320.0;
const double _kListWidthMin = 200.0;
const double _kListWidthMax = 500.0;
const double _kColMinWidth  = 160.0;

enum _ViewMode { kanban, list }

class PipelinePage extends ConsumerStatefulWidget {
  const PipelinePage({super.key, this.initialDealId});
  final String? initialDealId;

  @override
  ConsumerState<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends ConsumerState<PipelinePage> {
  String?   _selectedId;
  _ViewMode _viewMode = _ViewMode.kanban;
  double    _listWidth = _kListWidth;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialDealId;
  }

  void _select(String? id) => setState(() => _selectedId = id);

  void _moveToStage(Deal deal, DealStage stage) {
    if (deal.stage == stage) return;
    ref.read(dealsProvider.notifier).updateDeal(deal.id, deal.toInput().copyWith(stage: stage));
  }

  @override
  Widget build(BuildContext context) {
    final dealsAsync = ref.watch(dealsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _kSplitBreak;

    return SalesCommands(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearViewHeader(
            icon: Icons.view_kanban_outlined,
            title: 'Pipeline',
            actions: [
              _ViewToggle(
                mode: _viewMode,
                onChanged: (m) => setState(() { _viewMode = m; _selectedId = null; }),
              ),
              LinearNewButton(
                label: 'New deal',
                onPressed: () => showDealForm(context),
              ),
            ],
          ),
          Expanded(
            child: dealsAsync.when(
              loading: () => const _LoadingSkeleton(),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (deals) => _buildBody(deals, isWide),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Deal> deals, bool isWide) {
    if (_viewMode == _ViewMode.kanban) {
      return _KanbanBoard(
        deals: deals,
        onOpenDetail: (id) => showDealDetail(context, id),
        onMoveToStage: _moveToStage,
      );
    }

    final selected = _selectedId != null
        ? deals.where((d) => d.id == _selectedId).firstOrNull
        : null;

    if (_selectedId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedId = null);
      });
    }

    // List view
    if (isWide && selected != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _listWidth,
            child: _DealList(deals: deals, selectedId: _selectedId, onSelect: _select),
          ),
          ResizablePaneDivider(
            onDrag: (delta) => setState(() {
              _listWidth = (_listWidth + delta).clamp(_kListWidthMin, _kListWidthMax);
            }),
          ),
          Expanded(
            child: DealDetailPane(deal: selected, onClose: () => _select(null)),
          ),
        ],
      );
    }

    if (selected != null) {
      return DealDetailPane(deal: selected, onClose: () => _select(null));
    }

    if (deals.isEmpty) {
      return const AppEmptyState(
        icon: Icons.handshake_outlined,
        title: 'No deals yet',
        description: 'Create your first deal to start tracking your pipeline.',
      );
    }

    return _DealList(deals: deals, selectedId: _selectedId, onSelect: _select);
  }
}

// ── Kanban board ───────────────────────────────────────────────────────────────

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.deals,
    required this.onOpenDetail,
    required this.onMoveToStage,
  });

  final List<Deal>                     deals;
  final ValueChanged<String>           onOpenDetail;
  final void Function(Deal, DealStage) onMoveToStage;

  @override
  Widget build(BuildContext context) {
    final byStage = <DealStage, List<Deal>>{
      for (final s in DealStage.values) s: [],
    };
    for (final d in deals) { byStage[d.stage]!.add(d); }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final numCols  = DealStage.values.length;
        final colWidth = constraints.maxWidth / numCols;
        final useScroll = colWidth < _kColMinWidth;

        Widget columns = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final stage in DealStage.values)
              useScroll
                  ? SizedBox(
                      width: _kColMinWidth * 1.5,
                      child: _KanbanColumn(
                        stage: stage,
                        deals: byStage[stage]!,
                        onOpenDetail: onOpenDetail,
                        onMoveToStage: onMoveToStage,
                      ),
                    )
                  : Expanded(
                      child: _KanbanColumn(
                        stage: stage,
                        deals: byStage[stage]!,
                        onOpenDetail: onOpenDetail,
                        onMoveToStage: onMoveToStage,
                      ),
                    ),
          ],
        );

        if (useScroll) {
          columns = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: columns,
          );
        }

        return columns;
      },
    );
  }
}

// ── Kanban column with DragTarget ──────────────────────────────────────────────

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    required this.stage,
    required this.deals,
    required this.onOpenDetail,
    required this.onMoveToStage,
  });

  final DealStage                      stage;
  final List<Deal>                     deals;
  final ValueChanged<String>           onOpenDetail;
  final void Function(Deal, DealStage) onMoveToStage;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  bool _hovering = false;

  double get _totalValue => widget.deals.fold(0.0, (s, d) => s + d.value);

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    final color = widget.stage.color;

    return DragTarget<Deal>(
      onWillAcceptWithDetails: (details) {
        if (details.data.stage == widget.stage) return false;
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onMoveToStage(details.data, widget.stage);
      },
      builder: (ctx, candidates, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(LinearSpacing.sm),
          decoration: BoxDecoration(
            color: _hovering
                ? widget.stage.color.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadii.md),
            border: Border.all(
              color: _hovering
                  ? widget.stage.color.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Column header ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LinearSpacing.sm, LinearSpacing.sm, LinearSpacing.sm, 4),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: LinearSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.stage.label,
                        style: text.labelMedium?.copyWith(
                          color: ext.textSecondary, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: ext.overlay,
                        borderRadius: BorderRadius.circular(LinearRadii.pill),
                      ),
                      child: Text('${widget.deals.length}',
                          style: text.labelSmall?.copyWith(color: ext.textMuted)),
                    ),
                  ],
                ),
              ),
              if (widget.deals.isNotEmpty && _totalValue > 0)
                Padding(
                  padding: const EdgeInsets.only(
                    left: LinearSpacing.sm, bottom: LinearSpacing.xs),
                  child: Text(
                    _fmtTotal(widget.deals),
                    style: text.labelSmall?.copyWith(color: ext.textMuted),
                  ),
                ),
              // ── Cards ────────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    LinearSpacing.sm, LinearSpacing.xs,
                    LinearSpacing.sm, LinearSpacing.base),
                  itemCount: widget.deals.length,
                  itemBuilder: (_, i) {
                    final deal = widget.deals[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
                      child: _DraggableDealCard(
                        deal: deal,
                        onTap: () => widget.onOpenDetail(deal.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtTotal(List<Deal> deals) {
    final currency = deals.first.currency;
    final sym = currency == 'EUR' ? '€' : currency == 'USD' ? '\$' : '£';
    final total = _totalValue;
    if (total >= 1000000) return '$sym${(total / 1000000).toStringAsFixed(1)}M';
    if (total >= 1000)    return '$sym${(total / 1000).toStringAsFixed(0)}K';
    return '$sym${total.toStringAsFixed(0)}';
  }
}

// ── Draggable deal card ────────────────────────────────────────────────────────

class _DraggableDealCard extends StatelessWidget {
  const _DraggableDealCard({
    required this.deal,
    required this.onTap,
  });

  final Deal         deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Draggable<Deal>(
      data: deal,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        color: Colors.transparent,
        child: SizedBox(
          width: 220,
          child: _DealCard(deal: deal, onTap: () {}, isDragFeedback: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _DealCard(deal: deal, onTap: () {}),
      ),
      child: _DealCard(deal: deal, onTap: onTap),
    );
  }
}

// ── Deal card ──────────────────────────────────────────────────────────────────

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.deal,
    required this.onTap,
    this.isDragFeedback = false,
  });

  final Deal         deal;
  final VoidCallback onTap;
  final bool         isDragFeedback;

  @override
  Widget build(BuildContext context) {
    final ext   = context.linearExt;
    final text  = Theme.of(context).textTheme;
    final color = deal.stage.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        child: Container(
          padding: const EdgeInsets.all(LinearSpacing.base),
          decoration: BoxDecoration(
            color: ext.surfaceRaised,
            borderRadius: BorderRadius.circular(LinearRadii.md),
            border: Border.all(color: ext.borderSubtle),
            boxShadow: isDragFeedback
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deal.title,
                style: text.bodySmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (deal.companyName != null || deal.contactName != null) ...[
                const SizedBox(height: 4),
                Text(
                  [deal.companyName, deal.contactName]
                      .whereType<String>().join(' · '),
                  style: text.labelSmall?.copyWith(color: ext.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: LinearSpacing.sm),
              Row(
                children: [
                  if (deal.value > 0)
                    Expanded(
                      child: Text(
                        deal.displayValue,
                        style: text.labelSmall?.copyWith(
                          color: ext.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (deal.probability != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(LinearRadii.xs),
                      ),
                      child: Text('${deal.probability}%',
                          style: text.labelSmall?.copyWith(color: color)),
                    ),
                ],
              ),
              if (deal.closeDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 10, color: ext.textMuted),
                    const SizedBox(width: 4),
                    Text(_fmtDate(deal.closeDate!),
                        style: text.labelSmall?.copyWith(color: ext.textMuted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── List view ──────────────────────────────────────────────────────────────────

class _DealList extends StatelessWidget {
  const _DealList({
    required this.deals,
    required this.selectedId,
    required this.onSelect,
  });
  final List<Deal>            deals;
  final String?               selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final byStage = <DealStage, List<Deal>>{};
    for (final d in deals) { byStage.putIfAbsent(d.stage, () => []).add(d); }
    final sections = DealStage.values.where((s) => byStage.containsKey(s)).toList();

    return ListView.builder(
      itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + (byStage[s]?.length ?? 0)),
      itemBuilder: (context, i) {
        var offset = 0;
        for (final stage in sections) {
          final rows = byStage[stage]!;
          if (i == offset) return _ListGroupHeader(stage: stage, count: rows.length);
          offset++;
          if (i < offset + rows.length) {
            final deal = rows[i - offset];
            return _DealListRow(
              deal: deal,
              selected: deal.id == selectedId,
              onTap: () => onSelect(deal.id),
            );
          }
          offset += rows.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ListGroupHeader extends StatelessWidget {
  const _ListGroupHeader({required this.stage, required this.count});
  final DealStage stage;
  final int       count;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      color: ext.overlay,
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle)),
          const SizedBox(width: LinearSpacing.sm),
          Text(stage.label,
              style: text.labelMedium?.copyWith(
                  color: ext.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: LinearSpacing.sm),
          Text('$count', style: text.labelMedium?.copyWith(color: ext.textMuted)),
        ],
      ),
    );
  }
}

class _DealListRow extends StatelessWidget {
  const _DealListRow({required this.deal, required this.selected, required this.onTap});
  final Deal         deal;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? LinearColors.accent.withValues(alpha: 0.06) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          overlayColor: WidgetStatePropertyAll(ext.overlay),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ext.borderSubtle)),
              color: selected ? LinearColors.accent.withValues(alpha: 0.06) : null,
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: deal.stage.color, shape: BoxShape.circle)),
                const SizedBox(width: LinearSpacing.base),
                Expanded(
                  flex: 3,
                  child: Text(deal.title,
                      style: text.bodySmall?.copyWith(
                        color: ext.textPrimary,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.w400),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Text(deal.companyName ?? deal.contactName ?? '',
                      style: text.bodySmall?.copyWith(color: ext.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(deal.displayValue,
                    style: text.bodySmall?.copyWith(
                        color: ext.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── View toggle ────────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChanged});
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      decoration: BoxDecoration(
        color: ext.overlay,
        borderRadius: BorderRadius.circular(LinearRadii.sm),
        border: Border.all(color: ext.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.view_kanban_outlined,
            tooltip: 'Kanban',
            selected: mode == _ViewMode.kanban,
            onTap: () => onChanged(_ViewMode.kanban),
          ),
          _ToggleBtn(
            icon: Icons.view_list_outlined,
            tooltip: 'List',
            selected: mode == _ViewMode.list,
            onTap: () => onChanged(_ViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String   tooltip;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinearRadii.sm),
        child: Container(
          width: 30, height: 26,
          decoration: BoxDecoration(
            color: selected ? ext.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadii.xs),
          ),
          child: Icon(icon, size: 14,
              color: selected ? ext.textPrimary : ext.textMuted),
        ),
      ),
    );
  }
}

// ── Loading / error ────────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 6,
        itemBuilder: (_, _) => const AppContactRowSkeleton(),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: LinearColors.danger, size: 32),
            const SizedBox(height: LinearSpacing.sm),
            Text('Could not load deals', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: LinearSpacing.xs),
            Text(message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}
