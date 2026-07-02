import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/view_prefs_service.dart';
import '../../data/models/invoice.dart';
import '../../data/providers/invoices_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_data_table.dart';
import 'invoice_detail_pane.dart';
import 'invoice_form_dialog.dart';

const double _kSplitBreak   = 860.0;
const double _kListWidth    = 400.0;
const double _kListWidthMin = 390.0;
const double _kListWidthMax = 580.0;

// ── Column definitions ─────────────────────────────────────────────────────────

enum _ColId { number, client, status, dueDate, total }

class _ColDef {
  const _ColDef({
    required this.id,
    required this.label,
    required this.width,
    this.visible = true,
    this.alwaysVisible = false,
  });

  final _ColId id;
  final String label;
  final double width;
  final bool   visible;
  final bool   alwaysVisible;

  _ColDef copyWith({bool? visible, double? width}) => _ColDef(
        id: id, label: label, width: width ?? this.width,
        visible: visible ?? this.visible, alwaysVisible: alwaysVisible,
      );
}

const _kDefaultColumns = <_ColDef>[
  _ColDef(id: _ColId.number,  label: 'Number',   width: 160, alwaysVisible: true),
  _ColDef(id: _ColId.client,  label: 'Client',   width: 140),
  _ColDef(id: _ColId.status,  label: 'Status',   width: 90),
  _ColDef(id: _ColId.dueDate, label: 'Due date', width: 100),
  _ColDef(id: _ColId.total,   label: 'Total',    width: 90),
];

// ── Cell builders ──────────────────────────────────────────────────────────────

