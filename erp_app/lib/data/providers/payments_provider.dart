import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/payment.dart';
import '../repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseClientProvider));
});

final paymentsForInvoiceProvider =
    FutureProvider.family<List<Payment>, String>((ref, invoiceId) async {
  final orgId = await ref.watch(currentOrgIdProvider.future);
  if (orgId == null) return [];
  return ref.read(paymentRepositoryProvider).fetchByInvoice(invoiceId, orgId);
});
