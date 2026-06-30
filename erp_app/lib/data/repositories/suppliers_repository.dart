import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier.dart';

class SuppliersRepository {
  const SuppliersRepository(this._client);
  final SupabaseClient _client;

  static const _table  = 'suppliers';
  static const _select = '*';

  Future<List<Supplier>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .order('name')
        .limit(2000);   // D-3
    return rows.map(Supplier.fromJson).toList();
  }

  Future<Supplier> create(SupplierInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select(_select)
        .single();
    return Supplier.fromJson(row);
  }

  Future<Supplier> update(String id, SupplierInput input) async {
    final row = await _client
        .from(_table)
        .update(input.toJson())
        .eq('id', id)
        .select(_select)
        .single();
    return Supplier.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('org_id', orgId);
  }
}
