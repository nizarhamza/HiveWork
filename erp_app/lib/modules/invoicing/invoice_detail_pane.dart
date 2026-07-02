import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/view_prefs_service.dart';
import '../../data/models/invoice.dart';
import '../../data/models/payment.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/providers/payments_provider.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_dialog.dart';
import '../../ui/organisms/app_toast.dart';
import '../org/org_providers.dart';
import 'invoice_form_dialog.dart';
import 'invoice_pdf.dart';

const double _kPropsWidth    = 240.0;
const double _kPropsWidthMin = 160.0;
const double _kPropsWidthMax = 380.0;
const double _kSplitBreak    = 540.0;

class InvoiceDetailPane extends ConsumerStatefulWidget {
  const InvoiceDetailPane({
    super.key,
    required this.item,
    this.onClose,
  });

  final InvoiceWithClient item;
  final VoidCallback?     onClose;

  @override
  ConsumerState<InvoiceDetailPane> createState() => _InvoiceDetailPaneState();
}

class _InvoiceDetailPaneState extends ConsumerState<InvoiceDetailPane> {
  double _propsWidth = _kPropsWidth;
  bool   _exporting        = false;
  bool   _saving           = false;
  bool   _updatingStatus   = false;
  Timer? _savePropsTimer;

  @override
  void initState() {
    super.initState();
    ViewPrefsService.getDouble('invoices.propsWidth', _kPropsWidth).then((w) {
      if (mounted) setState(() => _propsWidth = w);
    });
  }

