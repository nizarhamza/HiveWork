import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product.dart';
import '../../data/providers/products_provider.dart';
import '../../core/utils/formatting.dart';
import '../../theme/linear_tokens.dart';

/// Controls which filter UI is shown in the product picker.
enum ProductPickerFilter {
  none,       // plain search only (default)
  category,   // category chips → search → product list
  brandModel, // brand chips → model chips → search → product list
}

/// Opens a modal search-and-select dialog for picking a product.
/// Returns the selected [Product], or null if cancelled/cleared.
Future<({Product? product, bool cleared})> showProductPicker(
  BuildContext context, {
  String? currentProductId,
  ProductPickerFilter filter = ProductPickerFilter.none,
}) async {
  final result = await showDialog<({Product? product, bool cleared})>(
    context: context,
    builder: (_) => _ProductPickerDialog(
      currentProductId: currentProductId,
      filter: filter,
    ),
  );
  return result ?? (product: null, cleared: false);
}

class _ProductPickerDialog extends ConsumerStatefulWidget {
  const _ProductPickerDialog({
    this.currentProductId,
    this.filter = ProductPickerFilter.none,
  });
  final String? currentProductId;
  final ProductPickerFilter filter;

  @override
  ConsumerState<_ProductPickerDialog> createState() =>
      _ProductPickerDialogState();
}

class _ProductPickerDialogState extends ConsumerState<_ProductPickerDialog> {
  final _ctrl = TextEditingController();
  String  _query           = '';
  String? _selectedCategory;
  String? _selectedBrand;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Derived filter values ──────────────────────────────────────────────────

  List<String> _categories(List<Product> all) {
    final set = <String>{};
    for (final p in all) {
      if (p.category != null && p.category!.isNotEmpty) set.add(p.category!);
    }
    return set.toList()..sort();
  }

  List<String> _brands(List<Product> all) {
    final set = <String>{};
    for (final p in all) {
      if (p.brand != null && p.brand!.isNotEmpty) set.add(p.brand!);
    }
    return set.toList()..sort();
  }

  List<Product> _filter(List<Product> all) {
    var list = all;

    if (widget.filter == ProductPickerFilter.category &&
        _selectedCategory != null) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }

