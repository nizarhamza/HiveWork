import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/contact.dart';
import '../repositories/contact_repository.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(supabaseClientProvider));
});

/// Async list of contacts for the current org.
/// Automatically re-runs when the auth state changes.
class ContactsNotifier extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(contactRepositoryProvider).fetchAll(orgId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create(ContactInput input) async {
    final contact = await ref.read(contactRepositoryProvider).create(input);
    state = AsyncData([...?state.value, contact]);
  }

  Future<void> updateContact(String id, ContactInput input) async {
    final updated = await ref.read(contactRepositoryProvider).update(id, input);
    state = AsyncData(
      state.value?.map((c) => c.id == id ? updated : c).toList() ?? [],
    );
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(contactRepositoryProvider).delete(id, orgId);
    state = AsyncData(state.value?.where((c) => c.id != id).toList() ?? []);
  }
}

final contactsProvider =
    AsyncNotifierProvider<ContactsNotifier, List<Contact>>(ContactsNotifier.new);
