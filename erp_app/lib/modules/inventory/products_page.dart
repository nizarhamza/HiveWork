import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/view_prefs_service.dart';
import '../../core/utils/formatting.dart';
import '../../data/models/product.dart';
import '../../data/providers/products_provider.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_data_table.dart';
import 'product_detail_pane.dart';
import 'product_form_dialog.dart';

const double _kSplitBreak   = 840.0;
const double _kListWidth    = 340.0;
const double _kListWidthMin = 200.0;
const double _kListWidthMax = 520.0;

// ── Filter ─────────────────────────────────────────────────────────────────────

class _ProductFilter {
  const _ProductFilter({this.searchText = '', this.lowStockOnly = false});

  final String searchText;
  final bool   lowStockOnly;

  bool get isActive => searchText.isNotEmpty || lowStockOnly;

  List<Product> apply(List<Product> products) {
    final q = searchText.trim().toLowerCase();
    return products.where((p) {
      if (q.isNotEmpty) {
        final inSpec     = p.specification?.toLowerCase().contains(q) ?? false;
        final inBrand    = p.brand?.toLowerCase().contains(q)         ?? false;
        final inCategory = p.category?.toLowerCase().contains(q)      ?? false;
        final inSku      = p.sku?.toLowerCase().contains(q)           ?? false;
        final inDesc     = p.description?.toLowerCase().contains(q)   ?? false;
        if (!inSpec && !inBrand && !inCategory && !inSku && !inDesc) return false;
      }
      if (lowStockOnly && !p.isLowStock) return false;
      return true;
    }).toList();
  }

  _ProductFilter withSearch(String v) =>
      _ProductFilter(searchText: v, lowStockOnly: lowStockOnly);

  _ProductFilter withLowStockOnly(bool v) =>
      _ProductFilter(searchText: searchText, lowStockOnly: v);
}

// ── Column definitions ─────────────────────────────────────────────────────────

enum _ColId { category, brand, specification, name, sku, unitPrice, stockQty, supplier, taxRate, unit, created }