    if (widget.filter == ProductPickerFilter.brandModel) {
      if (_selectedBrand != null) {
        list = list.where((p) => p.brand == _selectedBrand).toList();
      }
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              (p.brand?.toLowerCase().contains(q)         ?? false) ||
              (p.specification?.toLowerCase().contains(q) ?? false) ||
              (p.sku?.toLowerCase().contains(q)           ?? false) ||
              (p.description?.toLowerCase().contains(q)   ?? false))
          .toList();
    }

    return list;
  }

  bool get _hasActiveFilter =>
      _selectedCategory != null ||
      _selectedBrand != null;

  @override
  Widget build(BuildContext context) {
    final ext           = context.linearExt;
    final text          = Theme.of(context).textTheme;
    final productsAsync = ref.watch(productsProvider);

    return Dialog(
      backgroundColor:  ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 64),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base, LinearSpacing.base,
                LinearSpacing.base, LinearSpacing.sm,
              ),
              child: Row(
                children: [
                  Text('Select product', style: text.titleSmall),
                  const Spacer(),
                  if (widget.currentProductId != null)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop((product: null, cleared: true)),
                      style: TextButton.styleFrom(
                          foregroundColor: LinearColors.danger),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),

            // ── Category chips ───────────────────────────────────────────────
            if (widget.filter == ProductPickerFilter.category)
              productsAsync.maybeWhen(
                data: (all) {
                  final cats = _categories(all);
                  if (cats.isEmpty) return const SizedBox.shrink();
                  return _ChipRow(
                    label: 'Category',
                    values: cats,
                    selected: _selectedCategory,
                    onSelect: (v) =>
                        setState(() => _selectedCategory = v),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

            // ── Brand chips ──────────────────────────────────────────────────
            if (widget.filter == ProductPickerFilter.brandModel)
              productsAsync.maybeWhen(
                data: (all) {
                  final brands = _brands(all);
                  if (brands.isEmpty) return const SizedBox.shrink();
                  return _ChipRow(
                    label:    'Brand',
                    values:   brands,
                    selected: _selectedBrand,
                    onSelect: (v) => setState(() => _selectedBrand = v),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

            // ── Search ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: LinearSpacing.base),
              child: TextField(
                controller: _ctrl,
                autofocus:  true,
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by brand, specification, SKU…',
                  hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                  prefixIcon:
                      Icon(Icons.search, size: 16, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm,
                    vertical:   LinearSpacing.sm,
                  ),
                  filled:    true,
                  fillColor: ext.surfaceBase,
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
                    borderSide:
                        const BorderSide(color: LinearColors.accent),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: LinearSpacing.sm),
            const Divider(height: 1),

            // ── Product list ─────────────────────────────────────────────────
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error loading products',
                      style:
                          text.bodySmall?.copyWith(color: ext.textMuted)),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty && !_hasActiveFilter
                            ? 'No products yet'
                            : 'No results',
                        style:
                            text.bodySmall?.copyWith(color: ext.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount:   filtered.length,
                    itemBuilder: (ctx, i) => _ProductTile(
                      product:  filtered[i],
                      selected: filtered[i].id == widget.currentProductId,
                      onTap:    () => Navigator.of(context)
                          .pop((product: filtered[i], cleared: false)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip row ────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelect,
  });

  final String             label;
  final List<String>       values;
  final String?            selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: LinearSpacing.base,
        end:   LinearSpacing.base,
        bottom: LinearSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            '$label:',
            style: text.labelSmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(width: LinearSpacing.xs),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label:    'All',
                    active:   selected == null,
                    onTap:    () => onSelect(null),
                  ),
                  for (final v in values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: LinearSpacing.xs),
                      child: _FilterChip(
                        label:  v,
                        active: selected == v,
                        onTap:  () => onSelect(selected == v ? null : v),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String       label;
  final bool         active;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: widget.active
                ? LinearColors.accent.withValues(alpha: 0.12)
                : _hovered
                    ? ext.overlay
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadii.pill),
            border: Border.all(
              color: widget.active
                  ? LinearColors.accent.withValues(alpha: 0.5)
                  : ext.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: text.labelSmall?.copyWith(
              color: widget.active
                  ? LinearColors.accent
                  : ext.textSecondary,
              fontWeight:
                  widget.active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Product tile ───────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final Product      product;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? LinearColors.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap:        onTap,
        overlayColor: WidgetStatePropertyAll(ext.overlay),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base,
            vertical:   LinearSpacing.sm,
          ),
          child: Row(
            children: [
              _ProductAvatar(product: product),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    // Row: Category · Brand badges
                    if (product.category != null || product.brand != null)
                      Row(
                        children: [
                          if (product.category != null)
                            _Badge(product.category!, color: ext.textMuted),
                          if (product.category != null && product.brand != null)
                            const SizedBox(width: 4),
                          if (product.brand != null)
                            _Badge(product.brand!, color: ext.textSecondary),
                        ],
                      ),
                    if (product.category != null || product.brand != null)
                      const SizedBox(height: 2),
                    // Specification (primary identifier)
                    Text(
                      product.specification ?? product.name,
                      style: text.bodySmall?.copyWith(
                        color:      ext.textPrimary,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.sku != null)
                      Text(product.sku!,
                          style: text.labelSmall?.copyWith(color: ext.textMuted),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(
                fmtPrice(product.unitPrice),
                style: text.bodySmall?.copyWith(
                  color:      ext.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              if (selected)
                const Icon(Icons.check, size: 16, color: LinearColors.accent)
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(LinearRadii.xs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:    color,
              fontSize: 9,
            ),
      ),
    );
  }
}

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color:        product.avatarColor,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        product.initials,
        style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
