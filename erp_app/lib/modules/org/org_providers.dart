import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/companies_provider.dart';
import '../../data/providers/contacts_provider.dart';
import '../../data/providers/deals_provider.dart';
import '../../data/providers/products_provider.dart';
import '../../data/providers/quotes_provider.dart';
import '../../data/providers/suppliers_provider.dart';
import 'org_details.dart';
import 'org_repository.dart';
import 'org_role.dart';

// ── Current org ID (replaces the FutureProvider that was in auth_providers) ────

class _CurrentOrgNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref.read(orgRepositoryProvider).getDefaultOrgId(user.id);
  }

  /// Persists [orgId] to `profiles.default_org_id` and updates local state.
  /// Invalidates all org-scoped data caches so the new org's data loads fresh.
  Future<void> select(String orgId) async {
    await ref.read(orgRepositoryProvider).setDefaultOrg(orgId);
    ref.invalidate(contactsProvider);
    ref.invalidate(companiesProvider);
    ref.invalidate(dealsProvider);
    ref.invalidate(quotesProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(suppliersProvider);
    state = AsyncData(orgId);
  }

  /// Sets local state without persisting — fallback when DB save fails.
  void forceLocal(String orgId) {
    state = AsyncData(orgId);
  }

  /// Clears the current org selection.
  Future<void> clear() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    await ref.read(supabaseClientProvider)
        .from('profiles')
        .update({'default_org_id': null})
        .eq('id', userId);
    state = const AsyncData(null);
  }
}

/// The current org's ID — null when unauthenticated or no org selected yet.
/// Use [currentOrgIdProvider.notifier].select(id) to switch orgs.
final currentOrgIdProvider =
    AsyncNotifierProvider<_CurrentOrgNotifier, String?>(
  _CurrentOrgNotifier.new,
);

// ── All orgs the signed-in user belongs to ─────────────────────────────────────

final userOrgsProvider = FutureProvider<List<OrgMembership>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(orgRepositoryProvider).fetchUserOrgs(user.id);
});

// ── Active org membership (name + role) ────────────────────────────────────────

/// The OrgMembership for the currently selected org, or null when unresolved.
final currentOrgMembershipProvider = FutureProvider<OrgMembership?>((ref) async {
  final orgId = await ref.watch(currentOrgIdProvider.future);
  if (orgId == null) return null;
  final orgs = await ref.watch(userOrgsProvider.future);
  return orgs.where((o) => o.orgId == orgId).firstOrNull;
});

// ── Full org details (for Settings → Org Info tab) ─────────────────────────────

final orgDetailsProvider = FutureProvider<OrgDetails?>((ref) async {
  final orgId = await ref.watch(currentOrgIdProvider.future);
  if (orgId == null) return null;
  return ref.read(orgRepositoryProvider).fetchOrgDetails(orgId);
});
