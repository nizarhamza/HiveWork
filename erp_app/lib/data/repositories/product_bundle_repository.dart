import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/product_bundle.dart';

class ProductBundleRepository {
  const ProductBundleRepository(this._client);
  final SupabaseClient _client;

  static const _bundles = 'product_bundles';
  static const _lines   = 'product_bundle_lines';

  // ── Bundle list ────────────────────────────────────────────────────────────

  Future<List<ProductBundle>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_bundles)
        .select('*, line_count:product_bundle_lines!product_bundle_lines_bundle_id_fkey(count)')
        .eq('org_id', orgId)
        .order('name')
        .limit(2000);   // D-3

    return rows.map((r) {
      final countList = r['line_count'] as List<dynamic>?;
      final count = countList?.isNotEmpty == true
          ? ((countList!.first as Map<String, dynamic>)['count'] as num? ?? 0).toInt()
          : 0;
      return ProductBundle.fromJson({...r, 'line_count': count});
    }).toList();
  }

  // ── Bundle detail (with resolved lines) ────────────────────────────────────

  Future<ProductBundleWithLines> fetchWithLines(String bundleId) async {
    final bundleRow = await _client
        .from(_bundles)
        .select('*')
        .eq('id', bundleId)
        .single();

    final lineRows = await _client
        .from(_lines)
        .select(
          '*,'
          'product:products(*),'
          'child_bundle:product_bundles!child_bundle_id(*)',
        )
        .eq('bundle_id', bundleId)
        .order('sort_order');

    final bundle = ProductBundle.fromJson({...bundleRow, 'line_count': lineRows.length});

    final resolvedLines = lineRows.map((r) {
      Product?       product;
      ProductBundle? childBundle;

      final productJson = r['product'] as Map<String, dynamic>?;
      if (productJson != null) {
        product = Product.fromJson(productJson);
      }

      final cbJson = r['child_bundle'] as Map<String, dynamic>?;
      if (cbJson != null) {
        childBundle = ProductBundle.fromJson({...cbJson, 'line_count': 0});
      }

      return ProductBundleLine.fromJson(
        r,
        product:     product,
        childBundle: childBundle,
      );
    }).toList();

    return ProductBundleWithLines(bundle: bundle, lines: resolvedLines);
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<ProductBundle> create(ProductBundleInput input) async {
    final row = await _client
        .from(_bundles)
        .insert(input.toJson())
        .select('*')
        .single();
    return ProductBundle.fromJson({...row, 'line_count': 0});
  }

  Future<ProductBundle> update(String id, ProductBundleInput input) async {
    final row = await _client
        .from(_bundles)
        .update({
          'name':       input.name,
          'is_active':  input.isActive,
          'updated_at': DateTime.now().toIso8601String(),
          if (input.description != null)
            'description': input.description
          else
            'description': null,
        })
        .eq('id', id)
        .select('*')
        .single();
    return ProductBundle.fromJson(row);
  }

  Future<void> softDelete(String id) async {
    await _client.from(_bundles).update({
      'is_active':  false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Lines (replace-all strategy) ──────────────────────────────────────────

  Future<void> replaceLines(
    String bundleId,
    List<ProductBundleLineInput> lines,
  ) async {
    await _client.from(_lines).delete().eq('bundle_id', bundleId);
    if (lines.isNotEmpty) {
      await _client
          .from(_lines)
          .insert([for (final l in lines) l.toJson(bundleId)]);
    }
    await _client.from(_bundles).update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bundleId);
  }

  // ── Recursive flatten (max depth 3) ───────────────────────────────────────

  Future<List<FlatBundleLine>> flattenBundle(
    String bundleId, {
    double parentQty = 1.0,
    int    depth     = 0,
  }) async {
    if (depth > 3) return [];

    final detail = await fetchWithLines(bundleId);
    final result  = <FlatBundleLine>[];

    for (final line in detail.lines) {
      final effectiveQty = parentQty * line.quantity;
      if (line.product != null) {
        result.add(FlatBundleLine(product: line.product!, qty: effectiveQty));
      } else if (line.childBundle != null && depth < 3) {
        result.addAll(await flattenBundle(
          line.childBundle!.id,
          parentQty: effectiveQty,
          depth:     depth + 1,
        ));
      }
    }

    return result;
  }

  // ── Cycle detection (calls the DB function) ────────────────────────────────

  Future<bool> wouldCreateCycle(String rootId, String candidateId) async {
    if (rootId == candidateId) return true;
    try {
      final result = await _client.rpc(
        'bundle_would_create_cycle',
        params: {'root_id': rootId, 'candidate_id': candidateId},
      );
      return result as bool? ?? false;
    } catch (_) {
      // If the function doesn't exist yet, default to safe (not a cycle)
      return false;
    }
  }
}
