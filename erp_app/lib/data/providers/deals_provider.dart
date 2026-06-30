import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/deal.dart';
import '../repositories/deal_repository.dart';

final dealRepositoryProvider = Provider<DealRepository>((ref) {
  return DealRepository(ref.watch(supabaseClientProvider));
});

class DealsNotifier extends AsyncNotifier<List<Deal>> {
  @override
  Future<List<Deal>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(dealRepositoryProvider).fetchAll(orgId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Deal> create(DealInput input) async {
    final deal = await ref.read(dealRepositoryProvider).create(input);
    state = AsyncData([deal, ...?state.value]);
    return deal;
  }

  Future<Deal> updateDeal(String id, DealInput input) async {
    final updated = await ref.read(dealRepositoryProvider).update(id, input);
    state = AsyncData(
      state.value?.map((d) => d.id == id ? updated : d).toList() ?? [],
    );
    return updated;
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(dealRepositoryProvider).delete(id, orgId);
    state = AsyncData(state.value?.where((d) => d.id != id).toList() ?? []);
  }
}

final dealsProvider =
    AsyncNotifierProvider<DealsNotifier, List<Deal>>(DealsNotifier.new);
