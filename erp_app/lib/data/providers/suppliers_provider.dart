import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/supplier.dart';
import '../repositories/suppliers_repository.dart';

final supplierRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.watch(supabaseClientProvider));
});

class SuppliersNotifier extends AsyncNotifier<List<Supplier>> {
  @override
  Future<List<Supplier>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(supplierRepositoryProvider).fetchAll(orgId);
  }

  Future<void> create(SupplierInput input) async {
    final supplier = await ref.read(supplierRepositoryProvider).create(input);
    state = AsyncData([...?state.value, supplier]);
  }

  Future<void> updateSupplier(String id, SupplierInput input) async {
    final updated =
        await ref.read(supplierRepositoryProvider).update(id, input);
    state = AsyncData(
      state.value?.map((s) => s.id == id ? updated : s).toList() ?? [],
    );
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(supplierRepositoryProvider).delete(id, orgId);
    state = AsyncData(state.value?.where((s) => s.id != id).toList() ?? []);
  }
}

final suppliersProvider =
    AsyncNotifierProvider<SuppliersNotifier, List<Supplier>>(
        SuppliersNotifier.new);
