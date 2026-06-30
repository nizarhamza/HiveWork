import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class ProductsRepository {
  const ProductsRepository(this._client);
  final SupabaseClient _client;

  static const _table  = 'products';
  static const _select = '*, supplier:suppliers!supplier_id(name)';

  Future<List<Product>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .order('name')
        .limit(2000);   // D-3: unbounded query guard
    return rows.map(Product.fromJson).toList();
  }

  Future<Product> create(ProductInput input) async {
    final row = await _client
        .from(_table)
        .insert(input.toJson())
        .select(_select)
        .single();
    return Product.fromJson(row);
  }

  Future<Product> update(String id, ProductInput input) async {
    final row = await _client
        .from(_table)
        .update(input.toJson())
        .eq('id', id)
        .select(_select)
        .single();
    return Product.fromJson(row);
  }

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  /// D-2: Delta-based adjustment via Postgres RPC so concurrent increments
  /// compose correctly (stock_quantity + delta vs. last-write-wins).
  /// Requires migration 20260626000003_adjust_stock_rpc.sql to be applied.
  Future<Product> adjustStock(
      String productId, String orgId, int delta) async {
    final rows = await _client.rpc('adjust_product_stock', params: {
      'p_product_id': productId,
      'p_org_id':     orgId,
      'p_delta':      delta,
    }) as List;
    return Product.fromJson(
        (rows.first as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v),
        ));
  }
}
