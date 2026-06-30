import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/view_prefs_service.dart';
import '../../core/utils/formatting.dart';
import '../../data/models/quote.dart';
import '../../data/models/quote_line_tree.dart';
import '../../data/providers/quotes_provider.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_dialog.dart';
import '../../ui/organisms/app_toast.dart';
import '../org/org_providers.dart';
import 'quote_form_dialog.dart';
import 'quote_pdf.dart';

const double _kPropsWidth    = 240.0;
const double _kPropsWidthMin = 160.0;
const double _kPropsWidthMax = 380.0;
const double _kSplitBreak    = 540.0;

class QuoteDetailPane extends ConsumerStatefulWidget {
  const QuoteDetailPane({
    super.key,
    required this.item,
    this.onClose,
  });

  final QuoteWithClient item;
  final VoidCallback?   onClose;

  @override
  ConsumerState<QuoteDetailPane> createState() => _QuoteDetailPaneState();
}

class _QuoteDetailPaneState extends ConsumerState<QuoteDetailPane> {
  double _propsWidth = _kPropsWidth;
  bool   _exporting  = false;
  bool   _saving     = false;
  Timer? _savePropsTimer;

  @override
  void initState() {
    super.initState();
    ViewPrefsService.getDouble('quotes.propsWidth', _kPropsWidth).then((w) {
      if (mounted) setState(() => _propsWidth = w);
    });
  }

  @override
  void dispose() {
    _savePropsTimer?.cancel();
    super.dispose();
  }

