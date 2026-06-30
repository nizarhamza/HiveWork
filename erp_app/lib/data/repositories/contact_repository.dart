import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contact.dart';

class ContactRepository {
  const ContactRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'contacts';
  static const _select =
      '*, companies(name), creator:profiles!created_by(display_name), updater:profiles!updated_by(display_name)';

  Future<List<Contact>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .order('first_name')
        .limit(2000);   // D-3
    return rows.map(Contact.fromJson).toList();
  }

  Stream<List<Contact>> watchAll(String orgId) {
    // .stream() doesn't support joins, so we use a broadcast stream that
    // re-fetches on every change event from the realtime channel.
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('org_id', orgId)
        .asyncMap((_) => fetchAll(orgId));
  }

  Future<Contact> create(ContactInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select(_select)
        .single();
    return Contact.fromJson(row);
  }

  Future<Contact> update(String id, ContactInput input) async {
    final row = await _client
        .from(_table)
        .update(input.toJson())
        .eq('id', id)
        .select(_select)
        .single();
    return Contact.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('org_id', orgId);
  }
}