class _ColDef {
  const _ColDef({
    required this.id,
    required this.label,
    required this.width,
    this.visible       = true,
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
  _ColDef(id: _ColId.category,      label: 'Category',      width: 130),
  _ColDef(id: _ColId.brand,         label: 'Brand',         width: 120),
  _ColDef(id: _ColId.specification, label: 'Specification', width: 140),
  _ColDef(id: _ColId.name,          label: 'Label',         width: 200, alwaysVisible: true),
  _ColDef(id: _ColId.sku,           label: 'SKU',           width: 120),
  _ColDef(id: _ColId.unitPrice,     label: 'Unit price',    width: 100),
  _ColDef(id: _ColId.stockQty,      label: 'Stock',         width: 110),
  _ColDef(id: _ColId.supplier,      label: 'Supplier',      width: 160),
  _ColDef(id: _ColId.taxRate,       label: 'Tax %',         width: 70,  visible: false),
  _ColDef(id: _ColId.unit,          label: 'Unit',          width: 70,  visible: false),
  _ColDef(id: _ColId.created,       label: 'Created',       width: 100, visible: false),
];

Widget _buildCell(_ColId id, Product p, BuildContext ctx, bool selected) {
  final ext  = ctx.linearExt;
  final text = Theme.of(ctx).textTheme;
  switch (id) {
    case _ColId.category:
      return Text(p.category ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.brand:
      return Text(p.brand ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.specification:
      return Text(p.specification ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.name:
      return Text(
        p.name,
        style: text.bodySmall?.copyWith(
          color:      ext.textPrimary,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      );
    case _ColId.sku:
      return Text(p.sku ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.unitPrice:
      return Text(fmtPrice(p.unitPrice),
          style: text.bodySmall?.copyWith(color: ext.textPrimary),
          overflow: TextOverflow.ellipsis);
    case _ColId.stockQty:
      return _StockBadge(product: p);
    case _ColId.supplier:
      return Text(p.supplierName ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.taxRate:
      return Text('${p.taxRate.toStringAsFixed(0)}%',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.unit:
      return Text(p.unit ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.created:
      return Text(_fmtDate(p.createdAt),
          style: text.bodySmall?.copyWith(color: ext.textMuted),
          overflow: TextOverflow.ellipsis);
  }
}

Comparable? Function(Product)? _sortKey(_ColId id) => switch (id) {
  _ColId.category      => (p) => p.category?.toLowerCase(),
  _ColId.brand         => (p) => p.brand?.toLowerCase(),
  _ColId.specification => (p) => p.specification?.toLowerCase(),
  _ColId.name          => (p) => p.name.toLowerCase(),
  _ColId.sku       => (p) => p.sku?.toLowerCase(),
  _ColId.unitPrice => (p) => p.unitPrice,
  _ColId.stockQty  => (p) => p.stockQuantity,
  _ColId.supplier  => (p) => p.supplierName?.toLowerCase(),
  _ColId.created   => (p) => p.createdAt.millisecondsSinceEpoch,
  _                => null,
};

String? _productFitValue(_ColId id, Product p) => switch (id) {
  _ColId.name          => p.name,
  _ColId.sku           => p.sku,
  _ColId.category      => p.category,
  _ColId.brand         => p.brand,
  _ColId.specification => p.specification,
  _ColId.unitPrice     => p.unitPrice.toStringAsFixed(2),
  _ColId.stockQty      => p.stockQuantity.toString(),
  _ColId.supplier      => p.supplierName,
  _ColId.taxRate       => '${p.taxRate.toStringAsFixed(0)}%',
  _ColId.unit          => p.unit,
  _ColId.created       => null,
};

AppColumnDef<Product> _toDef(_ColDef col) => AppColumnDef<Product>(
  id:          col.id.name,
  label:       col.label,
  width:       col.width,
  visible:     col.visible,
  alwaysVisible: col.alwaysVisible,
  flex:        col.id == _ColId.name,
  sortKey:     _sortKey(col.id),
  valueForFit: (p) => _productFitValue(col.id, p),
  builder:     (ctx, p, sel) => _buildCell(col.id, p, ctx, sel),
);

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}


// ── Prefs ──────────────────────────────────────────────────────────────────────

class _Prefs {
  static const _listWidthKey = 'products.listWidth';
  static const _visibleCols  = 'products.visibleColumns';
  static const _colWidths    = 'products.colWidths';
  static const _sortColKey   = 'products.sortCol';
  static const _sortAscKey   = 'products.sortAsc';
  static const _lowStockOnly = 'products.filter.lowStockOnly';

  static Future<void> saveListWidth(double v) =>
      ViewPrefsService.setDouble(_listWidthKey, v);

  static Future<void> saveColumns(List<_ColDef> cols) =>
      ViewPrefsService.setStringList(
          _visibleCols, [for (final c in cols) if (c.visible) c.id.name]);

  static Future<void> saveColumnWidths(List<_ColDef> cols) =>
      ViewPrefsService.setStringList(
          _colWidths, [for (final c in cols) '${c.id.name}:${c.width}']);

  static Future<void> saveSort(String? colId, bool asc) async {
    if (colId == null) {
      await ViewPrefsService.removeKey(_sortColKey);
    } else {
      await ViewPrefsService.setString(_sortColKey, colId);
    }
    await ViewPrefsService.setBoolOrNull(_sortAscKey, asc);
  }

  static Future<({
    double listWidth,
    List<_ColDef> columns,
    String? sortColId,
    bool sortAscending,
    bool lowStockOnly,
  })> load() async {
    final listWidth = await ViewPrefsService.getDouble(_listWidthKey, _kListWidth);

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
      final widthMap = <String, double>{};
      for (final entry in savedWidths) {
        final i = entry.indexOf(':');
        if (i > 0) {
          final w = double.tryParse(entry.substring(i + 1));
          if (w != null) widthMap[entry.substring(0, i)] = w;
        }
      }
      cols = [
        for (final c in cols)
          widthMap.containsKey(c.id.name) ? c.copyWith(width: widthMap[c.id.name]!) : c,
      ];
    }

    return (
      listWidth:     listWidth,
      columns:       cols,
      sortColId:     await ViewPrefsService.getString(_sortColKey),
      sortAscending: await ViewPrefsService.getBoolOrNull(_sortAscKey) ?? true,
      lowStockOnly:  await ViewPrefsService.getBoolOrNull(_lowStockOnly) ?? false,
    );
  }
}

// ── Page ───────────────────────────────────────────────────────────────────────

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String?       _selectedId;
  double        _listWidth   = _kListWidth;
  List<_ColDef> _columns     = _kDefaultColumns;
  _ProductFilter _filter     = const _ProductFilter();
  String?       _sortColId;
  bool          _sortAsc     = true;
  Timer?        _saveWidthTimer;
  Timer?        _saveColWidthTimer;

  @override
  void initState() {
    super.initState();
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
      _filter    = _filter.withLowStockOnly(p.lowStockOnly);
    });
  }

  void _select(String? id) => setState(() => _selectedId = id);

  void _toggleColumn(_ColId id) {
    setState(() {
      _columns = [
        for (final c in _columns)
          if (c.id == id) c.copyWith(visible: !c.visible) else c,
      ];
    });
    _Prefs.saveColumns(_columns);
  }

  void _reorderColumns(int from, int to) {
    final visible = _columns.where((c) => c.visible).toList();
    final hidden  = _columns.where((c) => !c.visible).toList();
    final col     = visible.removeAt(from);
    visible.insert(to, col);
    setState(() => _columns = [...visible, ...hidden]);
    _Prefs.saveColumns(_columns);
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

  void _onSortChanged(String colId) {
    setState(() {
      if (_sortColId == colId) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColId = colId;
        _sortAsc   = true;
      }
    });
    _Prefs.saveSort(_sortColId, _sortAsc);
  }

  Product? _findSelected(List<Product> products) {
    if (_selectedId == null) return null;
    for (final p in products) {
      if (p.id == _selectedId) return p;
    }
    return null;
  }

  List<AppTableGroup<Product>> _buildGroups(List<Product> products) {
    final sorted = List<Product>.from(products);
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
    } else {
      // Default: category ASC NULLS LAST → brand ASC NULLS LAST → specification ASC NULLS LAST
      sorted.sort((a, b) {
        int cmp = _nullLast(a.category?.toLowerCase(), b.category?.toLowerCase());
        if (cmp != 0) return cmp;
        cmp = _nullLast(a.brand?.toLowerCase(), b.brand?.toLowerCase());
        if (cmp != 0) return cmp;
        return _nullLast(a.specification?.toLowerCase(), b.specification?.toLowerCase());
      });
    }
    return [AppTableGroup(label: 'Products', items: sorted)];
  }

  static int _nullLast(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  void _openFilterPanel() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _FilterDialog(
        filter:    _filter,
        onChanged: (f) => setState(() => _filter = f),
      ),
    );
  }

  void _openDisplayPanel() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _ColumnPickerDialog(
        columns:  _columns,
        onToggle: _toggleColumn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _kSplitBreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearViewHeader(
          icon:  Icons.category_outlined,
          title: 'Products',
          actions: [
            _FilterButton(
              isActive: _filter.isActive,
              onTap:    _openFilterPanel,
            ),
            LinearGhostButton(
              icon:  Icons.view_column_outlined,
              label: 'Display',
              onTap: _openDisplayPanel,
            ),
            LinearNewButton(
              label: 'New product',
              onPressed: () => showProductForm(context),
            ),
          ],
        ),
        Expanded(
          child: productsAsync.when(
            loading: () => ListView.builder(
              itemCount:   8,
              itemBuilder: (_, _) => const AppContactRowSkeleton(),
            ),
            error: (e, _) => _ErrorState(message: e.toString()),
            data:  (products) => _buildBody(products, isWide),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<Product> products, bool isWide) {
    final filtered = _filter.apply(products);
    final selected = _findSelected(products);

    if (_selectedId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedId = null);
      });
    }

    if (isWide && selected != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _listWidth,
            child: _ProductList(
              products:   filtered,
              selectedId: _selectedId,
              onSelect:   _select,
            ),
          ),
          ResizablePaneDivider(
            onDrag: (delta) {
              setState(() {
                _listWidth =
                    (_listWidth + delta).clamp(_kListWidthMin, _kListWidthMax);
              });
              _saveWidthTimer?.cancel();
              _saveWidthTimer = Timer(const Duration(milliseconds: 400), () {
                _Prefs.saveListWidth(_listWidth);
              });
            },
          ),
          Expanded(
            child: ProductDetailPane(
              product: selected,
              onClose: () => _select(null),
            ),
          ),
        ],
      );
    }

