import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/supplier.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../theme/linear_tokens.dart';

/// Opens a modal search-and-select dialog for picking a supplier.
/// Returns the selected [Supplier], or null if cancelled/cleared.
Future<({Supplier? supplier, bool cleared})> showSupplierPicker(
  BuildContext context, {
  String? currentSupplierId,
}) async {
  final result = await showDialog<({Supplier? supplier, bool cleared})>(
    context: context,
    builder: (_) => _SupplierPickerDialog(currentSupplierId: currentSupplierId),
  );
  return result ?? (supplier: null, cleared: false);
}

class _SupplierPickerDialog extends ConsumerStatefulWidget {
  const _SupplierPickerDialog({this.currentSupplierId});
  final String? currentSupplierId;

  @override
  ConsumerState<_SupplierPickerDialog> createState() =>
      _SupplierPickerDialogState();
}

class _SupplierPickerDialogState
    extends ConsumerState<_SupplierPickerDialog> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Supplier> _filter(List<Supplier> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.taxId?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ext           = context.linearExt;
    final text          = Theme.of(context).textTheme;
    final suppliersAsync = ref.watch(suppliersProvider);

    return Dialog(
      backgroundColor:  ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base, LinearSpacing.base,
                LinearSpacing.base, LinearSpacing.sm,
              ),
              child: Row(
                children: [
                  Text('Select supplier', style: text.titleSmall),
                  const Spacer(),
                  if (widget.currentSupplierId != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop((supplier: null, cleared: true)),
                      style: TextButton.styleFrom(foregroundColor: LinearColors.danger),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: LinearSpacing.base),
              child: TextField(
                controller: _ctrl,
                autofocus:  true,
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search suppliers…',
                  hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                  prefixIcon: Icon(Icons.search, size: 16, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm, vertical: LinearSpacing.sm,
                  ),
                  filled:       true,
                  fillColor:    ext.surfaceBase,
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
                    borderSide:   const BorderSide(color: LinearColors.accent),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: LinearSpacing.sm),
            const Divider(height: 1),
            Expanded(
              child: suppliersAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error loading suppliers',
                      style: text.bodySmall?.copyWith(color: ext.textMuted)),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty ? 'No suppliers yet' : 'No results for "$_query"',
                        style: text.bodySmall?.copyWith(color: ext.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount:   filtered.length,
                    itemBuilder: (ctx, i) => _SupplierTile(
                      supplier: filtered[i],
                      selected: filtered[i].id == widget.currentSupplierId,
                      onTap:    () => Navigator.of(context)
                          .pop((supplier: filtered[i], cleared: false)),
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

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.supplier,
    required this.selected,
    required this.onTap,
  });

  final Supplier     supplier;
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
              _SupplierAvatar(supplier: supplier),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      supplier.name,
                      style: text.bodySmall?.copyWith(
                        color:      ext.textPrimary,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (supplier.paymentTerms != null)
                      Text(
                        supplier.paymentTerms!,
                        style: text.labelSmall?.copyWith(color: ext.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (supplier.currency != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: LinearSpacing.sm),
                  child: Text(
                    supplier.currency!,
                    style: text.labelSmall?.copyWith(color: ext.textMuted),
                  ),
                ),
              if (selected)
                const Icon(Icons.check, size: 16, color: LinearColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierAvatar extends StatelessWidget {
  const _SupplierAvatar({required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color:        supplier.avatarColor,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        supplier.initials,
        style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