  Future<void> _edit() async {
    final id = widget.item.quote.id;
    final quoteWithLines = await ref.read(quoteWithLinesProvider(id).future);
    final q = quoteWithLines ?? widget.item.quote;
    if (!mounted) return;
    final result = await showQuoteForm(context, initial: q.toInput());
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(quotesProvider.notifier).updateQuote(q.id, result);
    } catch (e) {
      // F-1: surface save errors to the user instead of swallowing them.
      if (mounted) {
        ref.read(toastProvider.notifier).show(
          'Failed to save quote: $e',
          variant: ToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await AppDialog.confirm(
      context,
      title:        'Delete this quote?',
      message:      'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive:  true,
    );
    if (confirmed && mounted) {
      await ref.read(quotesProvider.notifier).delete(widget.item.quote.id);
      widget.onClose?.call();
    }
  }

  Future<void> _exportPdf() async {
    final id = widget.item.quote.id;
    setState(() => _exporting = true);
    try {
      final quoteWithLines = await ref.read(quoteWithLinesProvider(id).future);
      if (!mounted) return;
      final org = await ref.read(orgDetailsProvider.future);
      if (!mounted) return;
      if (org == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No organization found for this account.')),
        );
        return;
      }
      final exportItem = QuoteWithClient(
        quote:      quoteWithLines ?? widget.item.quote,
        clientName: widget.item.clientName,
      );
      if (!mounted) return;
      await showQuotePdfPreview(context, exportItem, org: org);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          item:      item,
          onClose:   widget.onClose,
          onEdit:    _saving    ? null : _edit,
          onDelete:  _saving    ? null : _delete,
          onExport:  _exporting ? null : _exportPdf,
          exporting: _exporting,
          saving:    _saving,
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth >= _kSplitBreak;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _RecordBody(item: item)),
                    ResizablePaneDivider(
                      onDrag: (d) {
                        setState(() {
                          _propsWidth = (_propsWidth - d)
                              .clamp(_kPropsWidthMin, _kPropsWidthMax);
                        });
                        _savePropsTimer?.cancel();
                        _savePropsTimer = Timer(const Duration(milliseconds: 400), () {
                          ViewPrefsService.setDouble('quotes.propsWidth', _propsWidth);
                        });
                      },
                    ),
                    SizedBox(
                      width: _propsWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: ctx.linearExt.borderSubtle),
                          ),
                        ),
                        child: _PropertiesPanel(item: item),
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
                    _PropertiesPanel(item: item),
                    const SizedBox(height: LinearSpacing.xl),
                    _LineItemsBody(quoteId: item.quote.id, currency: item.quote.currency),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.exporting,
    required this.saving,
    this.onClose,
  });

  final QuoteWithClient item;
  final VoidCallback?   onClose;
  final VoidCallback?   onEdit;
  final VoidCallback?   onDelete;
  final VoidCallback?   onExport;
  final bool            exporting;
  final bool            saving;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ext  = context.linearExt;

    return Container(
      height:  56,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      child: Row(
        children: [
          if (onClose != null) ...[
            AppIconButton(
              icon:      Icons.chevron_left,
              tooltip:   'Back to list',
              iconSize:  18,
              onPressed: onClose,
            ),
            const SizedBox(width: LinearSpacing.xs),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.quote.number,
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.clientName != null)
                  Text(
                    item.clientName!,
                    style: text.bodySmall?.copyWith(color: ext.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _StatusChip(status: item.quote.status),
          const SizedBox(width: LinearSpacing.sm),
          AppButton(
            label:     'Edit',
            variant:   AppButtonVariant.outlined,
            size:      AppButtonSize.sm,
            icon:      Icons.edit_outlined,
            loading:   saving,
            onPressed: onEdit,
          ),
          const SizedBox(width: LinearSpacing.xs),
          AppButton(
            label:     'Export PDF',
            variant:   AppButtonVariant.outlined,
            size:      AppButtonSize.sm,
            icon:      Icons.picture_as_pdf_outlined,
            loading:   exporting,
            onPressed: onExport,
          ),
          const SizedBox(width: LinearSpacing.xs),
          AppIconButton(
            icon:      Icons.delete_outline,
            tooltip:   'Delete quote',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final QuoteStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
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

// ── Record body ────────────────────────────────────────────────────────────────

class _RecordBody extends StatelessWidget {
  const _RecordBody({required this.item});
  final QuoteWithClient item;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(LinearSpacing.lg),
        child: _LineItemsBody(
          quoteId:  item.quote.id,
          currency: item.quote.currency,
        ),
      );
}

// ── Line items (loads via provider) ───────────────────────────────────────────

class _LineItemsBody extends ConsumerWidget {
  const _LineItemsBody({required this.quoteId, required this.currency});
  final String quoteId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quoteWithLinesProvider(quoteId));

    return async.when(
      loading: () => Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
            child: AppSkeleton.line(height: 28),
          ),
        ),
      ),
      error: (e, _) => Text(
        'Could not load line items: $e',
        style: const TextStyle(color: LinearColors.danger),
      ),
      data: (quote) => _LineItemsSection(
        lines:    quote?.lines ?? const [],
        currency: currency,
      ),
    );
  }
}

// ── Line items table ───────────────────────────────────────────────────────────

