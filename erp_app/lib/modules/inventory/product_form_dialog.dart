import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product.dart';
import '../../data/providers/products_provider.dart';
import '../../data/providers/units_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/atoms/app_text_field.dart';
import '../../ui/organisms/app_dialog.dart';
import '../../core/utils/formatting.dart';
import 'supplier_picker_dialog.dart';

// Spec → category-aware placeholder for the Specification field.
String _specHint(String category) {
  final c = category.trim().toLowerCase();
  if (c.contains('onduleur') || c.contains('inverter')) return 'e.g. 3KW';
  if (c.contains('panneau') || c.contains('solar'))     return 'e.g. 550W';
  if (c.contains('batterie') || c.contains('battery'))  return 'e.g. 100Ah / 48V';
  if (c.contains('câble')    || c.contains('cable'))    return 'e.g. 6mm²';
  if (c.contains('disjoncteur'))                        return 'e.g. 32A 3P';
  if (c.contains('transformateur'))                     return 'e.g. 25KVA';
  if (c.contains('compteur') || c.contains('meter'))    return 'e.g. 40A';
  if (c.contains('luminaire'))                          return 'e.g. 60W 4000K';
  if (c.contains('armoire'))                            return 'e.g. 36 modules';
  if (c.contains('conduit')  || c.contains('gaine'))    return 'e.g. Ø25';
  return 'e.g. 3KW, 6mm², 550W…';
}

List<String> _distinctValues(List<Product> products, String? Function(Product) getter) {
  final seen = <String>{};
  for (final p in products) {
    final v = getter(p);
    if (v != null && v.isNotEmpty) seen.add(v);
  }
  return seen.toList()..sort();
}

Future<bool> showProductForm(BuildContext context, {Product? product}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => ProductFormDialog(product: product),
      ) ??
      false;
}

