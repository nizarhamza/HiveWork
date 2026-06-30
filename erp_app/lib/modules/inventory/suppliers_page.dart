import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/supplier.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_data_table.dart';
import '../../ui/organisms/app_dialog.dart';
import 'supplier_form_dialog.dart';

// ── Column definitions ─────────────────────────────────────────────────────────

enum _ColId { name, taxId, currency, paymentTerms, created }

class _ColDef {
  const _ColDef({
    required this.id,
    required this.label,
    required this.width,
    this.visible      = true,
    this.alwaysVisible = false,
  });

  final _ColId id;
  final String  label;
  final double  width;
  final bool    visible;
  final bool    alwaysVisible;

  _ColDef copyWith({bool? visible, double? width}) => _ColDef(
        id: id, label: label, width: width ?? this.width,
        visible: visible ?? this.visible,
        alwaysVisible: alwaysVisible,
      );
}

const _kDefaultColumns = <_ColDef>[
  _ColDef(id: _ColId.name,         label: 'Name',          width: 220, alwaysVisible: true),
  _ColDef(id: _ColId.taxId,        label: 'Tax ID',        width: 140),
  _ColDef(id: _ColId.currency,     label: 'Currency',      width: 100),
  _ColDef(id: _ColId.paymentTerms, label: 'Payment terms', width: 160),
  _ColDef(id: _ColId.created,      label: 'Created',       width: 100, visible: false),
];