  @override
  void dispose() {
    _savePropsTimer?.cancel();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    final id = widget.item.invoice.id;
    setState(() => _exporting = true);
    try {
      final invoiceWithLines = await ref.read(invoiceWithLinesProvider(id).future);
      if (!mounted) return;
      final org = await ref.read(orgDetailsProvider.future);
      if (!mounted) return;
      if (org == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No organization found for this account.')),
        );
        return;
      }
      final exportItem = InvoiceWithClient(
        invoice:    invoiceWithLines ?? widget.item.invoice,
        clientName: widget.item.clientName,
      );
      if (!mounted) return;
      await showInvoicePdfPreview(context, exportItem, org: org);
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

  Future<void> _edit() async {
    final id = widget.item.invoice.id;
    final invoiceWithLines = await ref.read(invoiceWithLinesProvider(id).future);
    final inv = invoiceWithLines ?? widget.item.invoice;
    if (!mounted) return;
    final result = await showInvoiceForm(context, initial: inv.toInput());
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(invoicesProvider.notifier).updateInvoice(inv.id, result);
    } catch (e) {
      if (mounted) {
        ref.read(toastProvider.notifier).show(
          'Failed to save invoice: $e',
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
      title:        'Delete this invoice?',
      message:      'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive:  true,
    );
    if (confirmed && mounted) {
      await ref.read(invoicesProvider.notifier).delete(widget.item.invoice.id);
      widget.onClose?.call();
    }
  }

  Future<void> _updateStatus(InvoiceStatus status) async {
    setState(() => _updatingStatus = true);
    try {
      await ref.read(invoicesProvider.notifier).updateStatus(
        widget.item.invoice.id,
        status,
      );
    } catch (e) {
      if (mounted) {
        ref.read(toastProvider.notifier).show(
          'Failed to update status: $e',
          variant: ToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _markSent() => _updateStatus(InvoiceStatus.sent);

  Future<void> _cancelInvoice() async {
    final confirmed = await AppDialog.confirm(
      context,
      title:        'Cancel this invoice?',
      message:      'The invoice will be marked as cancelled.',
      confirmLabel: 'Cancel Invoice',
      destructive:  true,
    );
    if (confirmed && mounted) await _updateStatus(InvoiceStatus.cancelled);
  }

  Future<void> _recordPayment() async {
    final payments = ref
        .read(paymentsForInvoiceProvider(widget.item.invoice.id))
        .value ?? [];
    final paid      = payments.fold(0.0, (s, p) => s + p.amount);
    final remaining = widget.item.invoice.total - paid;
    if (remaining <= 0) return;
    await showRecordPaymentDialog(
      context,
      invoiceId:   widget.item.invoice.id,
      orgId:       widget.item.invoice.orgId,
      maxAmount:   remaining,
    );
    if (mounted) {
      ref.invalidate(paymentsForInvoiceProvider(widget.item.invoice.id));
      ref.invalidate(invoiceWithLinesProvider(widget.item.invoice.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final inv  = item.invoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          item:     item,
          onClose:  widget.onClose,
          onExportPdf: _exporting ? null : _exportPdf,
          onEdit:   _saving ? null : _edit,
          onDelete: _saving ? null : _delete,
          onMarkSent: inv.status == InvoiceStatus.draft && !_updatingStatus
              ? _markSent : null,
          onRecordPayment: (inv.status == InvoiceStatus.sent || inv.status == InvoiceStatus.overdue)
              ? _recordPayment : null,
          onCancel: (inv.status == InvoiceStatus.draft ||
                     inv.status == InvoiceStatus.sent  ||
                     inv.status == InvoiceStatus.overdue) && !_updatingStatus
              ? _cancelInvoice : null,
          fullyPaid:      inv.status == InvoiceStatus.paid,
          saving:         _saving,
          exporting:      _exporting,
          updatingStatus: _updatingStatus,
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
                          ViewPrefsService.setDouble('invoices.propsWidth', _propsWidth);
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
                    _LineItemsBody(invoiceId: item.invoice.id, currency: inv.currency),
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
    required this.saving,
    required this.exporting,
    required this.updatingStatus,
    this.onClose,
    this.onExportPdf,
    this.onMarkSent,
    this.onRecordPayment,
    this.onCancel,
    this.fullyPaid = false,
  });

  final InvoiceWithClient item;
  final VoidCallback?     onClose;
  final VoidCallback?     onExportPdf;
  final VoidCallback?     onEdit;
  final VoidCallback?     onDelete;
  final VoidCallback?     onMarkSent;
  final VoidCallback?     onRecordPayment;
  final VoidCallback?     onCancel;
  final bool              fullyPaid;
  final bool              saving;
  final bool              exporting;
  final bool              updatingStatus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ext  = context.linearExt;
    final inv  = item.invoice;

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
                  inv.number,
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
          _StatusChip(status: inv.status),
          const SizedBox(width: LinearSpacing.sm),
          if (onMarkSent != null) ...[
            AppButton(
              label:     'Mark Sent',
              variant:   AppButtonVariant.outlined,
              size:      AppButtonSize.sm,
              icon:      Icons.send_outlined,
              onPressed: onMarkSent,
            ),
            const SizedBox(width: LinearSpacing.xs),
          ],
          if (onRecordPayment != null) ...[
            AppButton(
              label:     'Record Payment',
              variant:   AppButtonVariant.outlined,
              size:      AppButtonSize.sm,
              icon:      Icons.payments_outlined,
              onPressed: onRecordPayment,
            ),
            const SizedBox(width: LinearSpacing.xs),
          ] else if (fullyPaid) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        LinearColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                border:       Border.all(
                    color: LinearColors.success.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 13, color: LinearColors.success),
                  const SizedBox(width: 5),
                  Text(
                    'Paid in full',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: LinearColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LinearSpacing.xs),
          ],
          AppButton(
            label:     'Export PDF',
            variant:   AppButtonVariant.outlined,
            size:      AppButtonSize.sm,
            icon:      Icons.picture_as_pdf_outlined,
            loading:   exporting,
            onPressed: onExportPdf,
          ),
          const SizedBox(width: LinearSpacing.xs),
          AppButton(
            label:     'Edit',
            variant:   AppButtonVariant.outlined,
            size:      AppButtonSize.sm,
            icon:      Icons.edit_outlined,
            loading:   saving,
            onPressed: onEdit,
          ),
          if (onCancel != null) ...[
            const SizedBox(width: LinearSpacing.xs),
            AppButton(
              label:     'Cancel Invoice',
              variant:   AppButtonVariant.outlined,
              size:      AppButtonSize.sm,
              icon:      Icons.cancel_outlined,
              loading:   updatingStatus,
              onPressed: onCancel,
            ),
          ],
          const SizedBox(width: LinearSpacing.xs),
          AppIconButton(
            icon:      Icons.delete_outline,
            tooltip:   'Delete invoice',
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
  final InvoiceStatus status;

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
  final InvoiceWithClient item;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(LinearSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LineItemsBody(
              invoiceId: item.invoice.id,
              currency:  item.invoice.currency,
            ),
            const SizedBox(height: LinearSpacing.xl),
            _PaymentsSection(invoiceId: item.invoice.id),
          ],
        ),
      );
}

// ── Line items ─────────────────────────────────────────────────────────────────

class _LineItemsBody extends ConsumerWidget {
  const _LineItemsBody({required this.invoiceId, required this.currency});
  final String invoiceId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceWithLinesProvider(invoiceId));

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
      data: (invoice) => _LineItemsSection(
        lines:    invoice?.lines ?? const [],
        currency: currency,
      ),
    );
  }
}

class _LineItemsSection extends StatelessWidget {
  const _LineItemsSection({required this.lines, required this.currency});
  final List<InvoiceLine> lines;
  final String            currency;

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

    final rows = _buildRows(lines);

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
        ...rows.map((r) {
          if (r.hasChildren) return _GroupRow(row: r, currency: currency);
          return _LeafRow(row: r, currency: currency);
        }),
      ],
    );
  }

