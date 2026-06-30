import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_bundle.dart';
import '../../data/providers/product_bundle_provider.dart';
import '../../data/providers/products_provider.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_dialog.dart';
import '../../core/utils/formatting.dart';
import '../org/org_providers.dart';
import 'product_picker_dialog.dart';

// ── Children-table column widths ───────────────────────────────────────────────
const _kBColN     = 28.0;
const _kBColIcon  = 14.0;
const _kBColCat   = 120.0;
const _kBColBrand = 88.0;
const _kBColSku   = 80.0;
const _kBColUnit  = 50.0;
const _kBColQty   = 72.0;
const _kBColDrag  = 20.0;
const _kBColDel   = 22.0;
const _kBColGap   =  6.0;

// ── Page ───────────────────────────────────────────────────────────────────────

class BundlesPage extends ConsumerStatefulWidget {
  const BundlesPage({super.key});

  @override
  ConsumerState<BundlesPage> createState() => _BundlesPageState();
}

class _BundlesPageState extends ConsumerState<BundlesPage> {
  String _search     = '';
  bool   _activeOnly = true;

  Future<void> _openNew() async {
    await showDialog(
      context: context,
      builder: (_) => const _BundleFormDialog(),
    );
  }

  Future<void> _openEdit(ProductBundle bundle) async {
    await showDialog(
      context: context,
      builder: (_) => _BundleFormDialog(bundle: bundle),
    );
  }

