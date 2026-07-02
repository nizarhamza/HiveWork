import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../data/models/payment.dart';
import '../../modules/org/org_providers.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/molecules/app_skeleton.dart';

// Org-wide payments list (read-only, newest first).

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgAsync = ref.watch(currentOrgIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearViewHeader(
          icon:  Icons.payments_outlined,
          title: 'Payments',
        ),
        Expanded(
          child: orgAsync.when(
            loading: () => const _Skeleton(),
            error:   (_, _) => const SizedBox.shrink(),
            data:    (orgId) {
              if (orgId == null) return const SizedBox.shrink();
              return _PaymentsList(orgId: orgId);
            },
          ),
        ),
      ],
    );
  }
}

class _PaymentsList extends ConsumerWidget {
  const _PaymentsList({required this.orgId});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(_allPaymentsProvider(orgId));

    return paymentsAsync.when(
      loading: () => const _Skeleton(),
      error:   (e, _) => Center(child: Text('Failed to load: $e')),
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Text(
              'No payments recorded yet.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.linearExt.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding:          const EdgeInsets.all(LinearSpacing.lg),
          itemCount:        payments.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: context.linearExt.borderSubtle),
          itemBuilder: (_, i) => _PaymentRow(payment: payments[i]),
        );
      },
    );
  }
}

final _allPaymentsProvider =
    FutureProvider.family<List<Payment>, String>((ref, orgId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows   = await client
      .from('payments')
      .select()
      .eq('org_id', orgId)
      .order('paid_on', ascending: false)
      .limit(500);
  return (rows as List)
      .map((r) => Payment.fromJson(r as Map<String, dynamic>))
      .toList();
});

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LinearSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:        LinearColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(LinearRadii.sm),
            ),
            child: const Icon(Icons.payments_outlined, size: 16,
                color: LinearColors.success),
          ),
          const SizedBox(width: LinearSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(payment.paidOn),
                  style: text.bodySmall?.copyWith(color: ext.textPrimary),
                ),
                if (payment.method != null)
                  Text(
                    payment.method!,
                    style: text.labelSmall?.copyWith(color: ext.textMuted),
                  ),
              ],
            ),
          ),
          if (payment.reference != null)
            Padding(
              padding: const EdgeInsets.only(right: LinearSpacing.sm),
              child: Text(
                payment.reference!,
                style: text.labelSmall?.copyWith(color: ext.textMuted),
              ),
            ),
          Text(
            '${payment.amount.toStringAsFixed(2)} TND',
            style: text.bodySmall?.copyWith(
                color:      LinearColors.success,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          8,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LinearSpacing.lg, vertical: LinearSpacing.xs),
            child: AppSkeleton.line(height: 48),
          ),
        ),
      );
}

String _fmtDate(DateTime dt) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun',
              'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
}