Widget _buildCell(
    _ColId id, InvoiceWithClient item, BuildContext ctx, bool selected) {
  final ext  = ctx.linearExt;
  final text = Theme.of(ctx).textTheme;
  final inv  = item.invoice;

  switch (id) {
    case _ColId.number:
      return Text(
        inv.number,
        style: text.bodySmall?.copyWith(
          color:      ext.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      );
    case _ColId.client:
      return Text(
        item.clientName ?? '—',
        style: text.bodySmall?.copyWith(
          color: item.clientName != null ? ext.textSecondary : ext.textMuted,
        ),
        overflow: TextOverflow.ellipsis,
      );
    case _ColId.status:
      return _InvoiceStatusPill(status: inv.status);
    case _ColId.dueDate:
      if (inv.dueDate == null) {
        return Text('—', style: text.bodySmall?.copyWith(color: ext.textMuted));
      }
      final overdue = inv.status == InvoiceStatus.overdue;
      return Text(
        _fmtDate(inv.dueDate!),
        style: text.bodySmall?.copyWith(
          color: overdue ? LinearColors.danger : ext.textSecondary,
        ),
        overflow: TextOverflow.ellipsis,
      );
    case _ColId.total:
      return Text(
        inv.displayTotal,
        style: text.bodySmall?.copyWith(
          color:      ext.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.end,
        overflow:  TextOverflow.ellipsis,
      );
  }
}

Comparable? Function(InvoiceWithClient)? _sortKeyFor(_ColId id) => switch (id) {
  _ColId.number  => (i) => i.invoice.number.toLowerCase(),
  _ColId.client  => (i) => i.clientName?.toLowerCase(),
  _ColId.status  => (i) => i.invoice.status.index,
  _ColId.dueDate => (i) => i.invoice.dueDate?.millisecondsSinceEpoch,
  _ColId.total   => (i) => i.invoice.total,
};

String? _fitValueFor(_ColId id, InvoiceWithClient i) => switch (id) {
  _ColId.number  => i.invoice.number,
  _ColId.client  => i.clientName,
  _ColId.status  => i.invoice.status.label,
  _ColId.dueDate => i.invoice.dueDate != null ? _fmtDate(i.invoice.dueDate!) : null,
  _ColId.total   => i.invoice.displayTotal,
};

AppColumnDef<InvoiceWithClient> _toAppDef(_ColDef col) =>
    AppColumnDef<InvoiceWithClient>(
      id:            col.id.name,
      label:         col.label,
      width:         col.width,
      visible:       col.visible,
      alwaysVisible: col.alwaysVisible,
      flex:          col.id == _ColId.number,
      sortKey:       _sortKeyFor(col.id),
      valueForFit:   (i) => _fitValueFor(col.id, i),
      builder:       (ctx, i, sel) => _buildCell(col.id, i, ctx, sel),
    );

// ── Preference persistence ─────────────────────────────────────────────────────

class _Prefs {
  static const _listWidthKey = 'invoices.listWidth';
  static const _visibleCols  = 'invoices.visibleColumns';
  static const _colWidths    = 'invoices.colWidths';
  static const _sortColKey   = 'invoices.sortCol';
  static const _sortAscKey   = 'invoices.sortAsc';

  static Future<void> saveListWidth(double v) =>
      ViewPrefsService.setDouble(_listWidthKey, v);

  static Future<void> saveColumns(List<_ColDef> cols) =>
      ViewPrefsService.setStringList(
          _visibleCols, [for (final c in cols) if (c.visible) c.id.name]);

  static Future<void> saveColumnWidths(List<_ColDef> cols) =>
      ViewPrefsService.setStringList(
          _colWidths, [for (final c in cols) '${c.id.name}:${c.width}']);

  static Future<void> saveSort(String? colId, bool ascending) async {
    if (colId == null) {
      await ViewPrefsService.removeKey(_sortColKey);
    } else {
      await ViewPrefsService.setString(_sortColKey, colId);
    }
    await ViewPrefsService.setBoolOrNull(_sortAscKey, ascending);
  }

  static Map<String, double> _parseWidths(List<String> list) {
    final map = <String, double>{};
    for (final entry in list) {
      final i = entry.indexOf(':');
      if (i > 0) {
        final w = double.tryParse(entry.substring(i + 1));
        if (w != null) map[entry.substring(0, i)] = w;
      }
    }
    return map;
  }

  static Future<({
    double listWidth,
    List<_ColDef> columns,
    String? sortColId,
    bool sortAscending,
  })> load() async {
    final listWidth =
        await ViewPrefsService.getDouble(_listWidthKey, _kListWidth);

    List<_ColDef> cols = _kDefaultColumns;
    final savedVis = await ViewPrefsService.getStringList(_visibleCols);
    if (savedVis != null) {
      final visSet = savedVis.toSet();
      cols = [
        for (final c in _kDefaultColumns)
          c.alwaysVisible ? c : c.copyWith(visible: visSet.contains(c.id.name)),
      ];
    }

    final savedWidths = await ViewPrefsService.getStringList(_colWidths);
    if (savedWidths != null) {
      final widthMap = _parseWidths(savedWidths);
      cols = [
        for (final c in cols)
          widthMap.containsKey(c.id.name)
              ? c.copyWith(width: widthMap[c.id.name]!)
              : c,
      ];
    }

    final sortColId   = await ViewPrefsService.getString(_sortColKey);
    final sortAscBool = await ViewPrefsService.getBoolOrNull(_sortAscKey);

    return (
      listWidth:     listWidth,
      columns:       cols,
      sortColId:     sortColId,
      sortAscending: sortAscBool ?? true,
    );
  }
}

// ── Page ───────────────────────────────────────────────────────────────────────

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key, this.initialInvoiceId});
  final String? initialInvoiceId;

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  String?         _selectedId;
  String          _search       = '';
  InvoiceStatus?  _statusFilter;
  double          _listWidth    = _kListWidth;
  List<_ColDef>   _columns      = _kDefaultColumns;
  String?         _sortColId;
  bool            _sortAsc      = true;
  Timer?          _saveWidthTimer;
  Timer?          _saveColWidthTimer;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialInvoiceId;
    _loadPrefs();
  }

  @override
  void dispose() {
    _saveWidthTimer?.cancel();
    _saveColWidthTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await _Prefs.load();
    if (!mounted) return;
    setState(() {
      _listWidth = p.listWidth;
      _columns   = p.columns;
      _sortColId = p.sortColId;
      _sortAsc   = p.sortAscending;
    });
  }

  List<InvoiceWithClient> _filter(List<InvoiceWithClient> all) {
    final q = _search.trim().toLowerCase();
    return all.where((item) {
      if (q.isNotEmpty) {
        final inNum    = item.invoice.number.toLowerCase().contains(q);
        final inClient = item.clientName?.toLowerCase().contains(q) ?? false;
        if (!inNum && !inClient) return false;
      }
      if (_statusFilter != null && item.invoice.status != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<AppTableGroup<InvoiceWithClient>> _buildGroups(
      List<InvoiceWithClient> invoices) {
    final sorted = List<InvoiceWithClient>.from(invoices);
    if (_sortColId != null) {
      try {
        final colId = _ColId.values.byName(_sortColId!);
        final key   = _sortKeyFor(colId);
        if (key != null) {
          sorted.sort((a, b) {
            final ka = key(a);
            final kb = key(b);
            if (ka == null && kb == null) return 0;
            if (ka == null) return _sortAsc ? 1 : -1;
            if (kb == null) return _sortAsc ? -1 : 1;
            return _sortAsc ? ka.compareTo(kb) : kb.compareTo(ka);
          });
        }
      } catch (_) {}
    }
    return [AppTableGroup(label: 'Invoices', items: sorted)];
  }

  void _resizeColumn(int visibleIndex, double delta) {
    final visible = _columns.where((c) => c.visible).toList();
    if (visibleIndex >= visible.length) return;
    final col      = visible[visibleIndex];
    final newWidth = (col.width + delta).clamp(40.0, double.infinity);
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id == col.id ? c.copyWith(width: newWidth) : c,
      ];
    });
    _saveColWidthTimer?.cancel();
    _saveColWidthTimer = Timer(const Duration(milliseconds: 400), () {
      _Prefs.saveColumnWidths(_columns);
    });
  }

  void _reorderColumns(int from, int to) {
    if (from == to) return;
    final visible = _columns.where((c) => c.visible).toList();
    final hidden  = _columns.where((c) => !c.visible).toList();
    final col     = visible.removeAt(from);
    visible.insert(to, col);
    setState(() => _columns = [...visible, ...hidden]);
    _Prefs.saveColumns(_columns);
  }

  void _hideColumn(String columnId) {
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id.name == columnId ? c.copyWith(visible: false) : c,
      ];
    });
    _Prefs.saveColumns(_columns);
  }

  void _autoFitColumn(String columnId, double width) {
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id.name == columnId ? c.copyWith(width: width) : c,
      ];
    });
    _Prefs.saveColumnWidths(_columns);
  }

  void _onSortChanged(String columnId) {
    setState(() {
      if (_sortColId == columnId) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColId = columnId;
        _sortAsc   = true;
      }
    });
    _Prefs.saveSort(_sortColId, _sortAsc);
  }

  Future<void> _newInvoice() async {
    final orgId = await ref.read(currentOrgIdProvider.future) ?? '';
    if (!mounted) return;
    final result = await showInvoiceForm(
      context,
      initial: InvoiceInput(orgId: orgId, lines: const []),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(invoicesProvider.notifier).create(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e')),
        );
      }
    }
  }

  Future<void> _editInvoice(InvoiceWithClient item) async {
    if (!mounted) return;
    final result = await showInvoiceForm(
      context,
      initial: item.invoice.toInput(),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(invoicesProvider.notifier).updateInvoice(item.invoice.id, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final isWide        = MediaQuery.sizeOf(context).width >= _kSplitBreak;
    final ext           = context.linearExt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearViewHeader(
          icon:  Icons.receipt_long_outlined,
          title: 'Invoices',
          center: SizedBox(
            width: 480,
            child: _CompactSearch(
              onChanged: (v) => setState(() {
                _search     = v;
                _selectedId = null;
              }),
            ),
          ),
          actions: [
            _StatusFilterButton(
              current:   _statusFilter,
              onChanged: (s) => setState(() {
                _statusFilter = s;
                _selectedId   = null;
              }),
            ),
            AppIconButton(
              icon:      Icons.refresh_rounded,
              tooltip:   'Refresh',
              onPressed: () => ref.read(invoicesProvider.notifier).refresh(),
            ),
            SizedBox(
              height: 16, width: 1,
              child: ColoredBox(color: ext.borderBase),
            ),
            LinearNewButton(
              label:     'New invoice',
              onPressed: _newInvoice,
            ),
          ],
        ),
        Expanded(
          child: invoicesAsync.when(
            loading: () => const _Skeleton(),
            error:   (e, _) => _ErrorState(e.toString()),
            data:    (all) {
              if (all.isEmpty) {
                return AppEmptyState(
                  icon:        Icons.receipt_long_outlined,
                  title:       'No invoices yet',
                  description: 'Create your first invoice with the button above.',
                  action: AppButton(
                    label:     'New invoice',
                    variant:   AppButtonVariant.filled,
                    icon:      Icons.add,
                    onPressed: _newInvoice,
                  ),
                );
              }
              final filtered = _filter(all);
              return _buildBody(filtered, isWide);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<InvoiceWithClient> invoices, bool isWide) {
    final selected =
        invoices.where((i) => i.invoice.id == _selectedId).firstOrNull;

    if (selected == null && _selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) setState(() => _selectedId = null); });
    }

    if (invoices.isEmpty) {
      return Center(
        child: Text(
          'No invoices match the filter.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.linearExt.textMuted),
        ),
      );
    }

    final table = _buildTable(invoices);

    if (!isWide || selected == null) return table;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _listWidth, child: table),
        ResizablePaneDivider(
          onDrag: (d) {
            setState(() {
              _listWidth =
                  (_listWidth + d).clamp(_kListWidthMin, _kListWidthMax);
            });
            _saveWidthTimer?.cancel();
            _saveWidthTimer = Timer(const Duration(milliseconds: 400), () {
              _Prefs.saveListWidth(_listWidth);
            });
          },
        ),
        Expanded(
          child: InvoiceDetailPane(
            item:    selected,
            onClose: () => setState(() => _selectedId = null),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<InvoiceWithClient> invoices) {
    final actionsCol = AppColumnDef<InvoiceWithClient>(
      id:            'actions',
      label:         '',
      width:         36,
      alwaysVisible: true,
      builder: (ctx, item, _) => _InvoiceActionsMenu(
        item:   item,
        onEdit: () => _editInvoice(item),
      ),
    );

    return AppDataTable<InvoiceWithClient>(
      groups:          _buildGroups(invoices),
      columns:         [for (final c in _columns) _toAppDef(c)],
      trailingColumns: [actionsCol],
      leadingBuilder:  (_, _) => const SizedBox.shrink(),
      leadingWidth:    0,
      itemKey:         (i) => i.invoice.id,
      onTap:           (i) => setState(() =>
          _selectedId = i.invoice.id == _selectedId ? null : i.invoice.id),
      selectedKey:     _selectedId,
      sortColumnId:    _sortColId,
      sortAscending:   _sortAsc,
      onSortChanged:   _onSortChanged,
      onColumnsReorder: _reorderColumns,
      onColumnResize:  _resizeColumn,
      onHideColumn:    _hideColumn,
      onColumnAutoFit: _autoFitColumn,
    );
  }
}

// ── Actions menu ───────────────────────────────────────────────────────────────

enum _InvoiceAction { edit }

class _InvoiceActionsMenu extends StatefulWidget {
  const _InvoiceActionsMenu({
    required this.item,
    required this.onEdit,
  });

  final InvoiceWithClient item;
  final VoidCallback      onEdit;

  @override
  State<_InvoiceActionsMenu> createState() => _InvoiceActionsMenuState();
}

class _InvoiceActionsMenuState extends State<_InvoiceActionsMenu> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: PopupMenuButton<_InvoiceAction>(
        tooltip:     'More actions',
        padding:     EdgeInsets.zero,
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding:  const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _hovered ? ext.overlayActive : Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadii.xs),
          ),
          child: Icon(Icons.more_horiz_rounded, size: 16,
              color: _hovered ? ext.textSecondary : ext.textMuted),
        ),
        iconSize:    16,
        offset:      const Offset(0, 28),
        constraints: const BoxConstraints(minWidth: 160),
        itemBuilder: (_) => [
          PopupMenuItem(
            value:  _InvoiceAction.edit,
            height: 32,
            child:  Text('Edit',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
        onSelected: (action) {
          switch (action) {
            case _InvoiceAction.edit:
              widget.onEdit();
          }
        },
      ),
    );
  }
}

