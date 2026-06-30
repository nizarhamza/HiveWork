import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product.dart';
import '../../data/providers/products_provider.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/organisms/app_dialog.dart';
import '../../core/utils/formatting.dart';
import 'product_form_dialog.dart';

const double _kPropsWidth    = 256.0;
const double _kPropsWidthMin = 180.0;
const double _kPropsWidthMax = 480.0;
const double _kSplitBreak    = 560.0;

// ── Public entry-point ─────────────────────────────────────────────────────────

class ProductDetailPane extends ConsumerStatefulWidget {
  const ProductDetailPane({
    super.key,
    required this.product,
    this.onClose,
  });

  final Product       product;
  final VoidCallback? onClose;

  @override
  ConsumerState<ProductDetailPane> createState() => _ProductDetailPaneState();
}

class _ProductDetailPaneState extends ConsumerState<ProductDetailPane> {
  double _propsWidth = _kPropsWidth;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final onClose = widget.onClose;

    Future<void> update(ProductInput input) =>
        ref.read(productsProvider.notifier).updateProduct(product.id, input);

    Future<void> delete() async {
      final confirmed = await AppDialog.confirm(
        context,
        title:        'Delete ${product.name}?',
        message:      'This action cannot be undone.',
        confirmLabel: 'Delete',
        destructive:  true,
      );
      if (confirmed) {
        await ref.read(productsProvider.notifier).delete(product.id);
        onClose?.call();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(
          product: product,
          onClose: onClose,
          onDelete: delete,
          onAdjustStock: () => _showAdjustStock(context, product),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth >= _kSplitBreak) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _RecordBody(product: product, onUpdate: update),
                    ),
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
                            left: BorderSide(color: ctx.linearExt.borderSubtle),
                          ),
                        ),
                        child: _PropertiesPanel(
                          product:  product,
                          onUpdate: update,
                          onAdjustStock: () => _showAdjustStock(ctx, product),
                        ),
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
                    _PropertiesPanel(
                      product:       product,
                      onUpdate:      update,
                      onAdjustStock: () => _showAdjustStock(context, product),
                    ),
                    const SizedBox(height: LinearSpacing.xl),
                    _ActivitySection(product: product),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAdjustStock(BuildContext context, Product product) {
    showDialog<void>(
      context: context,
      builder: (_) => _AdjustStockDialog(
        product: product,
        onAdjust: (delta) =>  // D-2: pass delta, not absolute qty
            ref.read(productsProvider.notifier).adjustStock(product.id, delta),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.product,
    required this.onDelete,
    required this.onAdjustStock,
    this.onClose,
  });

  final Product       product;
  final VoidCallback? onClose;
  final VoidCallback  onDelete;
  final VoidCallback  onAdjustStock;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height:  56,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      child: Row(
        children: [
          if (onClose != null) ...[
            AppIconButton(
              icon:    Icons.chevron_left,
              tooltip: 'Back to list',
              iconSize: 18,
              onPressed: onClose,
            ),
            const SizedBox(width: LinearSpacing.xs),
          ],
          _ProductAvatarLarge(product: product),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style:    text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.sku != null)
                  Text(
                    'SKU: ${product.sku}',
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          AppButton(
            label:    'Adjust stock',
            variant:  AppButtonVariant.outlined,
            size:     AppButtonSize.sm,
            icon:     Icons.tune_rounded,
            onPressed: onAdjustStock,
          ),
          const SizedBox(width: LinearSpacing.sm),
          AppButton(
            label:    'Edit',
            variant:  AppButtonVariant.outlined,
            size:     AppButtonSize.sm,
            icon:     Icons.edit_outlined,
            onPressed: () => showProductForm(context, product: product),
          ),
          const SizedBox(width: LinearSpacing.sm),
          AppIconButton(
            icon:    Icons.delete_outline,
            tooltip: 'Delete product',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Record body ────────────────────────────────────────────────────────────────

class _RecordBody extends StatelessWidget {
  const _RecordBody({required this.product, required this.onUpdate});

  final Product product;
  final Future<void> Function(ProductInput) onUpdate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DescriptionSection(product: product, onUpdate: onUpdate),
          const SizedBox(height: LinearSpacing.xl),
          _ActivitySection(product: product),
        ],
      ),
    );
  }
}

