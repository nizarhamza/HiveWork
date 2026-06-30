import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'org_details.dart';
import 'org_role.dart';

class OrgRepository {
  const OrgRepository(this._client);
  final SupabaseClient _client;

  static const _orgSelect =
      'id, name, currency, timezone, address, country, phone, email, website, '
      'tax_id, logo_url, rc_number, rne_number, bank_name, bank_rib, bank_iban, '
      'bank_bic, default_payment_terms, enable_fodec, enable_timbre_fiscal, '
      'enable_retenu_source, payment_terms_options, default_quote_notes';

  /// All orgs the [userId] belongs to, with organization name + logo joined.
  Future<List<OrgMembership>> fetchUserOrgs(String userId) async {
    final rows = await _client
        .from('org_members')
        .select('org_id, org_role, organizations(name, logo_url)')
        .eq('user_id', userId);
    return (rows as List)
        .map((r) => OrgMembership.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Calls the existing `create_organization` RPC, then persists timezone.
  Future<Map<String, dynamic>> createOrg({
    required String name,
    required String currency,
    required String timezone,
  }) async {
    final result = await _client.rpc('create_organization', params: {
      'p_name':     name,
      'p_currency': currency,
      'p_address':  '',
      'p_logo_url': null,
    });
    final org = result as Map<String, dynamic>;
    // The RPC doesn't handle timezone — persist it via a direct update.
    await _client
        .from('organizations')
        .update({'timezone': timezone})
        .eq('id', org['id'] as String);
    return org;
  }

  /// Sets `profiles.default_org_id` for the currently signed-in user.
  /// S-6: null-safe — guards against a session expiring between UI action and
  /// this call; throws a clear exception rather than a cryptic null-check crash.
  Future<void> setDefaultOrg(String orgId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    await _client
        .from('profiles')
        .update({'default_org_id': orgId})
        .eq('id', userId);
  }

  /// Permanently deletes an organization via the `delete_organization` RPC.
  Future<void> deleteOrg(String orgId) async {
    await _client.rpc('delete_organization', params: {'p_org_id': orgId});
  }

  /// Full org row from the `organizations` table.
  Future<OrgDetails> fetchOrgDetails(String orgId) async {
    final row = await _client
        .from('organizations')
        .select(_orgSelect)
        .eq('id', orgId)
        .single();
    return OrgDetails.fromJson(row);
  }

  /// Partial update on the `organizations` row — only pass changed fields.
  Future<void> updateOrgDetails(
      String orgId, Map<String, dynamic> fields) async {
    await _client.from('organizations').update(fields).eq('id', orgId);
  }

  /// Reads `profiles.default_org_id` for the currently signed-in user.
  Future<String?> getDefaultOrgId(String userId) async {
    final row = await _client
        .from('profiles')
        .select('default_org_id')
        .eq('id', userId)
        .single();
    return row['default_org_id'] as String?;
  }
}

final orgRepositoryProvider = Provider<OrgRepository>(
  (ref) => OrgRepository(ref.watch(supabaseClientProvider)),
);
