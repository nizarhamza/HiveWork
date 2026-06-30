import 'product.dart';

// ── Bundle header (read model) ─────────────────────────────────────────────────

class ProductBundle {
  const ProductBundle({
    required this.id,
    required this.orgId,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.category,
    this.priceOverride,
    this.sku,
    this.lineCount = 0,
  });

  final String   id;
  final String   orgId;
  final String   name;
  final String?  description;
  final String?  category;
  final double?  priceOverride;
  final String?  sku;
  final bool     isActive;
  final int      lineCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductBundle.fromJson(Map<String, dynamic> json) => ProductBundle(
        id:            json['id']             as String,
        orgId:         json['org_id']         as String,
        name:          json['name']           as String,
        description:   json['description']    as String?,
        category:      json['category']       as String?,
        priceOverride: (json['price_override'] as num?)?.toDouble(),
        sku:           json['sku']            as String?,
        isActive:      json['is_active']      as bool? ?? true,
        lineCount:     (json['line_count']    as num? ?? 0).toInt(),
        createdAt:     DateTime.parse(json['created_at'] as String),
        updatedAt:     DateTime.parse(json['updated_at'] as String),
      );

  ProductBundle copyWith({
    String?  name,
    String?  description,
    String?  category,
    double?  priceOverride,
    String?  sku,
    bool?    isActive,
    int?     lineCount,
  }) =>
      ProductBundle(
        id:            id,
        orgId:         orgId,
        name:          name          ?? this.name,
        description:   description   ?? this.description,
        category:      category      ?? this.category,
        priceOverride: priceOverride ?? this.priceOverride,
        sku:           sku           ?? this.sku,
        isActive:      isActive      ?? this.isActive,
        lineCount:     lineCount     ?? this.lineCount,
        createdAt:     createdAt,
        updatedAt:     updatedAt,
      );
}

// ── Bundle line (read model) ───────────────────────────────────────────────────

class ProductBundleLine {
  const ProductBundleLine({
    required this.id,
    required this.bundleId,
    required this.quantity,
    required this.sortOrder,
    this.productId,
    this.childBundleId,
    this.product,
    this.childBundle,
  });

  final String         id;
  final String         bundleId;
  final String?        productId;
  final String?        childBundleId;
  final double         quantity;
  final int            sortOrder;
  // resolved joins
  final Product?       product;
  final ProductBundle? childBundle;

  bool   get isProduct => productId != null;
  bool   get isBundle  => childBundleId != null;
  String get displayName => product?.displayLabel ?? childBundle?.name ?? '—';

  factory ProductBundleLine.fromJson(
    Map<String, dynamic> json, {
    Product?       product,
    ProductBundle? childBundle,
  }) =>
      ProductBundleLine(
        id:            json['id']              as String,
        bundleId:      json['bundle_id']       as String,
        productId:     json['product_id']      as String?,
        childBundleId: json['child_bundle_id'] as String?,
        quantity:      (json['quantity']       as num).toDouble(),
        sortOrder:     (json['sort_order']     as num? ?? 0).toInt(),
        product:       product,
        childBundle:   childBundle,
      );
}

// ── Bundle with resolved lines ─────────────────────────────────────────────────

class ProductBundleWithLines {
  const ProductBundleWithLines({
    required this.bundle,
    required this.lines,
  });

  final ProductBundle           bundle;
  final List<ProductBundleLine> lines;
}

// ── Flat leaf (result of recursive bundle expansion) ──────────────────────────

class FlatBundleLine {
  const FlatBundleLine({required this.product, required this.qty});

  final Product product;
  final double  qty; // effective qty = all ancestor quantities multiplied
}

// ── Write models ───────────────────────────────────────────────────────────────

class ProductBundleInput {
  const ProductBundleInput({
    required this.orgId,
    required this.name,
    this.description,
    this.category,
    this.priceOverride,
    this.sku,
    this.isActive = true,
  });

  final String  orgId;
  final String  name;
  final String? description;
  final String? category;
  final double? priceOverride;
  final String? sku;
  final bool    isActive;

  Map<String, dynamic> toJson() => {
        'org_id':    orgId,
        'name':      name,
        'is_active': isActive,
        if (description   != null) 'description':    description,
        if (category      != null) 'category':       category,
        if (priceOverride != null) 'price_override': priceOverride,
        if (sku           != null) 'sku':            sku,
      };
}

class ProductBundleLineInput {
  const ProductBundleLineInput({
    required this.quantity,
    required this.sortOrder,
    this.productId,
    this.childBundleId,
  });

  final String? productId;
  final String? childBundleId;
  final double  quantity;
  final int     sortOrder;

  Map<String, dynamic> toJson(String bundleId) => {
        'bundle_id':  bundleId,
        'quantity':   quantity,
        'sort_order': sortOrder,
        if (productId      != null) 'product_id':      productId,
        if (childBundleId  != null) 'child_bundle_id': childBundleId,
      };
}