// ── Description ────────────────────────────────────────────────────────────────

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.product, required this.onUpdate});

  final Product product;
  final Future<void> Function(ProductInput) onUpdate;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  late final _ctrl = TextEditingController(text: widget.product.description ?? '');
  bool _editing = false;
  bool _saving  = false;

  @override
  void didUpdateWidget(_DescriptionSection old) {
    super.didUpdateWidget(old);
    if (!_editing && old.product.description != widget.product.description) {
      _ctrl.text = widget.product.description ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final desc = _ctrl.text.trim();
    await widget.onUpdate(
      widget.product.toInput().copyWith(
        description: desc.isEmpty ? null : desc,
      ),
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
        const _SectionHeader('Description'),
        const SizedBox(height: LinearSpacing.sm),
        if (_editing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _ctrl,
                maxLines:   null,
                minLines:   3,
                autofocus:  true,
                style: text.bodyMedium?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText:       'Add description…',
                  contentPadding: const EdgeInsets.all(LinearSpacing.base),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    borderSide:   BorderSide(color: ext.borderBase),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    borderSide: const BorderSide(
                        color: LinearColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: LinearSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label:    'Cancel',
                    variant:  AppButtonVariant.ghost,
                    size:     AppButtonSize.sm,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editing = false),
                  ),
                  const SizedBox(width: LinearSpacing.sm),
                  AppButton(
                    label:    'Save',
                    variant:  AppButtonVariant.filled,
                    size:     AppButtonSize.sm,
                    loading:  _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          )
        else
          Semantics(
            label: 'Description — tap to edit',
            child: GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(LinearSpacing.base),
                  decoration: BoxDecoration(
                    color:        ext.surfaceBase,
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    border:       Border.all(color: ext.borderSubtle),
                  ),
                  child: _ctrl.text.isEmpty
                      ? Text('Click to add description…', style: text.bodyMedium)
                      : Text(_ctrl.text,
                          style: text.bodyMedium?.copyWith(color: ext.textPrimary)),
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
  const _ActivitySection({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Activity'),
        const SizedBox(height: LinearSpacing.sm),
        _ActivityRow(
          icon: Icons.inventory_2_outlined,
          text: 'Product created',
          time: _fmtDate(product.createdAt),
        ),
        if (product.updatedAt != product.createdAt)
          _ActivityRow(
            icon: Icons.edit_note_outlined,
            text: 'Product updated',
            time: _fmtDate(product.updatedAt),
          ),
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
    final ext  = context.linearExt;
    final tt   = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:  ext.surfaceBase,
              shape:  BoxShape.circle,
              border: Border.all(color: ext.borderSubtle),
            ),
            child: Icon(icon, size: 13, color: ext.textMuted),
          ),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Text(text,
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          Text(time, style: tt.labelSmall),
        ],
      ),
    );
  }
}

