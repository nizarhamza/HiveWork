import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_bundle.dart';
import '../../data/providers/product_bundle_provider.dart';
import '../../theme/linear_tokens.dart';

/// Result of the bundle picker — the selected bundle plus the multiplier qty.
typedef BundlePickResult = ({ProductBundle bundle, double qty});

/// Opens the bundle picker modal.
/// Returns null if the user cancelled, otherwise the selected bundle + qty.
Future<BundlePickResult?> showBundlePicker(BuildContext context) {
  return showDialog<BundlePickResult>(
    context: context,
    builder: (_) => const _BundlePickerDialog(),
  );
}

// ── Dialog ─────────────────────────────────────────────────────────────────────

class _BundlePickerDialog extends ConsumerStatefulWidget {
  const _BundlePickerDialog();

  @override
  ConsumerState<_BundlePickerDialog> createState() => _BundlePickerDialogState();
}

class _BundlePickerDialogState extends ConsumerState<_BundlePickerDialog> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl    = TextEditingController(text: '1');

  String          _query    = '';
  ProductBundle?  _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<ProductBundle> _filter(List<ProductBundle> all) {
    final q = _query.trim().toLowerCase();
    return all.where((b) {
      if (!b.isActive) return false;
      if (q.isNotEmpty && !b.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  void _select(ProductBundle b) {
    setState(() {
      _selected = b;
      _qtyCtrl.text = '1';
    });
  }

  void _confirm() {
    final bundle = _selected;
    if (bundle == null) return;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
    if (qty <= 0) return;
    Navigator.of(context).pop((bundle: bundle, qty: qty));
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base, LinearSpacing.base,
                LinearSpacing.base, LinearSpacing.sm,
              ),
              child: Text('Insert bundle', style: text.titleSmall),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.base),
              child: TextField(
                controller: _searchCtrl,
                autofocus:  _selected == null,
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
                onChanged: (v) => setState(() {
                  _query    = v;
                  _selected = null;
                }),
              ),
            ),
            const SizedBox(height: LinearSpacing.sm),
            const Divider(height: 1),

            // Bundle list
            Expanded(
              child: bundlesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error loading bundles',
                      style: text.bodySmall?.copyWith(color: ext.textMuted)),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No active bundles yet'
                            : 'No results for "$_query"',
                        style:
                            text.bodySmall?.copyWith(color: ext.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount:   filtered.length,
                    itemBuilder: (ctx, i) => _BundleTile(
                      bundle:   filtered[i],
                      selected: filtered[i].id == _selected?.id,
                      onTap:    () => _select(filtered[i]),
                    ),
                  );
                },
              ),
            ),

            // Qty prompt (shown once a bundle is selected)
            if (_selected != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.base,
                  vertical:   LinearSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Insert "${_selected!.name}"',
                            style: text.bodySmall
                                ?.copyWith(color: ext.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_selected!.lineCount} product(s) will be expanded',
                            style: text.labelSmall
                                ?.copyWith(color: ext.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: LinearSpacing.base),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller:      _qtyCtrl,
                        autofocus:       true,
                        textAlign:       TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                        ],
                        style: text.bodySmall?.copyWith(color: ext.textPrimary),
                        decoration: InputDecoration(
                          labelText:  'Qty',
                          labelStyle: text.labelSmall
                              ?.copyWith(color: ext.textMuted),
                          isDense:        true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LinearRadii.sm),
                            borderSide:   BorderSide(color: ext.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LinearRadii.sm),
                            borderSide: const BorderSide(
                                color: LinearColors.accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: LinearSpacing.sm),
                    _InsertButton(onTap: _confirm),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bundle tile in the list ────────────────────────────────────────────────────

class _BundleTile extends StatelessWidget {
  const _BundleTile({
    required this.bundle,
    required this.selected,
    required this.onTap,
  });

  final ProductBundle bundle;
  final bool          selected;
  final VoidCallback  onTap;

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
              _Avatar(bundle: bundle),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      bundle.name,
                      style: text.bodySmall?.copyWith(
                        color:      ext.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bundle.description != null)
                      Text(bundle.description!,
                          style: text.labelSmall
                              ?.copyWith(color: ext.textMuted),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Text(
                '${bundle.lineCount} item${bundle.lineCount == 1 ? '' : 's'}',
                style: text.labelSmall?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(width: LinearSpacing.sm),
              if (selected)
                const Icon(Icons.check, size: 15, color: LinearColors.accent)
              else
                const SizedBox(width: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.bundle});
  final ProductBundle bundle;

  @override
  Widget build(BuildContext context) {
    const palette = [
      Color(0xFF5E6AD2), Color(0xFF2BA87E), Color(0xFFD9730D),
      Color(0xFFC2554D), Color(0xFF9D5BD2), Color(0xFF3A87C2),
    ];
    final idx =
        bundle.name.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    final color = palette[idx];

    final words    = bundle.name.trim().split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : bundle.name.substring(0, bundle.name.length.clamp(0, 2)).toUpperCase();

    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Insert button ──────────────────────────────────────────────────────────────

class _InsertButton extends StatefulWidget {
  const _InsertButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_InsertButton> createState() => _InsertButtonState();
}

class _InsertButtonState extends State<_InsertButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? LinearColors.accent
                : LinearColors.accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(LinearRadii.sm),
          ),
          child: Text(
            'Insert',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:      Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
