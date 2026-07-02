import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/view_prefs_service.dart';
import '../../data/models/quote.dart';
import '../../data/providers/quotes_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_data_table.dart';
import 'quote_detail_pane.dart';
import 'quote_form_dialog.dart';
import 'sales_commands.dart';

const double _kSplitBreak   = 860.0;
const double _kListWidth    = 400.0;
const double _kListWidthMin = 390.0;
const double _kListWidthMax = 580.0;

// ── Column definitions ─────────────────────────────────────────────────────────

enum _ColId { number, client, status, total }

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
  _ColDef(id: _ColId.number, label: 'Number', width: 160, alwaysVisible: true),
  _ColDef(id: _ColId.client, label: 'Client',  width: 140),
  _ColDef(id: _ColId.status, label: 'Status',  width: 90),
  _ColDef(id: _ColId.total,  label: 'Total',   width: 90),
];

// ── Cell builders, sort keys, fit values ──────────────────────────────────────

Widget _buildCell(
    _ColId id, QuoteWithClient item, BuildContext ctx, bool selected) {
  final ext   = ctx.linearExt;
  final text  = Theme.of(ctx).textTheme;
  final quote = item.quote;

  switch (id) {
    case _ColId.number:
      return Text(
        quote.number,
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
      return _QuoteStatusPill(status: quote.status);
    case _ColId.total:
      return Text(
        quote.displayTotal,
        style: text.bodySmall?.copyWith(
          color:      ext.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.end,
        overflow:  TextOverflow.ellipsis,
      );
  }
}

Comparable? Function(QuoteWithClient)? _sortKeyFor(_ColId id) => switch (id) {
  _ColId.number => (q) => q.quote.number.toLowerCase(),
  _ColId.client => (q) => q.clientName?.toLowerCase(),
  _ColId.status => (q) => q.quote.status.index,
  _ColId.total  => (q) => q.quote.total,
};

String? _fitValueFor(_ColId id, QuoteWithClient q) => switch (id) {
  _ColId.number => q.quote.number,
  _ColId.client => q.clientName,
  _ColId.status => q.quote.status.label,
  _ColId.total  => q.quote.displayTotal,
};

AppColumnDef<QuoteWithClient> _toAppDef(_ColDef col) =>
    AppColumnDef<QuoteWithClient>(
      id:            col.id.name,
      label:         col.label,
      width:         col.width,
      visible:       col.visible,
      alwaysVisible: col.alwaysVisible,
      flex:          col.id == _ColId.number,
      sortKey:       _sortKeyFor(col.id),
      valueForFit:   (q) => _fitValueFor(col.id, q),
      builder:       (ctx, q, sel) => _buildCell(col.id, q, ctx, sel),
    );

// ── Preference persistence ─────────────────────────────────────────────────────

class _Prefs {
  static const _listWidthKey = 'quotes.listWidth';
  static const _visibleCols  = 'quotes.visibleColumns';
  static const _colWidths    = 'quotes.colWidths';
  static const _sortColKey   = 'quotes.sortCol';
  static const _sortAscKey   = 'quotes.sortAsc';

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

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key, this.initialQuoteId});
  final String? initialQuoteId;

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  String?       _selectedId;
  String        _search       = '';
  QuoteStatus?  _statusFilter;
  double        _listWidth    = _kListWidth;
  List<_ColDef> _columns      = _kDefaultColumns;
  String?       _sortColId;
  bool          _sortAsc      = true;
  Timer?        _saveWidthTimer;
  Timer?        _saveColWidthTimer;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialQuoteId;
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

  // ── Filtering & grouping ─────────────────────────────────────────────────────

  List<QuoteWithClient> _filter(List<QuoteWithClient> all) {
    final q = _search.trim().toLowerCase();
    return all.where((item) {
      if (q.isNotEmpty) {
        final inNum    = item.quote.number.toLowerCase().contains(q);
        final inClient = item.clientName?.toLowerCase().contains(q) ?? false;
        if (!inNum && !inClient) return false;
      }
      if (_statusFilter != null && item.quote.status != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<AppTableGroup<QuoteWithClient>> _buildGroups(
      List<QuoteWithClient> quotes) {
    final sorted = List<QuoteWithClient>.from(quotes);
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
    return [AppTableGroup(label: 'Quotes', items: sorted)];
  }

  // ── Column management ────────────────────────────────────────────────────────

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

  // ── Quote actions ────────────────────────────────────────────────────────────

  Future<void> _newQuote() async {
    final orgId = await ref.read(currentOrgIdProvider.future) ?? '';
    if (!mounted) return;
    final result = await showQuoteForm(
      context,
      initial: QuoteInput(orgId: orgId, lines: const []),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(quotesProvider.notifier).create(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quote: $e')),
        );
      }
    }
  }

  Future<void> _editQuote(QuoteWithClient item) async {
    if (!mounted) return;
    final result = await showQuoteForm(
      context,
      initial: item.quote.toInput(),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(quotesProvider.notifier).updateQuote(item.quote.id, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quote: $e')),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesProvider);
    final isWide      = MediaQuery.sizeOf(context).width >= _kSplitBreak;
    final ext         = context.linearExt;

    return SalesCommands(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearViewHeader(
            icon:  Icons.request_quote_outlined,
            title: 'Quotes',
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
                onPressed: () => ref.read(quotesProvider.notifier).refresh(),
              ),
              SizedBox(
                height: 16, width: 1,
                child: ColoredBox(color: ext.borderBase),
              ),
              LinearNewButton(
                label:     'New quote',
                onPressed: _newQuote,
              ),
            ],
          ),
          Expanded(
            child: quotesAsync.when(
              loading: () => const _Skeleton(),
              error:   (e, _) => _ErrorState(e.toString()),
              data:    (all) {
                if (all.isEmpty) {
                  return AppEmptyState(
                    icon:        Icons.request_quote_outlined,
                    title:       'No quotes yet',
                    description: 'Create your first quote with the button above.',
                    action: AppButton(
                      label:     'New quote',
                      variant:   AppButtonVariant.filled,
                      icon:      Icons.add,
                      onPressed: _newQuote,
                    ),
                  );
                }
                final filtered = _filter(all);
                return _buildBody(filtered, isWide);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<QuoteWithClient> quotes, bool isWide) {
    final selected =
        quotes.where((q) => q.quote.id == _selectedId).firstOrNull;

    if (selected == null && _selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) setState(() => _selectedId = null); });
    }

    if (quotes.isEmpty) {
      return Center(
        child: Text(
          'No quotes match the filter.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.linearExt.textMuted),
        ),
      );
    }

    final table = _buildTable(quotes);

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
          child: QuoteDetailPane(
            item:    selected,
            onClose: () => setState(() => _selectedId = null),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<QuoteWithClient> quotes) {
    // ── Trailing: actions column ("..." menu, future buttons go here) ──────────
    final actionsCol = AppColumnDef<QuoteWithClient>(
      id:            'actions',
      label:         '',
      width:         36,
      alwaysVisible: true,
      builder: (ctx, item, _) => _QuoteActionsMenu(
        item:   item,
        onEdit: () => _editQuote(item),
        // Add more callbacks here as new actions are introduced.
      ),
    );

    return AppDataTable<QuoteWithClient>(
      groups:          _buildGroups(quotes),
      columns:         [for (final c in _columns) _toAppDef(c)],
      trailingColumns: [actionsCol],
      leadingBuilder:  (_, _) => const SizedBox.shrink(),
      leadingWidth:    0,
      itemKey:         (q) => q.quote.id,
      onTap:           (q) => setState(() =>
          _selectedId = q.quote.id == _selectedId ? null : q.quote.id),
      selectedKey:     _selectedId,
      sortColumnId:    _sortColId,
      sortAscending:   _sortAsc,
      onSortChanged:   _onSortChanged,
      onColumnsReorder: _reorderColumns,
      onColumnResize:  _resizeColumn,
      onHideColumn:    _hideColumn,
      onColumnAutoFit: _autoFitColumn,
      // trailingColumns are not resizable — omit onTrailingColumnResize.
    );
  }
}

// ── Actions menu ───────────────────────────────────────────────────────────────

enum _QuoteAction { edit }

class _QuoteActionsMenu extends StatefulWidget {
  const _QuoteActionsMenu({
    required this.item,
    required this.onEdit,
  });

  final QuoteWithClient item;
  final VoidCallback    onEdit;
  // Add more VoidCallback fields here as new actions land (onDuplicate, onDelete, …).

  @override
  State<_QuoteActionsMenu> createState() => _QuoteActionsMenuState();
}

class _QuoteActionsMenuState extends State<_QuoteActionsMenu> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: PopupMenuButton<_QuoteAction>(
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
            value:  _QuoteAction.edit,
            height: 32,
            child:  Text('Edit',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          // Future actions: Duplicate, Convert to invoice, Delete, …
        ],
        onSelected: (action) {
          switch (action) {
            case _QuoteAction.edit:
              widget.onEdit();
          }
        },
      ),
    );
  }
}

// ── Status filter button ───────────────────────────────────────────────────────

// Sentinel to distinguish "All statuses selected" from "menu dismissed" —
// PopupMenuButton never calls onSelected when value is null.
const _kAllStatuses = Object();

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({required this.current, required this.onChanged});
  final QuoteStatus?               current;
  final ValueChanged<QuoteStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext    = context.linearExt;
    final text   = Theme.of(context).textTheme;
    final active = current != null;

    return PopupMenuButton<Object>(
      tooltip:     'Filter by status',
      padding:     EdgeInsets.zero,
      offset:      const Offset(0, 36),
      constraints: const BoxConstraints(minWidth: 160),
      itemBuilder: (_) => [
        PopupMenuItem<Object>(
          value:  _kAllStatuses,
          height: 32,
          child:  Text('All statuses',
              style: text.bodySmall?.copyWith(
                  color: current == null ? ext.textPrimary : ext.textMuted)),
        ),
        const PopupMenuDivider(height: 1),
        ...QuoteStatus.values.map(
          (s) => PopupMenuItem<Object>(
            value:  s,
            height: 32,
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration:
                      BoxDecoration(color: s.color, shape: BoxShape.circle),
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
      onSelected: (v) => onChanged(v == _kAllStatuses ? null : v as QuoteStatus),
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

    return Semantics(
      label:     'Search quotes and clients',
      textField: true,
      child: AnimatedContainer(
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
            hintText:  'Search quotes, clients…',
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
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────────────

class _QuoteStatusPill extends StatelessWidget {
  const _QuoteStatusPill({required this.status});
  final QuoteStatus status;

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
            Text('Failed to load quotes',
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
