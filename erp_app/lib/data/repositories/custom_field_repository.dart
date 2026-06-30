import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/custom_field.dart';

class CustomFieldRepository {
  const CustomFieldRepository(this._client);
  final SupabaseClient _client;

  static const _table  = 'custom_field_definitions';
  static const _select =
      'id, org_id, entity_type, label, field_key, field_type, '
      'options, is_unique, sort_order, created_at';

  Future<List<CustomFieldDef>> fetchAll(
      String orgId, String entityType) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('org_id', orgId)
        .eq('entity_type', entityType)
        .order('sort_order')
        .order('created_at')
        .limit(200);    // D-3 — custom field defs are few per org
    return rows.map(CustomFieldDef.fromJson).toList();
  }

  Future<CustomFieldDef> create(CustomFieldDefInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select(_select)
        .single();
    return CustomFieldDef.fromJson(row);
  }

  Future<void> delete(String id) async {
    final deleted =
        await _client.from(_table).delete().eq('id', id).select('id');
    if ((deleted as List).isEmpty) {
      throw Exception(
          'Delete failed — the field no longer exists or you do not have permission.');
    }
  }

  // Returns true if no other record in the org already has [value] stored in
  // [fieldKey] inside custom_fields. Pass [excludeId] when updating an
  // existing record so the record itself doesn't count as a violation.
  Future<bool> isValueUnique({
    required String orgId,
    required String entityType,
    required String fieldKey,
    required dynamic value,
    String? excludeId,
  }) async {
    final table = entityType == 'contact' ? 'contacts' : 'companies';
    var query = _client
        .from(table)
        .select('id')
        .eq('org_id', orgId)
        .filter('custom_fields->>$fieldKey', 'eq', value.toString());

    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }

    final rows = await query;
    return (rows as List).isEmpty;
  }
}