class _LineItemsSection extends StatelessWidget {
  const _LineItemsSection({required this.lines, required this.currency});
  final List<QuoteLine> lines;
  final String          currency;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xl),
          child: Text(
            'No line items',
            style: text.bodySmall?.copyWith(color: ext.textMuted),
          ),
        ),
      );
    }

    final rows = flattenQuoteLines(lines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Line Items'),
        const SizedBox(height: LinearSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
          child: Row(
            children: [
              Expanded(child: Text('Description',
                  style: text.labelSmall?.copyWith(color: ext.textMuted))),
              const SizedBox(width: LinearSpacing.sm),
              SizedBox(width: 44, child: Text('Qty',
                  style: text.labelSmall?.copyWith(color: ext.textMuted),
                  textAlign: TextAlign.end)),
              const SizedBox(width: LinearSpacing.sm),
              SizedBox(width: 80, child: Text('Unit price',
                  style: text.labelSmall?.copyWith(color: ext.textMuted),
                  textAlign: TextAlign.end)),
              const SizedBox(width: LinearSpacing.sm),
              SizedBox(width: 80, child: Text('Total',
                  style: text.labelSmall?.copyWith(color: ext.textMuted),
                  textAlign: TextAlign.end)),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final r in rows)
          if (!r.isLeaf)
            _GroupRow(row: r, currency: currency)
          else
            _LeafRow(row: r, currency: currency),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.row, required this.currency});
  final QuoteLineRow row;
  final String       currency;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: LinearSpacing.xs, horizontal: LinearSpacing.xs),
      decoration: BoxDecoration(
        color: row.depth == 0 ? ext.overlayActive : ext.overlay,
        border: Border(
          bottom: BorderSide(color: ext.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: row.depth * 12.0),
          Text(
            '${row.number}  ',
            style: text.labelSmall?.copyWith(color: ext.textMuted),
          ),
          Expanded(
            child: Text(
              row.line.label,
              style: text.bodySmall?.copyWith(
                color: ext.textPrimary,
                fontWeight: row.depth == 0 ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          // empty qty + unit price slots to keep column alignment
          const SizedBox(width: LinearSpacing.sm),
          const SizedBox(width: 44),
          const SizedBox(width: LinearSpacing.sm),
          const SizedBox(width: 80),
          const SizedBox(width: LinearSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              _fmtAmt(currency, row.displayTotal),
              style: text.bodySmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeafRow extends StatelessWidget {
  const _LeafRow({required this.row, required this.currency});
  final QuoteLineRow row;
  final String       currency;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: row.depth * 16.0 + LinearSpacing.xs),
          Text(
            '${row.number}  ',
            style: text.labelSmall?.copyWith(color: ext.textMuted),
          ),
          Expanded(
            child: Text(row.line.label,
                style: text.bodySmall?.copyWith(color: ext.textPrimary)),
          ),
          const SizedBox(width: LinearSpacing.sm),
          SizedBox(
            width: 44,
            child: Text(fmtQty(row.line.qty),
                style: text.bodySmall?.copyWith(color: ext.textSecondary),
                textAlign: TextAlign.end),
          ),
          const SizedBox(width: LinearSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(_fmtAmt(currency, row.line.unitPrice),
                style: text.bodySmall?.copyWith(color: ext.textSecondary),
                textAlign: TextAlign.end),
          ),
          const SizedBox(width: LinearSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(_fmtAmt(currency, row.line.lineTotal),
                style: text.bodySmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w500),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ── Properties panel ──────────────────────────────────────────────────────────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.item});
  final QuoteWithClient item;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    final q    = item.quote;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Properties'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Status',
            child: _StatusChip(status: q.status),
          ),
          _PropRow(
            label: 'Number',
            child: Text(q.number,
                style: text.bodySmall?.copyWith(
                    color: ext.textPrimary, fontFamily: 'Mono')),
          ),
          _PropRow(
            label: 'Client',
            child: Text(
              item.clientName ?? '—',
              style: text.bodySmall?.copyWith(
                color: item.clientName != null ? ext.textPrimary : ext.textMuted,
              ),
            ),
          ),
          _PropRow(
            label: 'Currency',
            child: Text(q.currency,
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          if (q.validUntil != null)
            _PropRow(
              label: 'Expires',
              child: Text(_fmtDate(q.validUntil!),
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          const SizedBox(height: LinearSpacing.sm),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Amounts'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Subtotal',
            child: Text(q.displayAmount(q.subtotal),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          if (q.tax > 0)
            _PropRow(
              label: 'Tax',
              child: Text(q.displayAmount(q.tax),
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          _PropRow(
            label: 'Total',
            child: Text(
              q.displayTotal,
              style: text.bodySmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: LinearSpacing.base),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Dates'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Created',
            child: Text(_fmtDate(q.createdAt),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          _PropRow(
            label: 'Updated',
            child: Text(_fmtDate(q.updatedAt),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

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

String _fmtDate(DateTime dt) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun',
              'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _fmtAmt(String currency, double v) {
  final sym = switch (currency.toUpperCase()) {
    'EUR' => '€', 'USD' => '\$', 'GBP' => '£', _ => '$currency ',
  };
  return v == v.truncateToDouble() ? '$sym${v.toInt()}' : '$sym${v.toStringAsFixed(2)}';
}
