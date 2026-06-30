import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deal.dart';

class DealRepository {
  const DealRepository(this._client);
  final SupabaseClient _client;

  static const _table  = 'deals';
  static const _select =
      '*, contacts(first_name, last_name), companies(name), '
      'owner:profiles!owner_id(display_name), '
      'creator:profiles!created_by(display_name)';

  Future<List<Deal>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(1000);   // D-3
    return rows.map(Deal.fromJson).toList();
  }

  Stream<List<Deal>> watchAll(String orgId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('org_id', orgId)
        .asyncMap((_) => fetchAll(orgId));
  }

  Future<Deal> create(DealInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select(_select)
        .single();
    return Deal.fromJson(row);
  }

  Future<Deal> update(String id, DealInput input) async {
    final row = await _client
        .from(_table)
        .update(input.toJson())
        .eq('id', id)
        .select(_select)
        .single();
    return Deal.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('org_id', orgId);
  }
}
