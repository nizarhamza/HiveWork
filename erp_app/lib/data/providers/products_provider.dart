import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/product.dart';
import '../repositories/products_repository.dart';

final productRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(supabaseClientProvider));
});

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(productRepositoryProvider).fetchAll(orgId);
  }

  Future<void> create(ProductInput input) async {
    final product = await ref.read(productRepositoryProvider).create(input);
    state = AsyncData([...?state.value, product]);
  }

  Future<void> updateProduct(String id, ProductInput input) async {
    final updated = await ref.read(productRepositoryProvider).update(id, input);
    state = AsyncData(
      state.value?.map((p) => p.id == id ? updated : p).toList() ?? [],
    );
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(productRepositoryProvider).delete(id, orgId);
    state = AsyncData(state.value?.where((p) => p.id != id).toList() ?? []);
  }

  /// D-2: accepts a signed [delta] (+/-), not an absolute quantity.
  Future<void> adjustStock(String productId, int delta) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    final updated = await ref
        .read(productRepositoryProvider)
        .adjustStock(productId, orgId, delta);
    state = AsyncData(
      state.value?.map((p) => p.id == productId ? updated : p).toList() ?? [],
    );
  }
}

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(
        ProductsNotifier.new);