// ── Properties panel ───────────────────────────────────────────────────────────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({
    required this.product,
    required this.onUpdate,
    required this.onAdjustStock,
  });

  final Product product;
  final Future<void> Function(ProductInput) onUpdate;
  final VoidCallback onAdjustStock;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Stock'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Qty',
            child: Row(
              children: [
                if (product.isLowStock) ...[
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: LinearColors.warning, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: LinearSpacing.xs),
                ],
                Text(
                  '${product.stockQuantity}${product.unit != null ? ' ${product.unit}' : ''}',
                  style: text.bodySmall?.copyWith(
                    color:      product.isLowStock
                        ? LinearColors.warning
                        : ext.textPrimary,
                    fontWeight: product.isLowStock ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (product.lowStockThreshold != null)
            _PropRow(
              label: 'Alert at',
              child: Text(
                '≤ ${product.lowStockThreshold}',
                style: text.bodySmall?.copyWith(color: ext.textSecondary),
              ),
            ),
          const SizedBox(height: LinearSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdjustStock,
              icon:  const Icon(Icons.tune_rounded, size: 13),
              label: const Text('Adjust stock'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.base, vertical: LinearSpacing.sm,
                ),
                textStyle: text.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Pricing'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Price',
            child: Text(
              fmtPrice(product.unitPrice),
              style: text.bodySmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          _PropRow(
            label: 'Tax',
            child: Text(
              '${product.taxRate.toStringAsFixed(0)}%',
              style: text.bodySmall?.copyWith(color: ext.textSecondary),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Details'),
          const SizedBox(height: LinearSpacing.sm),
          if (product.category != null)
            _PropRow(
              label: 'Category',
              child: Text(product.category!,
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (product.brand != null)
            _PropRow(
              label: 'Brand',
              child: Text(product.brand!,
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (product.specification != null)
            _PropRow(
              label: 'Spec',
              child: Text(product.specification!,
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (product.sku != null)
            _PropRow(
              label: 'SKU',
              child: Text(product.sku!,
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (product.unit != null)
            _PropRow(
              label: 'Unit',
              child: Text(product.unit!,
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (product.supplierName != null)
            _PropRow(
              label: 'Supplier',
              child: Text(
                product.supplierName!,
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Dates'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Created',
            child: Text(_fmtDate(product.createdAt),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          _PropRow(
            label: 'Updated',
            child: Text(_fmtDate(product.updatedAt),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Adjust stock dialog ────────────────────────────────────────────────────────

class _AdjustStockDialog extends StatefulWidget {
  const _AdjustStockDialog({required this.product, required this.onAdjust});
  final Product product;
  final Future<void> Function(int delta) onAdjust;  // D-2: delta, not abs qty

  @override
  State<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<_AdjustStockDialog> {
  late final _deltaCtrl = TextEditingController();
  String? _error;
  bool    _saving = false;

  int get _parsedDelta =>
      int.tryParse(_deltaCtrl.text.trim().replaceAll('+', '')) ?? 0;

  int get _newQty =>
      (widget.product.stockQuantity + _parsedDelta).clamp(0, 999999);

  @override
  void dispose() {
    _deltaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_deltaCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a quantity to adjust');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onAdjust(_parsedDelta);  // D-2: send delta, not newQty
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return AppDialog(
      title: 'Adjust stock — ${widget.product.name}',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Current quantity: ',
                  style: text.bodySmall?.copyWith(color: ext.textMuted)),
              Text(
                '${widget.product.stockQuantity}'
                '${widget.product.unit != null ? ' ${widget.product.unit}' : ''}',
                style: text.bodySmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.base),
          TextField(
            controller:   _deltaCtrl,
            autofocus:    true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: false,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
            ],
            onChanged: (_) => setState(() {}),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.linearExt.textPrimary),
            decoration: InputDecoration(
              labelText: 'Adjust by',
              hintText:  '+10 or -5',
            ),
          ),
          const SizedBox(height: LinearSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _deltaCtrl.text.trim().isNotEmpty
                ? Container(
                    key: const ValueKey('preview'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: LinearSpacing.base,
                      vertical:   LinearSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color:        ext.overlay,
                      borderRadius: BorderRadius.circular(LinearRadii.sm),
                    ),
                    child: Row(
                      children: [
                        Text('New quantity: ',
                            style: text.bodySmall?.copyWith(color: ext.textMuted)),
                        Text(
                          '$_newQty'
                          '${widget.product.unit != null ? ' ${widget.product.unit}' : ''}',
                          style: text.bodySmall?.copyWith(
                            color:      _newQty <= (widget.product.lowStockThreshold ?? -1)
                                ? LinearColors.warning
                                : ext.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('empty')),
          ),
          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.sm),
            Text(_error!,
                style: text.labelSmall?.copyWith(color: LinearColors.danger)),
          ],
        ],
      ),
      actions: [
        AppButton(
          label:     'Cancel',
          variant:   AppButtonVariant.ghost,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label:     'Apply',
          variant:   AppButtonVariant.filled,
          loading:   _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color:         context.linearExt.textMuted,
          letterSpacing: 0.6,
          fontWeight:    FontWeight.w600,
        ),
      );
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
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: ext.textMuted),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ProductAvatarLarge extends StatelessWidget {
  const _ProductAvatarLarge({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color:        product.avatarColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        product.initials,
        style: const TextStyle(
          color:      Colors.white,
          fontSize:   12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
