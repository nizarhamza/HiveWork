import 'package:flutter/material.dart';

enum CompanyStatus { active, prospect, inactive }

extension CompanyStatusX on CompanyStatus {
  String get label => switch (this) {
        CompanyStatus.active   => 'Active',
        CompanyStatus.prospect => 'Prospect',
        CompanyStatus.inactive => 'Inactive',
      };

  Color get color => switch (this) {
        CompanyStatus.active   => const Color(0xFF4CAF72),
        CompanyStatus.prospect => const Color(0xFFF5A623),
        CompanyStatus.inactive => const Color(0xFF71717A),
      };

  static CompanyStatus fromString(String s) => switch (s) {
        'active'   => CompanyStatus.active,
        'inactive' => CompanyStatus.inactive,
        _          => CompanyStatus.prospect,
      };
}

const kEmployeeRanges = ['1–10', '11–50', '51–200', '201–1,000', '1,000+'];

class Company {
  const Company({
    required this.id,
    required this.orgId,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.industry,
    this.website,
    this.phone,
    this.email,
    this.domain,
    this.employeeRange,
    this.notes,
    this.taxId,
    this.address,
    this.tags = const [],
    this.createdByName,
    this.updatedByName,
    this.customFields = const {},
  });

  final String id;
  final String orgId;
  final String name;
  final CompanyStatus status;
  final String? industry;
  final String? website;
  final String? phone;
  final String? email;
  final String? domain;
  final String? employeeRange;
  final String? notes;
  final String? taxId; // client MF (matricule fiscal), printed on quotes/invoices
  final String? address;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdByName;
  final String? updatedByName;
  final Map<String, dynamic> customFields;

  Color get avatarColor {
    const palette = [
      Color(0xFF5E6AD2),
      Color(0xFF2BA87E),
      Color(0xFFD9730D),
      Color(0xFFC2554D),
      Color(0xFF9D5BD2),
      Color(0xFF3A87C2),
    ];
    final idx =
        int.parse(id.replaceAll('-', '').substring(0, 4), radix: 16) %
            palette.length;
    return palette[idx];
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final updater = json['updater'] as Map<String, dynamic>?;
    return Company(
      id:            json['id'] as String,
      orgId:         json['org_id'] as String,
      name:          json['name'] as String,
      status:        CompanyStatusX.fromString(json['status'] as String? ?? 'prospect'),
      industry:      json['industry'] as String?,
      website:       json['website'] as String?,
      phone:         json['phone'] as String?,
      email:         json['email'] as String?,
      domain:        json['domain'] as String?,
      employeeRange: json['employee_range'] as String?,
      notes:         json['notes'] as String?,
      taxId:         json['tax_id'] as String?,
      address:       json['address'] as String?,
      tags:          (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt:     DateTime.parse(json['created_at'] as String),
      updatedAt:     DateTime.parse(json['updated_at'] as String),
      createdByName: creator?['display_name'] as String?,
      updatedByName: updater?['display_name'] as String?,
      customFields:  (json['custom_fields'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class CompanyInput {
  const CompanyInput({
    required this.orgId,
    required this.name,
    this.status = CompanyStatus.prospect,
    this.industry,
    this.website,
    this.phone,
    this.email,
    this.domain,
    this.employeeRange,
    this.notes,
    this.taxId,
    this.address,
    this.tags = const [],
    this.customFields = const {},
  });

  final String orgId;
  final String name;
  final CompanyStatus status;
  final String? industry;
  final String? website;
  final String? phone;
  final String? email;
  final String? domain;
  final String? employeeRange;
  final String? notes;
  final String? taxId;
  final String? address;
  final List<String> tags;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toJson() => {
        'org_id':        orgId,
        'name':          name,
        'status':        status.name,
        if (industry      != null) 'industry':       industry,
        if (website       != null) 'website':        website,
        if (phone         != null) 'phone':          phone,
        if (email         != null) 'email':          email,
        if (domain        != null) 'domain':         domain,
        if (employeeRange != null) 'employee_range': employeeRange,
        if (notes         != null) 'notes':          notes,
        if (taxId         != null) 'tax_id':         taxId,
        if (address       != null) 'address':        address,
        'tags':          tags,
        'custom_fields': customFields,
      };

  CompanyInput copyWith({
    String? orgId,
    String? name,
    CompanyStatus? status,
    Object? industry      = _absent,
    Object? website       = _absent,
    Object? phone         = _absent,
    Object? email         = _absent,
    Object? domain        = _absent,
    Object? employeeRange = _absent,
    Object? notes         = _absent,
    Object? taxId         = _absent,
    Object? address       = _absent,
    List<String>? tags,
    Map<String, dynamic>? customFields,
  }) =>
      CompanyInput(
        orgId:         orgId         ?? this.orgId,
        name:          name          ?? this.name,
        status:        status        ?? this.status,
        industry:      identical(industry,      _absent) ? this.industry      : industry      as String?,
        website:       identical(website,       _absent) ? this.website       : website       as String?,
        phone:         identical(phone,         _absent) ? this.phone         : phone         as String?,
        email:         identical(email,         _absent) ? this.email         : email         as String?,
        domain:        identical(domain,        _absent) ? this.domain        : domain        as String?,
        employeeRange: identical(employeeRange, _absent) ? this.employeeRange : employeeRange as String?,
        notes:         identical(notes,         _absent) ? this.notes         : notes         as String?,
        taxId:         identical(taxId,         _absent) ? this.taxId         : taxId         as String?,
        address:       identical(address,        _absent) ? this.address      : address       as String?,
        tags:          tags         ?? this.tags,
        customFields:  customFields ?? this.customFields,
      );
}

const _absent = Object();

extension CompanyToInput on Company {
  CompanyInput toInput() => CompanyInput(
        orgId:         orgId,
        name:          name,
        status:        status,
        industry:      industry,
        website:       website,
        phone:         phone,
        email:         email,
        domain:        domain,
        employeeRange: employeeRange,
        notes:         notes,
        taxId:         taxId,
        address:       address,
        tags:          tags,
        customFields:  customFields,
      );
}
