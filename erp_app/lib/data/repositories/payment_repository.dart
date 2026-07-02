import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

class PaymentRepository {
  const PaymentRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'payments';

  Future<List<Payment>> fetchByInvoice(String invoiceId, String orgId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('invoice_id', invoiceId)
        .eq('org_id', orgId)
        .order('paid_on', ascending: false);
    return (rows as List)
        .map((r) => Payment.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Payment> create(PaymentInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select()
        .single();
    return Payment.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
  }
}