// ── Status filter button ───────────────────────────────────────────────────────

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({required this.current, required this.onChanged});
  final InvoiceStatus?               current;
  final ValueChanged<InvoiceStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext    = context.linearExt;
    final text   = Theme.of(context).textTheme;
    final active = current != null;

    return PopupMenuButton<InvoiceStatus?>(
      tooltip:     'Filter by status',
      padding:     EdgeInsets.zero,
      offset:      const Offset(0, 36),
      constraints: const BoxConstraints(minWidth: 160),
      itemBuilder: (_) => [
        PopupMenuItem<InvoiceStatus?>(
          value:  null,
          height: 32,
          child:  Text('All statuses',
              style: text.bodySmall?.copyWith(
                  color: current == null ? ext.textPrimary : ext.textMuted)),
        ),
        const PopupMenuDivider(height: 1),
        ...InvoiceStatus.values.map(
          (s) => PopupMenuItem<InvoiceStatus?>(
            value:  s,
            height: 32,
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(s.label,
                    style: text.bodySmall?.copyWith(
                        color: current == s
                            ? ext.textPrimary
                            : ext.textSecondary)),
              ],
            ),
          ),
        ),
      ],
      onSelected: onChanged,
      child: _GhostChip(
        active: active,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                    color: current!.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ] else ...[
              Icon(Icons.filter_list_rounded, size: 13, color: ext.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              current?.label ?? 'Status',
              style: text.labelMedium?.copyWith(
                  color: active ? ext.textPrimary : ext.textSecondary,
                  fontSize: 11),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 12,
                color: ext.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Ghost chip ─────────────────────────────────────────────────────────────────

class _GhostChip extends StatefulWidget {
  const _GhostChip({required this.child, required this.active});
  final Widget child;
  final bool   active;

  @override
  State<_GhostChip> createState() => _GhostChipState();
}

class _GhostChipState extends State<_GhostChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.active
              ? LinearColors.accent.withValues(alpha: 0.08)
              : _hovered
                  ? ext.overlayActive
                  : Colors.transparent,
          border: Border.all(
            color: widget.active
                ? LinearColors.accent.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(LinearRadii.md),
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Compact header search ──────────────────────────────────────────────────────

class _CompactSearch extends StatefulWidget {
  const _CompactSearch({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_CompactSearch> createState() => _CompactSearchState();
}

class _CompactSearchState extends State<_CompactSearch> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    _ctrl.addListener(() {
      final has = _ctrl.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 28,
      decoration: BoxDecoration(
        color: _focused ? ext.surfaceBase : ext.overlay,
        border: Border.all(
          color: _focused ? ext.borderBase : ext.borderSubtle,
        ),
        borderRadius: BorderRadius.circular(LinearRadii.md),
      ),
      child: TextField(
        controller: _ctrl,
        focusNode:  _focus,
        onChanged:  widget.onChanged,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color:    ext.textPrimary,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText:  'Search invoices, clients…',
          hintStyle: TextStyle(fontSize: 12, color: ext.textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 13,
              color: ext.textMuted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 30, minHeight: 28),
          suffixIcon: _hasText
              ? GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    widget.onChanged('');
                  },
                  child: Icon(Icons.close_rounded, size: 12,
                      color: ext.textMuted),
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          isDense: true,
          filled:  false,
        ),
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────────────

class _InvoiceStatusPill extends StatelessWidget {
  const _InvoiceStatusPill({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(
          10,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LinearSpacing.base, vertical: LinearSpacing.xs),
            child: AppSkeleton.line(height: 32),
          ),
        ),
      );
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LinearSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: LinearColors.danger),
            const SizedBox(height: LinearSpacing.sm),
            Text('Failed to load invoices',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: LinearSpacing.xs),
            Text(message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Helper ─────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun',
              'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
}