    if (selected != null) {
      return ProductDetailPane(product: selected, onClose: () => _select(null));
    }

    if (filtered.isEmpty) {
      return AppEmptyState(
        icon:        Icons.category_outlined,
        title:       _filter.isActive
            ? 'No products match your filters'
            : 'No products yet',
        description: _filter.isActive
            ? 'Try adjusting or clearing your filters.'
            : 'Add your first product to start building the catalog.',
      );
    }

    return AppDataTable<Product>(
      groups:        _buildGroups(filtered),
      columns:       [for (final c in _columns) _toDef(c)],
      leadingBuilder: (ctx, p) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProductAvatar(product: p, size: 20),
          const SizedBox(width: LinearSpacing.md),
        ],
      ),
      itemKey:          (p) => p.id,
      onTap:            (p) => _select(p.id),
      selectedKey:      _selectedId,
      sortColumnId:     _sortColId,
      sortAscending:    _sortAsc,
      onSortChanged:    _onSortChanged,
      onColumnsReorder: _reorderColumns,
      onColumnResize:   _resizeColumn,
      onHideColumn:     _hideColumn,
      onColumnAutoFit:  _autoFitColumn,
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

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
            Text('Could not load products',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: LinearSpacing.xs),
            Text(message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ── Filter button ──────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.isActive, required this.onTap});
  final bool         isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LinearGhostButton(
          icon:  Icons.filter_list,
          label: isActive ? 'Filter (on)' : 'Filter',
          onTap: onTap,
        ),
        if (isActive)
          PositionedDirectional(
            top: 5, end: 5,
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: LinearColors.accent, shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Filter dialog ──────────────────────────────────────────────────────────────

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.filter, required this.onChanged});
  final _ProductFilter                filter;
  final ValueChanged<_ProductFilter>  onChanged;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late _ProductFilter      _local;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _local      = widget.filter;
    _searchCtrl = TextEditingController(text: widget.filter.searchText);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _update(_ProductFilter f) {
    setState(() => _local = f);
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 52, end: 190),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              color:        ext.surfaceRaised,
              borderRadius: BorderRadius.circular(LinearRadii.md),
              border:       Border.all(color: ext.borderSubtle),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LinearSpacing.base, LinearSpacing.sm,
                    LinearSpacing.base, LinearSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text('Filter', style: text.labelMedium?.copyWith(color: ext.textMuted)),
                      const Spacer(),
                      if (_local.isActive)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _update(const _ProductFilter());
                          },
                          child: Text('Clear all',
                              style: text.labelSmall?.copyWith(color: LinearColors.accent)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LinearSpacing.sm, LinearSpacing.sm, LinearSpacing.sm, LinearSpacing.xs,
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus:  true,
                    style:      text.bodySmall?.copyWith(color: ext.textPrimary),
                    decoration: InputDecoration(
                      hintText:  'Name, SKU, description…',
                      hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                      prefixIcon: Icon(Icons.search, size: 14, color: ext.textMuted),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
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
                    onChanged: (v) => _update(_local.withSearch(v)),
                  ),
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: () => _update(_local.withLowStockOnly(!_local.lowStockOnly)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LinearSpacing.base,
                      vertical:   LinearSpacing.sm - 2,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: Checkbox(
                            value:   _local.lowStockOnly,
                            onChanged: (_) => _update(_local.withLowStockOnly(!_local.lowStockOnly)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: LinearSpacing.sm),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: LinearColors.warning, shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: LinearSpacing.xs),
                        Text('Low stock only',
                            style: text.bodySmall?.copyWith(color: ext.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LinearSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Column picker dialog ───────────────────────────────────────────────────────

class _ColumnPickerDialog extends StatefulWidget {
  const _ColumnPickerDialog({required this.columns, required this.onToggle});
  final List<_ColDef>         columns;
  final void Function(_ColId) onToggle;

  @override
  State<_ColumnPickerDialog> createState() => _ColumnPickerDialogState();
}

class _ColumnPickerDialogState extends State<_ColumnPickerDialog> {
  late List<_ColDef> _local;

  @override
  void initState() {
    super.initState();
    _local = List.of(widget.columns);
  }

  void _toggle(_ColId id) {
    setState(() {
      _local = [
        for (final c in _local)
          if (c.id == id) c.copyWith(visible: !c.visible) else c,
      ];
    });
    widget.onToggle(id);
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 52, end: LinearSpacing.base),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 210,
            decoration: BoxDecoration(
              color:        ext.surfaceRaised,
              borderRadius: BorderRadius.circular(LinearRadii.md),
              border:       Border.all(color: ext.borderSubtle),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LinearSpacing.base, LinearSpacing.sm,
                    LinearSpacing.base, LinearSpacing.xs,
                  ),
                  child: Text('Columns',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: ext.textMuted)),
                ),
                const Divider(height: 1),
                for (final col in _local)
                  InkWell(
                    onTap: col.alwaysVisible ? null : () => _toggle(col.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LinearSpacing.base,
                        vertical:   LinearSpacing.sm - 2,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: Checkbox(
                              value:    col.visible,
                              onChanged: col.alwaysVisible ? null : (_) => _toggle(col.id),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: LinearSpacing.sm),
                          Text(
                            col.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: col.alwaysVisible ? ext.textMuted : ext.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: LinearSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact list (split-pane left rail) ───────────────────────────────────────

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.onSelect,
    this.selectedId,
  });

  final List<Product>         products;
  final String?               selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount:   products.length,
      itemBuilder: (ctx, i) => _ProductRow(
        product:  products[i],
        selected: products[i].id == selectedId,
        onTap:    () => onSelect(products[i].id),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onTap,
    this.selected = false,
  });

  final Product      product;
  final VoidCallback onTap;
  final bool         selected;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? ext.overlayActive : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          overlayColor: WidgetStatePropertyAll(ext.overlay),
          child: Container(
            height:  40,
            padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ext.borderSubtle)),
              color:  selected
                  ? LinearColors.accent.withValues(alpha: 0.06)
                  : null,
            ),
            child: Row(
              children: [
                _ProductAvatar(product: product, size: 20),
                const SizedBox(width: LinearSpacing.md),
                Expanded(
                  child: Text(
                    product.name,
                    style: text.bodySmall?.copyWith(
                      color:      ext.textPrimary,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StockBadge(product: product),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.product, this.size = 28});
  final Product product;
  final double  size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color:        product.avatarColor,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: Text(
        product.initials,
        style: TextStyle(
          color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final ext   = context.linearExt;
    final text  = Theme.of(context).textTheme;
    final isLow = product.isLowStock;
    final color = isLow ? LinearColors.warning : ext.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLow) ...[
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: LinearColors.warning, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: LinearSpacing.xs),
        ],
        Text(
          '${product.stockQuantity}',
          style: text.bodySmall?.copyWith(
            color:      color,
            fontWeight: isLow ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        if (product.unit != null)
          Text(' ${product.unit}',
              style: text.labelSmall?.copyWith(color: ext.textMuted)),
      ],
    );
  }
}