  List<ProductBundle> _filter(List<ProductBundle> all) {
    final q = _search.trim().toLowerCase();
    return all.where((b) {
      if (_activeOnly && !b.isActive) return false;
      if (q.isNotEmpty && !b.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bundlesAsync = ref.watch(bundlesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearViewHeader(
          icon:  Icons.category_outlined,
          title: 'Bundles',
          actions: [
            _ActiveToggle(
              value:     _activeOnly,
              onChanged: (v) => setState(() => _activeOnly = v),
            ),
            LinearNewButton(
              label:     'New bundle',
              onPressed: _openNew,
            ),
          ],
        ),
        Expanded(
          child: bundlesAsync.when(
            loading: () => ListView.builder(
              itemCount:   6,
              itemBuilder: (_, _) => const AppContactRowSkeleton(),
            ),
            error: (e, _) => Center(
              child: Text('Could not load bundles: $e',
                  style: const TextStyle(color: LinearColors.danger)),
            ),
            data: (bundles) {
              final filtered = _filter(bundles);

              if (filtered.isEmpty) {
                return AppEmptyState(
                  icon:  Icons.category_outlined,
                  title: _search.isNotEmpty
                      ? 'No bundles match "$_search"'
                      : 'No bundles yet',
                  description: _search.isNotEmpty
                      ? 'Try a different search term.'
                      : 'Create a bundle to insert pre-defined groups of products into quotes.',
                );
              }

              return _BundleList(
                bundles:  filtered,
                search:   _search,
                onSearch: (v) => setState(() => _search = v),
                onSelect: _openEdit,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Active-only toggle ─────────────────────────────────────────────────────────

class _ActiveToggle extends StatelessWidget {
  const _ActiveToggle({required this.value, required this.onChanged});
  final bool               value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        value ? LinearColors.accent.withValues(alpha: 0.10) : ext.overlay,
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            border: Border.all(
              color: value ? LinearColors.accent.withValues(alpha: 0.30) : ext.borderSubtle,
            ),
          ),
          child: Text(
            'Active only',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: value ? LinearColors.accent : ext.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bundle list ────────────────────────────────────────────────────────────────

class _BundleList extends StatelessWidget {
  const _BundleList({
    required this.bundles,
    required this.search,
    required this.onSearch,
    required this.onSelect,
  });

  final List<ProductBundle>          bundles;
  final String                       search;
  final ValueChanged<String>         onSearch;
  final ValueChanged<ProductBundle>  onSelect;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LinearSpacing.base, LinearSpacing.sm,
            LinearSpacing.base, LinearSpacing.xs,
          ),
          child: TextField(
            controller: TextEditingController(text: search)
              ..selection = TextSelection.collapsed(offset: search.length),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ext.textPrimary),
            decoration: InputDecoration(
              hintText:  'Search bundles…',
              hintStyle: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ext.textMuted),
              prefixIcon: Icon(Icons.search, size: 14, color: ext.textMuted),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              isDense:        true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: LinearSpacing.sm, vertical: LinearSpacing.sm,
              ),
              filled:    true,
              fillColor: ext.surfaceBase,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                borderSide:   BorderSide(color: ext.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                borderSide: const BorderSide(color: LinearColors.accent),
              ),
            ),
            onChanged: onSearch,
          ),
        ),
        Divider(height: 1, color: ext.borderSubtle),
        Expanded(
          child: ListView.builder(
            itemCount:   bundles.length,
            itemBuilder: (ctx, i) => _BundleRow(
              bundle: bundles[i],
              onTap:  () => onSelect(bundles[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _BundleRow extends StatefulWidget {
  const _BundleRow({required this.bundle, required this.onTap});
  final ProductBundle bundle;
  final VoidCallback  onTap;

  @override
  State<_BundleRow> createState() => _BundleRowState();
}

class _BundleRowState extends State<_BundleRow> {
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
          duration: const Duration(milliseconds: 80),
          height:  44,
          color:   _hovered ? ext.overlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
          child: Row(
            children: [
              _BundleAvatar(bundle: widget.bundle),
              const SizedBox(width: LinearSpacing.sm),
              Expanded(
                child: Text(
                  widget.bundle.name,
                  style: text.bodySmall?.copyWith(color: ext.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Text(
                '${widget.bundle.lineCount}',
                style: text.labelSmall?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(width: LinearSpacing.xs),
              if (!widget.bundle.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color:        ext.overlayActive,
                    borderRadius: BorderRadius.circular(LinearRadii.pill),
                  ),
                  child: Text(
                    'Inactive',
                    style: text.labelSmall?.copyWith(color: ext.textMuted, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BundleAvatar extends StatelessWidget {
  const _BundleAvatar({required this.bundle});
  final ProductBundle bundle;
  static const double size = 24;

  @override
  Widget build(BuildContext context) {
    const palette = [
      Color(0xFF5E6AD2), Color(0xFF2BA87E), Color(0xFFD9730D),
      Color(0xFFC2554D), Color(0xFF9D5BD2), Color(0xFF3A87C2),
    ];
    final idx =
        bundle.name.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    final color = palette[idx];

    final words   = bundle.name.trim().split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : bundle.name.substring(0, bundle.name.length.clamp(0, 2)).toUpperCase();

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color:      color,
          fontSize:   size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Section label (matches quote form style) ───────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color:         context.linearExt.textMuted,
          letterSpacing: 0.8,
          fontWeight:    FontWeight.w600,
        ),
      );
}

// ── Line draft ─────────────────────────────────────────────────────────────────

class _LineDraft {
  _LineDraft({
    required this.type,
    required this.itemId,
    required this.displayName,
    this.category,
    this.brand,
    this.sku,
    this.unit,
    double qty = 1.0,
  }) : qtyCtrl = TextEditingController(
            text: qty == qty.truncateToDouble()
                ? qty.toInt().toString()
                : qty.toStringAsFixed(3));

  final String                type;        // 'product' | 'bundle'
  final String                itemId;
  final String                displayName;
  final String?               category;
  final String?               brand;
  final String?               sku;
  final String?               unit;
  final TextEditingController qtyCtrl;

  double get qty =>
      double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;

  void dispose() => qtyCtrl.dispose();

  ProductBundleLineInput toInput(int order) => ProductBundleLineInput(
        quantity:      qty,
        sortOrder:     order,
        productId:     type == 'product' ? itemId : null,
        childBundleId: type == 'bundle'  ? itemId : null,
      );
}

// ── Bundle form dialog ─────────────────────────────────────────────────────────

class _BundleFormDialog extends ConsumerStatefulWidget {
  const _BundleFormDialog({this.bundle});
  final ProductBundle? bundle;

  @override
  ConsumerState<_BundleFormDialog> createState() => _BundleFormDialogState();
}

class _BundleFormDialogState extends ConsumerState<_BundleFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _priceCtrl;
  late bool _isActive;
  late List<_LineDraft> _lines;
  String? _lastAutoCategory;

  bool    _saving       = false;
  bool    _deleting     = false;
  bool    _loadingLines = false;
  String? _error;

  bool get _isNew => widget.bundle == null;

  @override
  void initState() {
    super.initState();
    final b = widget.bundle;
    _nameCtrl     = TextEditingController(text: b?.name        ?? '');
    _descCtrl     = TextEditingController(text: b?.description ?? '');
    _categoryCtrl = TextEditingController(text: b?.category    ?? '');
    _priceCtrl    = TextEditingController(
      text: b?.priceOverride != null ? fmtPrice(b!.priceOverride!) : '',
    );
    _isActive = b?.isActive ?? true;
    _lines    = [];

    if (b != null) _loadLines(b.id);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }


  void _onCategoryChanged(String cat) {
    final trimmed = cat.trim();
    if (trimmed == _lastAutoCategory) return;
    _lastAutoCategory = trimmed;
    if (trimmed.isEmpty) return;

    final products = ref.read(productsProvider).value ?? [];
    final inCategory = products
        .where((p) => p.category?.toLowerCase() == trimmed.toLowerCase())
        .toList();
    if (inCategory.isEmpty) return;

    setState(() {
      for (final l in _lines) { l.dispose(); }
      _lines = inCategory
          .map((p) => _LineDraft(
                type:        'product',
                itemId:      p.id,
                displayName: p.displayLabel,
                category:    p.category,
                unit:        p.unit,
                // brand and SKU intentionally omitted when adding by category
              ))
          .toList();
    });
  }

  Future<void> _loadLines(String bundleId) async {
    setState(() => _loadingLines = true);
    try {
      final detail = await ref
          .read(productBundleRepositoryProvider)
          .fetchWithLines(bundleId);
      if (!mounted) return;
      final newLines = detail.lines.map((l) => _LineDraft(
            type:        l.isProduct ? 'product' : 'bundle',
            itemId:      (l.productId ?? l.childBundleId)!,
            displayName: l.displayName,
            category:    l.product?.category,
            brand:       l.product?.brand,
            sku:         l.product?.sku,
            unit:        l.product?.unit,
            qty:         l.quantity,
          )).toList();
      setState(() {
        for (final l in _lines) { l.dispose(); }
        _lines = newLines;
        _loadingLines = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLines = false);
    }
  }

  Future<void> _addProduct() async {
    final result = await showProductPicker(
      context,
      filter: ProductPickerFilter.category,
    );
    if (!mounted || result.product == null) return;
    final p = result.product!;
    setState(() {
      _lines.add(_LineDraft(
        type:        'product',
        itemId:      p.id,
        displayName: p.displayLabel,
        category:    p.category,
        brand:       p.brand,
        sku:         p.sku,
        unit:        p.unit,
      ));
    });
  }

  Future<void> _addCategory() async {
    final products = ref.read(productsProvider).value ?? [];
    final categories = products
        .map((p) => p.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    if (!mounted) return;
    if (categories.isEmpty) return;

    final picked = await _showCategoryPicker(context, categories);
    if (!mounted || picked == null) return;

    final toAdd = products
        .where((p) => p.category?.toLowerCase() == picked.toLowerCase())
        .toList();

    final alreadyAdded = _lines
        .where((l) => l.type == 'product')
        .map((l) => l.itemId)
        .toSet();

    setState(() {
      for (final p in toAdd) {
        if (!alreadyAdded.contains(p.id)) {
          _lines.add(_LineDraft(
            type:        'product',
            itemId:      p.id,
            displayName: p.displayLabel,
            category:    p.category,
            unit:        p.unit,
            // brand and SKU intentionally omitted when adding by category
          ));
        }
      }
    });
  }

  Future<void> _addBundle() async {
    final excludeId    = widget.bundle?.id;
    final alreadyAdded = _lines
        .where((l) => l.type == 'bundle')
        .map((l) => l.itemId)
        .toSet();

    final picked = await _showChildBundlePicker(
      context,
      ref,
      excludeId:   excludeId,
      excludedIds: alreadyAdded,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _lines.add(_LineDraft(
        type:        'bundle',
        itemId:      picked.id,
        displayName: picked.name,
      ));
    });
  }

  void _removeLine(int i) {
    setState(() {
      _lines.removeAt(i).dispose();
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Bundle name is required.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final orgId = await ref.read(currentOrgIdProvider.future);
      if (orgId == null) throw Exception('No organisation selected');

      final repo  = ref.read(productBundleRepositoryProvider);
      final notif = ref.read(bundlesProvider.notifier);
      final catText   = _categoryCtrl.text.trim();
      final priceText = _priceCtrl.text.trim().replaceAll(',', '.');
      final input = ProductBundleInput(
        orgId:         orgId,
        name:          name,
        description:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category:      catText.isEmpty ? null : catText,
        priceOverride: double.tryParse(priceText),
        isActive:      _isActive,
      );

      String bundleId;
      if (_isNew) {
        final created = await notif.create(input);
        bundleId = created.id;
      } else {
        await notif.updateBundle(widget.bundle!.id, input);
        bundleId = widget.bundle!.id;
      }

      final lineInputs = _lines
          .asMap()
          .entries
          .map((e) => e.value.toInput(e.key))
          .toList();
      await repo.replaceLines(bundleId, lineInputs);
      notif.updateLineCount(bundleId, lineInputs.length);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  Future<void> _delete() async {
    final confirmed = await AppDialog.confirm(
      context,
      title:        'Deactivate this bundle?',
      message:      'The bundle will be hidden from pickers. '
                    'Existing quote lines are not affected.',
      confirmLabel: 'Deactivate',
      destructive:  true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(bundlesProvider.notifier).softDelete(widget.bundle!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _deleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return AppDialog(
      title:  _isNew ? 'New bundle' : 'Edit bundle',
      width:  700,
      actions: [
        if (!_isNew)
          AppButton(
            label:     'Deactivate',
            variant:   AppButtonVariant.danger,
            size:      AppButtonSize.sm,
            loading:   _deleting,
            onPressed: _deleting ? null : _delete,
          ),
        AppButton(
          label:     'Cancel',
          variant:   AppButtonVariant.ghost,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label:     _isNew ? 'Create bundle' : 'Save changes',
          variant:   AppButtonVariant.filled,
          size:      AppButtonSize.lg,
          icon:      Icons.check_rounded,
          loading:   _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section: Bundle name + active ────────────────────────────────────
          const _SectionLabel('Bundle'),
          const SizedBox(height: LinearSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledField(
                  label:     'Name',
                  controller: _nameCtrl,
                  hint:      'e.g. Kit Solaire 3KW',
                  autofocus: _isNew,
                ),
              ),
              const SizedBox(width: LinearSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active',
                      style: text.labelSmall?.copyWith(color: ext.textMuted)),
                  const SizedBox(height: 4),
                  Transform.scale(
                    scale: 0.72,
                    alignment: Alignment.topLeft,
                    child: Switch(
                      value:            _isActive,
                      onChanged:        (v) => setState(() => _isActive = v),
                      activeThumbColor: LinearColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.lg),

          // ── Section: Details ─────────────────────────────────────────────────
          const _SectionLabel('Details'),
          const SizedBox(height: LinearSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledField(
                  label:     'Category',
                  controller: _categoryCtrl,
                  hint:      'e.g. Onduleur — auto-fills products',
                  onChanged: _onCategoryChanged,
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _LabeledField(
                  label:      'Description',
                  controller: _descCtrl,
                  hint:       'Optional description',
                  maxLines:   2,
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _LabeledField(
                  label:        'Unit price override',
                  controller:   _priceCtrl,
                  hint:         'Leave blank to sum product prices',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.lg),

          // ── Section: Children ────────────────────────────────────────────────
          Row(
            children: [
              const _SectionLabel('Children'),
              const Spacer(),
              _SmallButton(
                icon:  Icons.folder_outlined,
                label: 'Add category',
                onTap: _addCategory,
              ),
              const SizedBox(width: LinearSpacing.sm),
              _SmallButton(
                icon:  Icons.inventory_2_outlined,
                label: 'Add product',
                onTap: _addProduct,
              ),
              const SizedBox(width: LinearSpacing.sm),
              _SmallButton(
                icon:  Icons.category_outlined,
                label: 'Add bundle',
                onTap: _addBundle,
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.sm),

          ClipRRect(
            borderRadius: BorderRadius.circular(LinearRadii.md),
            child: Container(
              decoration: BoxDecoration(
                color:        ext.surfaceBase,
                borderRadius: BorderRadius.circular(LinearRadii.md),
                border:       Border.all(color: ext.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Column header (only when rows are present)
                  if (!_loadingLines && _lines.isNotEmpty) ...[
                    Container(
                      color: ext.overlay,
                      padding: const EdgeInsets.symmetric(
                        horizontal: LinearSpacing.base,
                        vertical:   LinearSpacing.xs + 2,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: _kBColN,
                            child: Text('N°',
                                style: text.labelSmall?.copyWith(
                                  color: ext.textMuted, letterSpacing: 0.2)),
                          ),
                          const SizedBox(width: _kBColGap),
                          const SizedBox(width: _kBColIcon),
                          const SizedBox(width: _kBColGap),
                          SizedBox(
                            width: _kBColCat,
                            child: Text('Category',
                                style: text.labelSmall?.copyWith(
                                  color: ext.textMuted, letterSpacing: 0.2)),
                          ),
                          const SizedBox(width: _kBColGap),
                          SizedBox(
                            width: _kBColBrand,
                            child: Text('Brand',
                                style: text.labelSmall?.copyWith(
                                  color: ext.textMuted, letterSpacing: 0.2)),
                          ),
                          const SizedBox(width: _kBColGap),
                          SizedBox(
                            width: _kBColSku,
                            child: Text('SKU',
                                style: text.labelSmall?.copyWith(
                                  color: ext.textMuted, letterSpacing: 0.2)),
                          ),
                          const SizedBox(width: _kBColGap),
                          SizedBox(
                            width: _kBColUnit,
                            child: Text('Unit',
                                style: text.labelSmall?.copyWith(
                                  color: ext.textMuted, letterSpacing: 0.2)),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: _kBColQty,
                            child: Text('Qty',
                                textAlign: TextAlign.end,
                                style: text.labelSmall?.copyWith(
                                  color: ext.textMuted, letterSpacing: 0.2)),
                          ),
                          // spacer matching drag+gap+del+sm in each data row
                          const SizedBox(width: 56),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: ext.borderSubtle),
                  ],
                  // Body
                  if (_loadingLines)
                    const Padding(
                      padding: EdgeInsets.all(LinearSpacing.lg),
                      child: Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color:       LinearColors.accent,
                          ),
                        ),
                      ),
                    )
                  else if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(LinearSpacing.lg),
                      child: Center(
                        child: Text(
                          'No children yet — add products or bundles above.',
                          style: text.bodySmall?.copyWith(color: ext.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      shrinkWrap:    true,
                      physics:       const NeverScrollableScrollPhysics(),
                      itemCount:     _lines.length,
                      onReorderItem: (from, to) {
                        setState(() {
                          final item = _lines.removeAt(from);
                          _lines.insert(to, item);
                        });
                      },
                      itemBuilder: (ctx, i) => _BundleLineRow(
                        key:       ValueKey(Object.hashAll([_lines[i].itemId, i])),
                        draft:     _lines[i],
                        index:     i,
                        onDelete:  () => _removeLine(i),
                        onChanged: () => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.sm),
            _ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}

// ── Delete button (own hover → danger colour) ──────────────────────────────────

class _DeleteButton extends StatefulWidget {
  const _DeleteButton({required this.onDelete});
  final VoidCallback onDelete;

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? LinearColors.danger : context.linearExt.textSecondary;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: 'Remove',
        child: GestureDetector(
          onTap: widget.onDelete,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width:  22,
            height: 22,
            decoration: BoxDecoration(
              color:        _hovered
                  ? LinearColors.danger.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(LinearRadii.xs),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.close_rounded, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}

// ── Bundle line row ────────────────────────────────────────────────────────────

class _BundleLineRow extends StatefulWidget {
  const _BundleLineRow({
    super.key,
    required this.draft,
    required this.index,
    required this.onDelete,
    required this.onChanged,
  });

  final _LineDraft   draft;
  final int          index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_BundleLineRow> createState() => _BundleLineRowState();
}

class _BundleLineRowState extends State<_BundleLineRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    final d    = widget.draft;

    final isBundle   = d.type == 'bundle';
    final missingCat = !isBundle && (d.category == null || d.category!.isEmpty);

    final catText   = isBundle ? d.displayName : (d.category ?? '—');
    final brandText = d.brand ?? (isBundle ? '' : '—');
    final skuText   = d.sku   ?? (isBundle ? '' : '—');
    final unitText  = d.unit  ?? (isBundle ? '' : '—');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _hovered ? ext.overlay : Colors.transparent,
          border: Border(bottom: BorderSide(color: ext.borderSubtle)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.base,
          vertical:   LinearSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // N°
            SizedBox(
              width: _kBColN,
              child: Text(
                '${widget.index + 1}',
                style: text.labelSmall?.copyWith(color: ext.textMuted),
              ),
            ),
            const SizedBox(width: _kBColGap),
            // Type icon
            SizedBox(
              width: _kBColIcon,
              child: Icon(
                isBundle
                    ? Icons.category_outlined
                    : Icons.inventory_2_outlined,
                size:  13,
                color: ext.textMuted,
              ),
            ),
            const SizedBox(width: _kBColGap),
            // Category (red if missing for a product row)
            SizedBox(
              width: _kBColCat,
              child: Text(
                catText,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color:      missingCat ? LinearColors.danger : ext.textPrimary,
                  fontWeight: isBundle ? FontWeight.w500 : null,
                ),
              ),
            ),
            const SizedBox(width: _kBColGap),
            // Brand
            SizedBox(
              width: _kBColBrand,
              child: Text(
                brandText,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: brandText.isEmpty || brandText == '—'
                      ? ext.textMuted
                      : ext.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: _kBColGap),
            // SKU
            SizedBox(
              width: _kBColSku,
              child: Text(
                skuText,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: skuText.isEmpty || skuText == '—'
                      ? ext.textMuted
                      : ext.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: _kBColGap),
            // Unit
            SizedBox(
              width: _kBColUnit,
              child: Text(
                unitText,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ),
            const Spacer(),
            // Qty field
            SizedBox(
              width: _kBColQty,
              child: TextField(
                controller:      d.qtyCtrl,
                textAlign:       TextAlign.end,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                onChanged:       (_) => widget.onChanged(),
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText: '1',
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 5,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide:   BorderSide(color: ext.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide: const BorderSide(
                      color: LinearColors.accent, width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: LinearSpacing.sm),
            // Drag handle — explicit listener so the default handle isn't used
            ReorderableDragStartListener(
              index: widget.index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox(
                  width: _kBColDrag, height: 22,
                  child: Icon(
                    Icons.drag_indicator,
                    size:  14,
                    color: _hovered ? ext.textMuted : ext.borderBase,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _kBColGap),
            // Delete (visible on hover)
            SizedBox(
              width: _kBColDel,
              child: AnimatedOpacity(
                opacity:  _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: _DeleteButton(onDelete: widget.onDelete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Child-bundle picker ────────────────────────────────────────────────────────

Future<ProductBundle?> _showChildBundlePicker(
  BuildContext context,
  WidgetRef ref, {
  String?      excludeId,
  Set<String>? excludedIds,
}) {
  return showDialog<ProductBundle>(
    context: context,
    builder: (_) => _ChildBundlePickerDialog(
      excludeId:   excludeId,
      excludedIds: excludedIds ?? {},
      bundlesRef:  ref,
    ),
  );
}

class _ChildBundlePickerDialog extends ConsumerStatefulWidget {
  const _ChildBundlePickerDialog({
    required this.excludeId,
    required this.excludedIds,
    required this.bundlesRef,
  });

  final String?     excludeId;
  final Set<String> excludedIds;
  final WidgetRef   bundlesRef;

  @override
  ConsumerState<_ChildBundlePickerDialog> createState() =>
      _ChildBundlePickerDialogState();
}

class _ChildBundlePickerDialogState
    extends ConsumerState<_ChildBundlePickerDialog> {
  String _query = '';

  List<ProductBundle> _filter(List<ProductBundle> all) {
    return all.where((b) {
      if (!b.isActive) return false;
      if (b.id == widget.excludeId) return false;
      if (widget.excludedIds.contains(b.id)) return false;
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty && !b.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ext          = context.linearExt;
    final text         = Theme.of(context).textTheme;
    final bundlesAsync = ref.watch(bundlesProvider);

    return Dialog(
      backgroundColor:  ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base, LinearSpacing.base,
                LinearSpacing.base, LinearSpacing.sm,
              ),
              child: Text('Select child bundle', style: text.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search bundles…',
                  hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                  prefixIcon: Icon(Icons.search, size: 14, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm, vertical: LinearSpacing.sm,
                  ),
                  filled:    true,
                  fillColor: ext.surfaceBase,
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
            const SizedBox(height: LinearSpacing.sm),
            const Divider(height: 1),
            Expanded(
              child: bundlesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error:   (e, _) => Center(
                  child: Text('Error loading bundles',
                      style: text.bodySmall?.copyWith(color: ext.textMuted)),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No available bundles'
                            : 'No results for "$_query"',
                        style: text.bodySmall?.copyWith(color: ext.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount:   filtered.length,
                    itemBuilder: (ctx, i) {
                      final b = filtered[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(b),
                          overlayColor: WidgetStatePropertyAll(ext.overlay),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: LinearSpacing.base,
                              vertical:   LinearSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                _BundleAvatar(bundle: b),
                                const SizedBox(width: LinearSpacing.sm),
                                Expanded(
                                  child: Text(b.name,
                                      style: text.bodySmall
                                          ?.copyWith(color: ext.textPrimary)),
                                ),
                                Text('${b.lineCount} items',
                                    style: text.labelSmall
                                        ?.copyWith(color: ext.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

// ── Category picker ────────────────────────────────────────────────────────────

Future<String?> _showCategoryPicker(
  BuildContext context,
  List<String> categories,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CategoryPickerDialog(categories: categories),
  );
}

class _CategoryPickerDialog extends StatefulWidget {
  const _CategoryPickerDialog({required this.categories});
  final List<String> categories;

  @override
  State<_CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<_CategoryPickerDialog> {
  String _query = '';

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.categories;
    return widget.categories.where((c) => c.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor:  ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base, LinearSpacing.base,
                LinearSpacing.base, LinearSpacing.sm,
              ),
              child: Text('Select category', style: text.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search categories…',
                  hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                  prefixIcon: Icon(Icons.search, size: 14, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm, vertical: LinearSpacing.sm,
                  ),
                  filled:    true,
                  fillColor: ext.surfaceBase,
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
            const SizedBox(height: LinearSpacing.sm),
            const Divider(height: 1),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No categories match "$_query"',
                        style: text.bodySmall?.copyWith(color: ext.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount:   _filtered.length,
                      itemBuilder: (ctx, i) {
                        final cat = _filtered[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(cat),
                            overlayColor: WidgetStatePropertyAll(ext.overlay),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: LinearSpacing.base,
                                vertical:   LinearSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.folder_outlined,
                                      size: 14, color: ext.textMuted),
                                  const SizedBox(width: LinearSpacing.sm),
                                  Expanded(
                                    child: Text(cat,
                                        style: text.bodySmall
                                            ?.copyWith(color: ext.textPrimary)),
                                  ),
                                ],
                              ),
                            ),
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

// ── Small action button ────────────────────────────────────────────────────────

class _SmallButton extends StatefulWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:        _hovered ? ext.overlayActive : ext.overlay,
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            border:       Border.all(color: ext.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12,
                  color: _hovered ? LinearColors.accent : ext.textMuted),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _hovered ? LinearColors.accent : ext.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Labeled text field ─────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint         = '',
    this.maxLines     = 1,
    this.autofocus    = false,
    this.onChanged,
    this.keyboardType,
  });

  final String                 label;
  final TextEditingController  controller;
  final String                 hint;
  final int                    maxLines;
  final bool                   autofocus;
  final ValueChanged<String>?  onChanged;
  final TextInputType?         keyboardType;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: ext.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller:   controller,
          autofocus:    autofocus,
          maxLines:     maxLines,
          onChanged:    onChanged,
          keyboardType: keyboardType,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: ext.textPrimary),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ext.textMuted),
            isDense:        true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              borderSide:   BorderSide(color: ext.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.base, vertical: LinearSpacing.sm,
        ),
        decoration: BoxDecoration(
          color:        LinearColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border: Border.all(color: LinearColors.danger.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 14, color: LinearColors.danger),
            const SizedBox(width: LinearSpacing.sm),
            Expanded(
              child: Text(message,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: LinearColors.danger)),
            ),
          ],
        ),
      );
}
