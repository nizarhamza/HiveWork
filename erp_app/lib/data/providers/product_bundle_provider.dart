import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/product_bundle.dart';
import '../repositories/product_bundle_repository.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

final productBundleRepositoryProvider = Provider<ProductBundleRepository>((ref) {
  return ProductBundleRepository(ref.watch(supabaseClientProvider));
});

// ── Bundle list (org-scoped, with CRUD mutations) ──────────────────────────────

class BundlesNotifier extends AsyncNotifier<List<ProductBundle>> {
  @override
  Future<List<ProductBundle>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(productBundleRepositoryProvider).fetchAll(orgId);
  }

  Future<ProductBundle> create(ProductBundleInput input) async {
    final bundle = await ref.read(productBundleRepositoryProvider).create(input);
    state = AsyncData([...?state.value, bundle]);
    return bundle;
  }

  Future<void> updateBundle(String id, ProductBundleInput input) async {
    final updated = await ref.read(productBundleRepositoryProvider).update(id, input);
    state = AsyncData(
      state.value?.map((b) => b.id == id ? updated : b).toList() ?? [],
    );
  }

  Future<void> softDelete(String id) async {
    await ref.read(productBundleRepositoryProvider).softDelete(id);
    state = AsyncData(
      state.value?.where((b) => b.id != id).toList() ?? [],
    );
  }

  void updateLineCount(String bundleId, int count) {
    state = AsyncData(
      state.value
              ?.map((b) => b.id == bundleId ? b.copyWith(lineCount: count) : b)
              .toList() ??
          [],
    );
  }
}

final bundlesProvider =
    AsyncNotifierProvider<BundlesNotifier, List<ProductBundle>>(
  BundlesNotifier.new,
);

// ── Bundle detail (read-only, refreshable) ─────────────────────────────────────

final bundleDetailProvider =
    FutureProvider.family<ProductBundleWithLines?, String>((ref, id) async {
  if (id.isEmpty) return null;
  return ref.read(productBundleRepositoryProvider).fetchWithLines(id);
});

// ── Bundle flatten (recursive leaf expansion) ──────────────────────────────────

final bundleFlattenProvider =
    FutureProvider.family<List<FlatBundleLine>, String>((ref, id) async {
  if (id.isEmpty) return [];
  return ref.read(productBundleRepositoryProvider).flattenBundle(id);
});
