import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';

class CompanyRepository {
  const CompanyRepository(this._client);
  final SupabaseClient _client;

  static const _table  = 'companies';
  static const _select =
      '*, creator:profiles!created_by(display_name), updater:profiles!updated_by(display_name)';

  Future<List<Company>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .order('name')
        .limit(2000);   // D-3
    return rows.map(Company.fromJson).toList();
  }

  Future<Company> create(CompanyInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select(_select)
        .single();
    return Company.fromJson(row);
  }

  Future<Company> update(String id, CompanyInput input) async {
    final row = await _client
        .from(_table)
        .update(input.toJson())
        .eq('id', id)
        .select(_select)
        .single();
    return Company.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('org_id', orgId);
  }
}
