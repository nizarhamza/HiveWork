import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../data/models/payment_term_template.dart';

class PaymentTermRepository {
  const PaymentTermRepository(this._client);
  final SupabaseClient _client;

  static const _select = 'id, name, installments, created_at';

  Future<List<PaymentTermTemplate>> fetchAll(String orgId) async {
    final rows = await _client
        .from('payment_term_templates')
        .select(_select)
        .eq('org_id', orgId)
        .order('created_at');
    return (rows as List)
        .map((r) => PaymentTermTemplate.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentTermTemplate> create(
      String orgId, PaymentTermTemplateInput input) async {
    final row = await _client
        .from('payment_term_templates')
        .insert(input.toJson(orgId))
        .select(_select)
        .single();
    return PaymentTermTemplate.fromJson(row);
  }

  Future<PaymentTermTemplate> update(
      String id, String orgId, PaymentTermTemplateInput input) async {
    final row = await _client
        .from('payment_term_templates')
        .update({
          'name':         input.name.trim(),
          'installments': input.installments.map((i) => i.toJson()).toList(),
        })
        .eq('id', id)
        .eq('org_id', orgId)
        .select(_select)
        .single();
    return PaymentTermTemplate.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from('payment_term_templates')
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
  }
}

final paymentTermRepositoryProvider = Provider<PaymentTermRepository>(
  (ref) => PaymentTermRepository(ref.watch(supabaseClientProvider)),
);