Widget _buildCell(_ColId id, Supplier s, BuildContext ctx, bool selected) {
  final ext  = ctx.linearExt;
  final text = Theme.of(ctx).textTheme;
  switch (id) {
    case _ColId.name:
      return Text(
        s.name,
        style: text.bodySmall?.copyWith(
          color:      ext.textPrimary,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      );
    case _ColId.taxId:
      return Text(s.taxId ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.currency:
      return Text(s.currency ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.paymentTerms:
      return Text(s.paymentTerms ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.created:
      return Text(_fmtDate(s.createdAt),
          style: text.bodySmall?.copyWith(color: ext.textMuted),
          overflow: TextOverflow.ellipsis);
  }
}

Comparable? Function(Supplier)? _sortKey(_ColId id) => switch (id) {
  _ColId.name         => (s) => s.name.toLowerCase(),
  _ColId.taxId        => (s) => s.taxId?.toLowerCase(),
  _ColId.currency     => (s) => s.currency?.toLowerCase(),
  _ColId.paymentTerms => (s) => s.paymentTerms?.toLowerCase(),
  _ColId.created      => (s) => s.createdAt.millisecondsSinceEpoch,
};

String? _supplierFitValue(_ColId id, Supplier s) => switch (id) {
  _ColId.name         => s.name,
  _ColId.taxId        => s.taxId,
  _ColId.currency     => s.currency,
  _ColId.paymentTerms => s.paymentTerms,
  _ColId.created      => null,
};

AppColumnDef<Supplier> _toDef(_ColDef col) => AppColumnDef<Supplier>(
  id:          col.id.name,
  label:       col.label,
  width:       col.width,
  visible:     col.visible,
  alwaysVisible: col.alwaysVisible,
  flex:        col.id == _ColId.name,
  sortKey:     _sortKey(col.id),
  valueForFit: (s) => _supplierFitValue(col.id, s),
  builder:     (ctx, s, sel) => _buildCell(col.id, s, ctx, sel),
);

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ── Page ───────────────────────────────────────────────────────────────────────

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  String  _search   = '';
  String? _sortColId;
  bool    _sortAsc  = true;
  List<_ColDef> _columns = _kDefaultColumns;

  void _resizeColumn(int visibleIndex, double delta) {
    final visible = _columns.where((c) => c.visible).toList();
    if (visibleIndex >= visible.length) return;
    final col = visible[visibleIndex];
    final newW = (col.width + delta).clamp(40.0, double.infinity);
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id == col.id ? c.copyWith(width: newW) : c,
      ];
    });
  }

  void _hideColumn(String columnId) {
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id.name == columnId ? c.copyWith(visible: false) : c,
      ];
    });
  }

  void _autoFitColumn(String columnId, double width) {
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id.name == columnId ? c.copyWith(width: width) : c,
      ];
    });
  }

  List<Supplier> _filter(List<Supplier> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.taxId?.toLowerCase().contains(q) ?? false) ||
            (s.currency?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<AppTableGroup<Supplier>> _buildGroups(List<Supplier> suppliers) {
    final sorted = List<Supplier>.from(suppliers);
    if (_sortColId != null) {
      try {
        final colId = _ColId.values.byName(_sortColId!);
        final key   = _sortKey(colId);
        if (key != null) {
          sorted.sort((a, b) {
            final ka = key(a), kb = key(b);
            if (ka == null && kb == null) return 0;
            if (ka == null) return _sortAsc ? 1 : -1;
            if (kb == null) return _sortAsc ? -1 : 1;
            return _sortAsc ? ka.compareTo(kb) : kb.compareTo(ka);
          });
        }
      } catch (_) {}
    }
    return [AppTableGroup(label: 'Suppliers', items: sorted)];
  }

  Future<void> _confirmDelete(Supplier s) async {
    final confirmed = await AppDialog.confirm(
      context,
      title:        'Delete ${s.name}?',
      message:      'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive:  true,
    );
    if (confirmed) {
      await ref.read(suppliersProvider.notifier).delete(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final ext = context.linearExt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearViewHeader(
          icon:  Icons.local_shipping_outlined,
          title: 'Suppliers',
          actions: [
            SizedBox(
              width: 200,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search…',
                  hintStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ext.textMuted),
                  prefixIcon: Icon(Icons.search, size: 14, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm, vertical: LinearSpacing.sm,
                  ),
                  filled:      true,
                  fillColor:   ext.surfaceBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide:   BorderSide(color: ext.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide:   BorderSide(color: ext.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide: const BorderSide(color: LinearColors.accent),
                  ),
                ),
              ),
            ),
            LinearNewButton(
              label: 'New supplier',
              onPressed: () => showSupplierForm(context),
            ),
          ],
        ),
        Expanded(
          child: suppliersAsync.when(
            loading: () => ListView.builder(
              itemCount:   6,
              itemBuilder: (_, _) => const AppContactRowSkeleton(),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: LinearColors.danger, size: 32),
                  const SizedBox(height: LinearSpacing.sm),
                  Text('Could not load suppliers',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: LinearSpacing.xs),
                  Text(e.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            data: (suppliers) {
              final filtered = _filter(suppliers);
              if (filtered.isEmpty) {
                return AppEmptyState(
                  icon:        Icons.local_shipping_outlined,
                  title:       _search.isNotEmpty
                      ? 'No suppliers match your search'
                      : 'No suppliers yet',
                  description: _search.isNotEmpty
                      ? 'Try a different search term.'
                      : 'Add your first supplier to link products to them.',
                );
              }
              return AppDataTable<Supplier>(
                groups:        _buildGroups(filtered),
                columns:       [for (final c in _columns) _toDef(c)],
                itemKey:       (s) => s.id,
                sortColumnId:  _sortColId,
                sortAscending: _sortAsc,
                onSortChanged: (id) => setState(() {
                  if (_sortColId == id) {
                    _sortAsc = !_sortAsc;
                  } else {
                    _sortColId = id;
                    _sortAsc   = true;
                  }
                }),
                onTap: (s) => showSupplierForm(context, supplier: s),
                onColumnResize:  _resizeColumn,
                onHideColumn:    _hideColumn,
                onColumnAutoFit: _autoFitColumn,
                leadingBuilder: (ctx, s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Avatar(supplier: s),
                    const SizedBox(width: LinearSpacing.md),
                  ],
                ),
                trailingColumns: [
                  AppColumnDef<Supplier>(
                    id:      'actions',
                    label:   '',
                    width:   40,
                    builder: (ctx, s, _) => _ActionMenu(
                      onEdit:   () => showSupplierForm(ctx, supplier: s),
                      onDelete: () => _confirmDelete(s),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        color:        supplier.avatarColor,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        supplier.initials,
        style: const TextStyle(
          color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Row action menu ────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return PopupMenuButton<String>(
      tooltip:    '',
      padding:    EdgeInsets.zero,
      icon:       Icon(Icons.more_horiz, size: 14, color: ext.textMuted),
      iconSize:   14,
      constraints: const BoxConstraints(minWidth: 140),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          height: 32,
          child: Text('Edit',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ext.textPrimary)),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 32,
          child: Text('Delete',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: LinearColors.danger)),
        ),
      ],
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
    );
  }
}