  static List<_LineRow> _buildRows(List<InvoiceLine> lines) {
    final byParent = <String?, List<InvoiceLine>>{};
    for (final l in lines) {
      byParent.putIfAbsent(l.parentId, () => []).add(l);
    }
    for (final siblings in byParent.values) {
      siblings.sort((a, b) => a.position.compareTo(b.position));
    }
    final out = <_LineRow>[];
    final counter = <int>[];
    void walk(InvoiceLine l, int depth) {
      while (counter.length <= depth) { counter.add(0); }
      if (counter.length > depth + 1) counter.removeRange(depth + 1, counter.length);
      counter[depth]++;
      final number = counter.join('.');
      final children = byParent[l.id] ?? [];
      final total = children.isEmpty
          ? l.lineTotal
          : children.fold(0.0, (s, c) => s + c.lineTotal);
      out.add(_LineRow(
        line:        l,
        depth:       depth,
        number:      number,
        hasChildren: children.isNotEmpty,
        displayTotal: total,
      ));
      for (final child in children) { walk(child, depth + 1); }
    }
    for (final root in byParent[null] ?? <InvoiceLine>[]) {
      walk(root, 0);
    }
    return out;
  }
}

class _LineRow {
  const _LineRow({
    required this.line,
    required this.depth,
    required this.number,
    required this.hasChildren,
    required this.displayTotal,
  });
  final InvoiceLine line;
  final int         depth;
  final String      number;
  final bool        hasChildren;
  final double      displayTotal;
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.row, required this.currency});
  final _LineRow row;
  final String   currency;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: LinearSpacing.xs, horizontal: LinearSpacing.xs),
      decoration: BoxDecoration(
        color: row.depth == 0 ? ext.overlayActive : ext.overlay,
        border: Border(bottom: BorderSide(color: ext.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(width: row.depth * 12.0),
          Text('${row.number}  ',
              style: text.labelSmall?.copyWith(color: ext.textMuted)),
          Expanded(
            child: Text(
              row.line.label,
              style: text.bodySmall?.copyWith(
                color:      ext.textPrimary,
                fontWeight: row.depth == 0 ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
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
  final _LineRow row;
  final String   currency;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: row.depth * 16.0 + LinearSpacing.xs),
          Text('${row.number}  ',
              style: text.labelSmall?.copyWith(color: ext.textMuted)),
          Expanded(
            child: Text(row.line.label,
                style: text.bodySmall?.copyWith(color: ext.textPrimary)),
          ),
          const SizedBox(width: LinearSpacing.sm),
          SizedBox(
            width: 44,
            child: Text(_fmtQty(row.line.qty),
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

// ── Payments section ───────────────────────────────────────────────────────────

class _PaymentsSection extends ConsumerWidget {
  const _PaymentsSection({required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentsForInvoiceProvider(invoiceId));

    return async.when(
      loading: () => AppSkeleton.line(height: 32),
      error:   (e, _) => const SizedBox.shrink(),
      data: (payments) {
        if (payments.isEmpty) return const SizedBox.shrink();
        final ext  = context.linearExt;
        final text = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader('Payments'),
            const SizedBox(height: LinearSpacing.sm),
            ...payments.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 14, color: ext.textMuted),
                      const SizedBox(width: LinearSpacing.sm),
                      Expanded(
                        child: Text(
                          '${_fmtDate(p.paidOn)}${p.method != null ? ' · ${p.method}' : ''}',
                          style: text.bodySmall?.copyWith(color: ext.textSecondary),
                        ),
                      ),
                      Text(
                        _fmtAmt('TND', p.amount),
                        style: text.bodySmall?.copyWith(
                            color: LinearColors.success,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }
}

// ── Properties panel ──────────────────────────────────────────────────────────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.item});
  final InvoiceWithClient item;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    final inv  = item.invoice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Properties'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(label: 'Status', child: _StatusChip(status: inv.status)),
          _PropRow(
            label: 'Number',
            child: Text(inv.number,
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
            child: Text(inv.currency,
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          if (inv.issueDate != null)
            _PropRow(
              label: 'Issued',
              child: Text(_fmtDate(inv.issueDate!),
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          if (inv.dueDate != null)
            _PropRow(
              label: 'Due',
              child: Text(_fmtDate(inv.dueDate!),
                  style: text.bodySmall?.copyWith(
                    color: inv.status == InvoiceStatus.overdue
                        ? LinearColors.danger
                        : ext.textSecondary,
                  )),
            ),
          if (inv.quoteId != null)
            _PropRow(
              label: 'Quote',
              child: Text('from quote',
                  style: text.bodySmall?.copyWith(color: ext.textMuted)),
            ),
          const SizedBox(height: LinearSpacing.sm),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
          const _SectionHeader('Amounts'),
          const SizedBox(height: LinearSpacing.sm),
          _PropRow(
            label: 'Subtotal',
            child: Text(inv.displayAmount(inv.subtotal),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          if (inv.tax > 0)
            _PropRow(
              label: 'Tax',
              child: Text(inv.displayAmount(inv.tax),
                  style: text.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          _PropRow(
            label: 'Total',
            child: Text(
              inv.displayTotal,
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
            child: Text(_fmtDate(inv.createdAt),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
          _PropRow(
            label: 'Updated',
            child: Text(_fmtDate(inv.updatedAt),
                style: text.bodySmall?.copyWith(color: ext.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

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

// ── Prop row ───────────────────────────────────────────────────────────────────

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

// ── Record payment dialog ──────────────────────────────────────────────────────

Future<void> showRecordPaymentDialog(
  BuildContext context, {
  required String invoiceId,
  required String orgId,
  required double maxAmount,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _RecordPaymentDialog(
      invoiceId: invoiceId,
      orgId:     orgId,
      maxAmount: maxAmount,
    ),
  );
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({
    required this.invoiceId,
    required this.orgId,
    required this.maxAmount,
  });
  final String invoiceId;
  final String orgId;
  final double maxAmount;

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  late final _amountCtrl    = TextEditingController(text: widget.maxAmount.toStringAsFixed(3));
  late final _referenceCtrl = TextEditingController();
  DateTime _paidOn  = DateTime.now();
  String?  _method  = 'Bank transfer';
  bool     _saving  = false;
  String?  _amtError;

  static const _methods = ['Cash', 'Bank transfer', 'Check', 'Credit card', 'Other'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amt <= 0) {
      setState(() => _amtError = 'Amount must be greater than 0');
      return;
    }
    if (amt > widget.maxAmount + 0.001) {
      setState(() => _amtError =
          'Exceeds remaining balance (${widget.maxAmount.toStringAsFixed(3)} TND)');
      return;
    }
    setState(() { _saving = true; _amtError = null; });
    try {
      final repo = ref.read(paymentRepositoryProvider);
      await repo.create(PaymentInput(
        orgId:     widget.orgId,
        invoiceId: widget.invoiceId,
        amount:    amt,
        paidOn:    _paidOn,
        method:    _method,
        reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
      ));
      // Auto-mark invoice paid when the full remaining balance is covered.
      if (amt >= widget.maxAmount - 0.001) {
        await ref.read(invoicesProvider.notifier).updateStatus(
          widget.invoiceId,
          InvoiceStatus.paid,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: ext.surfaceBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        side: BorderSide(color: ext.borderSubtle),
      ),
      title: Text('Record Payment', style: text.titleMedium),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Amount', style: text.labelSmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller:  _amountCtrl,
              keyboardType: TextInputType.number,
              onChanged:   (_) { if (_amtError != null) setState(() => _amtError = null); },
              style: text.bodyMedium?.copyWith(color: ext.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                errorText: _amtError,
                helperText: 'Max: ${widget.maxAmount.toStringAsFixed(3)} TND',
                helperStyle: text.labelSmall?.copyWith(color: ext.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: BorderSide(
                      color: _amtError != null ? LinearColors.danger : ext.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: BorderSide(
                      color: _amtError != null ? LinearColors.danger : LinearColors.accent,
                      width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: const BorderSide(color: LinearColors.danger),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: const BorderSide(color: LinearColors.danger, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: LinearSpacing.base),
            Text('Date', style: text.labelSmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context:     context,
                  initialDate: _paidOn,
                  firstDate:   DateTime(2020),
                  lastDate:    DateTime.now().add(const Duration(days: 7)),
                );
                if (picked != null && mounted) setState(() => _paidOn = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  border: Border.all(color: ext.borderSubtle),
                ),
                child: Text(_fmtDate(_paidOn),
                    style: text.bodyMedium?.copyWith(color: ext.textPrimary)),
              ),
            ),
            const SizedBox(height: LinearSpacing.base),
            Text('Method', style: text.labelSmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: BorderSide(color: ext.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
                ),
              ),
              dropdownColor: ext.surfaceBase,
              style: text.bodyMedium?.copyWith(color: ext.textPrimary),
              items: _methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v),
            ),
            const SizedBox(height: LinearSpacing.base),
            Text('Reference (optional)',
                style: text.labelSmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _referenceCtrl,
              style: text.bodyMedium?.copyWith(color: ext.textPrimary),
              decoration: InputDecoration(
                hintText:  'Cheque #, wire ref…',
                hintStyle: text.bodyMedium?.copyWith(color: ext.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: BorderSide(color: ext.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: text.bodySmall?.copyWith(color: ext.textMuted)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: LinearColors.accent,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

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

String _fmtQty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
