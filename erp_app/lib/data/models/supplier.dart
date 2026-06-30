import 'package:flutter/material.dart';

class Supplier {
  const Supplier({
    required this.id,
    required this.orgId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.taxId,
    this.currency,
    this.paymentTerms,
  });

  final String  id;
  final String  orgId;
  final String  name;
  final String? taxId;
  final String? currency;
  final String? paymentTerms;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
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

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id:           json['id']            as String,
        orgId:        json['org_id']        as String,
        name:         json['name']          as String,
        taxId:        json['tax_id']        as String?,
        currency:     json['currency']      as String?,
        paymentTerms: json['payment_terms'] as String?,
        createdAt:    DateTime.parse(json['created_at'] as String),
        updatedAt:    DateTime.parse(json['updated_at'] as String),
      );
}

class SupplierInput {
  const SupplierInput({
    required this.orgId,
    required this.name,
    this.taxId,
    this.currency,
    this.paymentTerms,
  });

  final String  orgId;
  final String  name;
  final String? taxId;
  final String? currency;
  final String? paymentTerms;

  Map<String, dynamic> toJson() => {
        'org_id': orgId,
        'name':   name,
        if (taxId        != null) 'tax_id':        taxId,
        if (currency     != null) 'currency':      currency,
        if (paymentTerms != null) 'payment_terms': paymentTerms,
      };

  SupplierInput copyWith({
    String? orgId,
    String? name,
    Object? taxId        = _absent,
    Object? currency     = _absent,
    Object? paymentTerms = _absent,
  }) =>
      SupplierInput(
        orgId:        orgId        ?? this.orgId,
        name:         name         ?? this.name,
        taxId:        identical(taxId,        _absent) ? this.taxId        : taxId        as String?,
        currency:     identical(currency,     _absent) ? this.currency     : currency     as String?,
        paymentTerms: identical(paymentTerms, _absent) ? this.paymentTerms : paymentTerms as String?,
      );
}

const _absent = Object();

extension SupplierToInput on Supplier {
  SupplierInput toInput() => SupplierInput(
        orgId:        orgId,
        name:         name,
        taxId:        taxId,
        currency:     currency,
        paymentTerms: paymentTerms,
      );
}
