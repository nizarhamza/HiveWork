import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/custom_field.dart';
import '../repositories/custom_field_repository.dart';

final customFieldRepositoryProvider = Provider<CustomFieldRepository>((ref) {
  return CustomFieldRepository(ref.watch(supabaseClientProvider));
});

// ── Notifier — one instance per entityType ('contact' | 'company') ─────────────
//
// Riverpod 3.x family pattern: the factory receives the arg and passes it to
// the notifier's constructor. The notifier itself extends AsyncNotifier<T>.

class CustomFieldDefsNotifier extends AsyncNotifier<List<CustomFieldDef>> {
  CustomFieldDefsNotifier(this._entityType);
  final String _entityType;

  @override
  Future<List<CustomFieldDef>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref
        .read(customFieldRepositoryProvider)
        .fetchAll(orgId, _entityType);
  }

  Future<void> add(CustomFieldDefInput input) async {
    final def =
        await ref.read(customFieldRepositoryProvider).create(input);
    state = AsyncData([...?state.value, def]);
  }

  Future<void> remove(String id) async {
    await ref.read(customFieldRepositoryProvider).delete(id);
    state = AsyncData(
      state.value?.where((d) => d.id != id).toList() ?? [],
    );
  }
}

final customFieldDefsProvider = AsyncNotifierProvider.autoDispose.family<
    CustomFieldDefsNotifier, List<CustomFieldDef>, String>(
  (entityType) => CustomFieldDefsNotifier(entityType),
);