class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({super.key, this.product});
  final Product? product;

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  bool get _isEdit => widget.product != null;

  late final _categoryCtrl  = TextEditingController(text: widget.product?.category      ?? '');
  late final _brandCtrl     = TextEditingController(text: widget.product?.brand          ?? '');
  late final _specCtrl      = TextEditingController(text: widget.product?.specification  ?? '');
  late final _skuCtrl       = TextEditingController(text: widget.product?.sku            ?? '');
  late final _descCtrl      = TextEditingController(text: widget.product?.description    ?? '');
  late final _priceCtrl     = TextEditingController(
      text: widget.product != null ? fmtQty(widget.product!.unitPrice) : '');
  late final _taxCtrl       = TextEditingController(
      text: widget.product != null ? fmtQty(widget.product!.taxRate) : '');
  late final _thresholdCtrl = TextEditingController(
      text: widget.product?.lowStockThreshold?.toString() ?? '');

  late String? _supplierId   = widget.product?.supplierId;
  late String? _supplierName = widget.product?.supplierName;
  late String? _selectedUnit = widget.product?.unit;

  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryCtrl.addListener(() => setState(() {}));
    _brandCtrl.addListener(()    => setState(() {}));
    _specCtrl.addListener(()     => setState(() {}));
    _skuCtrl.addListener(()      => setState(() {}));
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _brandCtrl.dispose();
    _specCtrl.dispose();
    _skuCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _taxCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }


  String? _trim(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  double _parseDouble(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0.0;

  String get _previewLabel {
    final parts = [_categoryCtrl.text.trim(), _brandCtrl.text.trim(), _specCtrl.text.trim()]
        .where((s) => s.isNotEmpty)
        .join('  ');
    final skuPart = _skuCtrl.text.trim().isNotEmpty ? ' – ${_skuCtrl.text.trim()}' : '';
    return parts.isEmpty && skuPart.isEmpty ? '' : '$parts$skuPart';
  }

  Future<void> _pickSupplier() async {
    final result = await showSupplierPicker(context, currentSupplierId: _supplierId);
    if (!mounted) return;
    if (result.cleared) {
      setState(() { _supplierId = null; _supplierName = null; });
    } else if (result.supplier != null) {
      setState(() {
        _supplierId   = result.supplier!.id;
        _supplierName = result.supplier!.name;
      });
    }
  }

  Future<void> _save() async {
    final priceText = _priceCtrl.text.trim();
    if (priceText.isEmpty) {
      setState(() => _error = 'Unit price is required');
      return;
    }

    final orgId = ref.read(currentOrgIdProvider).value;
    if (orgId == null) {
      setState(() => _error = 'No organisation selected');
      return;
    }

    final input = ProductInput(
      orgId:             orgId,
      sku:               _trim(_skuCtrl),
      description:       _trim(_descCtrl),
      unitPrice:         _parseDouble(_priceCtrl),
      taxRate:           _parseDouble(_taxCtrl),
      unit:              _selectedUnit,
      stockQuantity:     widget.product?.stockQuantity ?? 0,
      lowStockThreshold: int.tryParse(_thresholdCtrl.text.trim()),
      supplierId:        _supplierId,
      category:          _trim(_categoryCtrl),
      brand:             _trim(_brandCtrl),
      specification:     _trim(_specCtrl),
    );

    setState(() { _loading = true; _error = null; });
    try {
      if (_isEdit) {
        await ref.read(productsProvider.notifier).updateProduct(widget.product!.id, input);
      } else {
        await ref.read(productsProvider.notifier).create(input);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext      = context.linearExt;
    final text     = Theme.of(context).textTheme;
    final products = ref.watch(productsProvider).value ?? [];
    final categories = _distinctValues(products, (p) => p.category);
    final brands     = _distinctValues(products, (p) => p.brand);
    final units      = ref.watch(unitsProvider);

    final preview = _previewLabel;

    return AppDialog(
      title: _isEdit ? 'Edit product' : 'New product',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Category · Brand
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AutocompleteField(
                  label:      'Category',
                  controller: _categoryCtrl,
                  options:    categories,
                  hint:       'e.g. Onduleur',
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _AutocompleteField(
                  label:      'Brand',
                  controller: _brandCtrl,
                  options:    brands,
                  hint:       'e.g. Schneider',
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),

          // 2. Specification
          AppTextField(
            label:     'Specification',
            controller: _specCtrl,
            autofocus:  !_isEdit,
            hint:       _specHint(_categoryCtrl.text),
          ),

          // Display-label preview chip (shows once any part is filled)
          if (preview.isNotEmpty) ...[
            const SizedBox(height: LinearSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
              decoration: BoxDecoration(
                color:        ext.surfaceBase,
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                border:       Border.all(color: ext.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.label_outline, size: 12, color: ext.textMuted),
                  const SizedBox(width: LinearSpacing.sm),
                  Expanded(
                    child: Text(
                      preview,
                      style: text.labelSmall?.copyWith(color: ext.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: LinearSpacing.base),

          // 3. SKU · Unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(label: 'SKU', controller: _skuCtrl),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _UnitDropdown(
                  units:    units,
                  selected: _selectedUnit,
                  onSelect: (u) => setState(() => _selectedUnit = u),
                  onAdd:    (u) {
                    ref.read(unitsProvider.notifier).addUnit(u);
                    setState(() => _selectedUnit = u);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),

          // 4. Description
          AppTextField(
            label:    'Description',
            controller: _descCtrl,
            maxLines:  2,
          ),
          const SizedBox(height: LinearSpacing.base),

          // 5. Unit price · Tax rate
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller:   _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  style: text.bodyMedium?.copyWith(color: ext.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Unit price',
                    hintText:  '0.00',
                    errorText: _error != null && _priceCtrl.text.isEmpty ? _error : null,
                  ),
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: TextField(
                  controller:   _taxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  style: text.bodyMedium?.copyWith(color: ext.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Tax rate (%)',
                    hintText:  '0',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),

          // 6. Supplier
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supplier',
                  style: text.labelSmall?.copyWith(color: ext.textMuted)),
              const SizedBox(height: LinearSpacing.xs),
              InkWell(
                onTap:        _pickSupplier,
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.base,
                    vertical:   LinearSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color:        ext.surfaceBase,
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    border:       Border.all(color: ext.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 14, color: ext.textMuted),
                      const SizedBox(width: LinearSpacing.sm),
                      Expanded(
                        child: Text(
                          _supplierName ?? 'Select supplier…',
                          style: text.bodySmall?.copyWith(
                            color: _supplierName != null
                                ? ext.textPrimary
                                : ext.textMuted,
                          ),
                        ),
                      ),
                      if (_supplierId != null)
                        GestureDetector(
                          onTap: () =>
                              setState(() { _supplierId = null; _supplierName = null; }),
                          child: Icon(Icons.close, size: 13, color: ext.textMuted),
                        )
                      else
                        Icon(Icons.chevron_right, size: 14, color: ext.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),

          // 7. Low-stock threshold
          TextField(
            controller:   _thresholdCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: text.bodyMedium?.copyWith(color: ext.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Low-stock threshold',
              hintText:  'Warn when stock reaches this level',
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.sm),
            Text(
              _error!,
              style: text.labelSmall?.copyWith(color: LinearColors.danger),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label:     'Cancel',
          variant:   AppButtonVariant.ghost,
          onPressed: _loading ? null : () => Navigator.pop(context, false),
        ),
        AppButton(
          label:     _isEdit ? 'Save changes' : 'Create product',
          variant:   AppButtonVariant.filled,
          loading:   _loading,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Unit dropdown ──────────────────────────────────────────────────────────────

class _UnitDropdown extends StatefulWidget {
  const _UnitDropdown({
    required this.units,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final List<String>        units;
  final String?             selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String>  onAdd;

  @override
  State<_UnitDropdown> createState() => _UnitDropdownState();
}

class _UnitDropdownState extends State<_UnitDropdown> {
  final _searchCtrl  = TextEditingController();
  final _layerLink   = LayerLink();
  final _focusNode   = FocusNode();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.selected ?? '';
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Delay so onTapDown on overlay items fires before the overlay is removed.
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _closeOverlay();
        });
      }
    });
  }

  @override
  void didUpdateWidget(_UnitDropdown old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected && !_focusNode.hasFocus) {
      _searchCtrl.text = widget.selected ?? '';
    }
  }

  @override
  void dispose() {
    _closeOverlay();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openOverlay() {
    _closeOverlay();
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    _overlay = OverlayEntry(
      builder: (ctx) => _UnitOverlay(
        layerLink:  _layerLink,
        query:      _searchCtrl.text,
        units:      widget.units,
        onSelect: (u) {
          widget.onSelect(u);
          _searchCtrl.text = u;
          _closeOverlay();
          _focusNode.unfocus();
        },
        onAdd: (u) {
          widget.onAdd(u);
          _searchCtrl.text = u;
          _closeOverlay();
          _focusNode.unfocus();
        },
        linearExt: ext,
        text:      text,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _closeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _rebuildOverlay() {
    if (_overlay == null) return;
    _closeOverlay();
    _openOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller:  _searchCtrl,
        focusNode:   _focusNode,
        style: text.bodyMedium?.copyWith(color: ext.textPrimary),
        decoration: InputDecoration(
          labelText: 'Unit',
          hintText: 'Piece, Metre…',
          hintStyle: text.bodyMedium?.copyWith(color: ext.textMuted),
          suffixIcon: Icon(Icons.expand_more, size: 14, color: ext.textMuted),
          suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        onTap:    _openOverlay,
        onChanged: (v) {
          widget.onSelect(v.isEmpty ? null : v);
          _rebuildOverlay();
        },
      ),
    );
  }
}

class _UnitOverlay extends StatelessWidget {
  const _UnitOverlay({
    required this.layerLink,
    required this.query,
    required this.units,
    required this.onSelect,
    required this.onAdd,
    required this.linearExt,
    required this.text,
  });

  final LayerLink          layerLink;
  final String             query;
  final List<String>       units;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onAdd;
  final LinearExt            linearExt;
  final TextTheme            text;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = units.where((u) => u.toLowerCase().contains(q)).toList();
    final showAdd  = q.isNotEmpty &&
        !units.any((u) => u.toLowerCase() == q);

    return Positioned(
      width: 200,
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link:             layerLink,
        showWhenUnlinked: false,
        targetAnchor:     Alignment.bottomLeft,
        followerAnchor:   Alignment.topLeft,
        child: Material(
          elevation: 4,
          color:     linearExt.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            side:         BorderSide(color: linearExt.borderSubtle),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              padding:    EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final u in filtered)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => onSelect(u),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
                      child: Text(u,
                          style: text.bodySmall?.copyWith(color: linearExt.textPrimary)),
                    ),
                  ),
                if (showAdd)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => onAdd(query.trim()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 13, color: LinearColors.accent),
                          const SizedBox(width: LinearSpacing.xs),
                          Flexible(
                            child: Text(
                              'Add "${query.trim()}"',
                              style: text.bodySmall?.copyWith(color: LinearColors.accent),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (filtered.isEmpty && !showAdd)
                  Padding(
                    padding: const EdgeInsets.all(LinearSpacing.base),
                    child: Text('No units',
                        style: text.bodySmall?.copyWith(color: linearExt.textMuted)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Autocomplete text field ────────────────────────────────────────────────────

class _AutocompleteField extends StatelessWidget {
  const _AutocompleteField({
    required this.label,
    required this.controller,
    required this.options,
    this.hint = '',
  });

  final String                label;
  final TextEditingController controller;
  final List<String>          options;
  final String                hint;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall?.copyWith(color: ext.textMuted)),
          const SizedBox(height: LinearSpacing.xs),
          TextField(
            controller: controller,
            style: text.bodyMedium?.copyWith(color: ext.textPrimary),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );
    }

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode:             FocusNode(),
      optionsBuilder: (tv) {
        final q = tv.text.trim().toLowerCase();
        if (q.isEmpty) return options;
        return options.where((o) => o.toLowerCase().contains(q));
      },
      onSelected: (v) => controller.text = v,
      fieldViewBuilder: (ctx, ctrl, focusNode, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall?.copyWith(color: ext.textMuted)),
          const SizedBox(height: LinearSpacing.xs),
          TextField(
            controller: ctrl,
            focusNode:  focusNode,
            style: text.bodyMedium?.copyWith(color: ext.textPrimary),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
      optionsViewBuilder: (ctx, onSelected, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          color:     ext.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            side:         BorderSide(color: ext.borderSubtle),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 220),
            child: ListView.builder(
              padding:     EdgeInsets.zero,
              shrinkWrap:  true,
              itemCount:   opts.length,
              itemBuilder: (_, i) {
                final opt = opts.elementAt(i);
                return InkWell(
                  onTap: () => onSelected(opt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LinearSpacing.base,
                      vertical:   LinearSpacing.sm,
                    ),
                    child: Text(opt,
                        style: text.bodySmall?.copyWith(color: ext.textPrimary)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
