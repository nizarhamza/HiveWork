import 'package:flutter/material.dart';

class Product {
  const Product({
    required this.id,
    required this.orgId,
    required this.name,
    required this.unitPrice,
    required this.stockQuantity,
    required this.createdAt,
    required this.updatedAt,
    this.sku,
    this.description,
    this.taxRate = 0.0,
    this.unit,
    this.lowStockThreshold,
    this.supplierId,
    this.supplierName,
    this.category,
    this.brand,
    this.specification,
  });

  final String  id;
  final String  orgId;
  final String  name;
  final String? sku;
  final String? description;
  final double  unitPrice;
  final double  taxRate;
  final String? unit;
  final int     stockQuantity;
  final int?    lowStockThreshold;
  final String? supplierId;
  final String? supplierName;
  final String? category;
  final String? brand;
  final String? specification;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Assembled from category · brand · specification – SKU (never stored separately).
  String get displayLabel {
    final parts = [category, brand, specification]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final skuPart = sku != null && sku!.isNotEmpty ? ' – $sku' : '';
    return parts.isEmpty ? (sku ?? '') : '$parts$skuPart';
  }

  bool get isLowStock =>
      lowStockThreshold != null && stockQuantity <= lowStockThreshold!;

  String get initials {
    final parts = [category, brand, specification]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0]![0]}${parts[1]![0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) {
      final w = parts[0]!.trim().split(RegExp(r'\s+'));
      if (w.length >= 2) return '${w[0][0]}${w[1][0]}'.toUpperCase();
      return parts[0]!.substring(0, parts[0]!.length.clamp(0, 2)).toUpperCase();
    }
    final n = name.trim();
    final w = n.split(RegExp(r'\s+'));
    if (w.length >= 2) return '${w[0][0]}${w[1][0]}'.toUpperCase();
    return n.substring(0, n.length.clamp(0, 2)).toUpperCase();
  }

  Color get avatarColor {
    const palette = [
      Color(0xFF5E6AD2), Color(0xFF2BA87E), Color(0xFFD9730D),
      Color(0xFFC2554D), Color(0xFF9D5BD2), Color(0xFF3A87C2),
    ];
    final idx =
        int.parse(id.replaceAll('-', '').substring(0, 4), radix: 16) %
            palette.length;
    return palette[idx];
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>?;
    return Product(
      id:                json['id']                   as String,
      orgId:             json['org_id']               as String,
      name:              json['name']                 as String,
      sku:               json['sku']                  as String?,
      description:       json['description']          as String?,
      unitPrice:         (json['unit_price']          as num).toDouble(),
      taxRate:           (json['tax_rate']            as num? ?? 0).toDouble(),
      unit:              json['unit']                 as String?,
      stockQuantity:     (json['stock_quantity']      as num? ?? 0).toInt(),
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt(),
      supplierId:        json['supplier_id']          as String?,
      supplierName:      supplier?['name']            as String?,
      category:          json['category']             as String?,
      brand:             json['brand']                as String?,
      specification:     (json['specification']       as String?) ??
                         (json['model']               as String?),
      createdAt:         DateTime.parse(json['created_at'] as String),
      updatedAt:         DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductInput {
  const ProductInput({
    required this.orgId,
    required this.unitPrice,
    this.sku,
    this.description,
    this.taxRate = 0.0,
    this.unit,
    this.stockQuantity = 0,
    this.lowStockThreshold,
    this.supplierId,
    this.category,
    this.brand,
    this.specification,
  });

  final String  orgId;
  final String? sku;
  final String? description;
  final double  unitPrice;
  final double  taxRate;
  final String? unit;
  final int     stockQuantity;
  final int?    lowStockThreshold;
  final String? supplierId;
  final String? category;
  final String? brand;
  final String? specification;

  // Auto-computed from parts; stored in the name column for backward compat.
  String get _computedName {
    final parts = [category, brand, specification]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final skuPart = sku != null && sku!.isNotEmpty ? ' – $sku' : '';
    return parts.isEmpty ? (sku ?? 'Untitled') : '$parts$skuPart';
  }

  Map<String, dynamic> toJson() => {
        'org_id':     orgId,
        'name':       _computedName,
        if (sku         != null) 'sku':                 sku,
        if (description != null) 'description':         description,
        'unit_price': unitPrice,
        'tax_rate':   taxRate,
        if (unit        != null) 'unit':                unit,
        'stock_quantity': stockQuantity,
        if (lowStockThreshold != null)
          'low_stock_threshold': lowStockThreshold,
        if (supplierId  != null) 'supplier_id':         supplierId,
        if (category    != null) 'category':            category,
        if (brand       != null) 'brand':               brand,
        if (specification != null) 'specification':     specification,
      };

  ProductInput copyWith({
    String? orgId,
    Object? sku               = _absent,
    Object? description       = _absent,
    double? unitPrice,
    double? taxRate,
    Object? unit              = _absent,
    int?    stockQuantity,
    Object? lowStockThreshold = _absent,
    Object? supplierId        = _absent,
    Object? category          = _absent,
    Object? brand             = _absent,
    Object? specification     = _absent,
  }) =>
      ProductInput(
        orgId:  orgId  ?? this.orgId,
        sku:    identical(sku,               _absent) ? this.sku               : sku         as String?,
        description: identical(description,  _absent) ? this.description       : description as String?,
        unitPrice:   unitPrice  ?? this.unitPrice,
        taxRate:     taxRate    ?? this.taxRate,
        unit:   identical(unit,              _absent) ? this.unit              : unit        as String?,
        stockQuantity:     stockQuantity     ?? this.stockQuantity,
        lowStockThreshold: identical(lowStockThreshold, _absent)
            ? this.lowStockThreshold
            : lowStockThreshold as int?,
        supplierId: identical(supplierId,    _absent) ? this.supplierId        : supplierId  as String?,
        category:      identical(category,      _absent) ? this.category      : category      as String?,
        brand:         identical(brand,         _absent) ? this.brand         : brand         as String?,
        specification: identical(specification, _absent) ? this.specification : specification as String?,
      );
}

const _absent = Object();

extension ProductToInput on Product {
  ProductInput toInput() => ProductInput(
        orgId:             orgId,
        sku:               sku,
        description:       description,
        unitPrice:         unitPrice,
        taxRate:           taxRate,
        unit:              unit,
        stockQuantity:     stockQuantity,
        lowStockThreshold: lowStockThreshold,
        supplierId:        supplierId,
        category:          category,
        brand:             brand,
        specification:     specification,
      );
}
