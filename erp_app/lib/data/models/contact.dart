import 'package:flutter/material.dart';

enum ContactStatus { active, lead, inactive }

extension ContactStatusX on ContactStatus {
  String get label => switch (this) {
        ContactStatus.active   => 'Active',
        ContactStatus.lead     => 'Lead',
        ContactStatus.inactive => 'Inactive',
      };

  Color get color => switch (this) {
        ContactStatus.active   => const Color(0xFF4CAF72),
        ContactStatus.lead     => const Color(0xFFF5A623),
        ContactStatus.inactive => const Color(0xFF71717A),
      };

  static ContactStatus fromString(String s) => switch (s) {
        'active'   => ContactStatus.active,
        'inactive' => ContactStatus.inactive,
        _          => ContactStatus.lead,
      };
}

class Contact {
  const Contact({
    required this.id,
    required this.orgId,
    required this.firstName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.companyId,
    this.companyName,
    this.lastName,
    this.email,
    this.phone,
    this.title,
    this.tags = const [],
    this.avatarUrl,
    this.notes,
    this.createdByName,
    this.updatedByName,
    this.customFields = const {},
  });

  final String id;
  final String orgId;
  final String? companyId;
  final String? companyName;   // populated via join on fetch
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? title;
  final ContactStatus status;
  final List<String> tags;
  final String? avatarUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdByName; // populated via profiles join
  final String? updatedByName; // populated via profiles join
  final Map<String, dynamic> customFields;

  String get fullName => [firstName, lastName].whereType<String>().join(' ');

  // Deterministic avatar color derived from the id.
  Color get avatarColor {
    const palette = [
      Color(0xFF5E6AD2),
      Color(0xFF2BA87E),
      Color(0xFFD9730D),
      Color(0xFFC2554D),
      Color(0xFF9D5BD2),
      Color(0xFF3A87C2),
    ];
    final idx = int.parse(id.replaceAll('-', '').substring(0, 4), radix: 16) %
        palette.length;
    return palette[idx];
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    final company = json['companies'] as Map<String, dynamic>?;
    final creator = json['creator']  as Map<String, dynamic>?;
    final updater = json['updater']  as Map<String, dynamic>?;
    return Contact(
      id:            json['id'] as String,
      orgId:         json['org_id'] as String,
      companyId:     json['company_id'] as String?,
      companyName:   company?['name'] as String?,
      firstName:     json['first_name'] as String,
      lastName:      json['last_name'] as String?,
      email:         json['email'] as String?,
      phone:         json['phone'] as String?,
      title:         json['title'] as String?,
      status:        ContactStatusX.fromString(json['status'] as String? ?? 'lead'),
      tags:          (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      avatarUrl:     json['avatar_url'] as String?,
      notes:         json['notes'] as String?,
      createdAt:     DateTime.parse(json['created_at'] as String),
      updatedAt:     DateTime.parse(json['updated_at'] as String),
      createdByName: creator?['display_name'] as String?,
      updatedByName: updater?['display_name'] as String?,
      customFields:  (json['custom_fields'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Payload for create / update operations.
class ContactInput {
  const ContactInput({
    required this.orgId,
    required this.firstName,
    this.companyId,
    this.lastName,
    this.email,
    this.phone,
    this.title,
    this.status = ContactStatus.lead,
    this.tags = const [],
    this.notes,
    this.customFields = const {},
  });

  final String orgId;
  final String? companyId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? title;
  final ContactStatus status;
  final List<String> tags;
  final String? notes;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toJson() => {
        'org_id':        orgId,
        if (companyId != null) 'company_id': companyId,
        'first_name':    firstName,
        if (lastName != null) 'last_name': lastName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (title != null) 'title': title,
        'status':        status.name,
        'tags':          tags,
        if (notes != null) 'notes': notes,
        'custom_fields': customFields,
      };

  ContactInput copyWith({
    String? orgId,
    String? firstName,
    Object? lastName      = _absent,
    Object? email         = _absent,
    Object? phone         = _absent,
    Object? title         = _absent,
    ContactStatus? status,
    List<String>? tags,
    Object? notes         = _absent,
    Object? companyId     = _absent,
    Map<String, dynamic>? customFields,
  }) =>
      ContactInput(
        orgId:        orgId        ?? this.orgId,
        firstName:    firstName    ?? this.firstName,
        lastName:     identical(lastName,   _absent) ? this.lastName   : lastName   as String?,
        email:        identical(email,      _absent) ? this.email      : email      as String?,
        phone:        identical(phone,      _absent) ? this.phone      : phone      as String?,
        title:        identical(title,      _absent) ? this.title      : title      as String?,
        notes:        identical(notes,      _absent) ? this.notes      : notes      as String?,
        companyId:    identical(companyId,  _absent) ? this.companyId  : companyId  as String?,
        status:       status       ?? this.status,
        tags:         tags         ?? this.tags,
        customFields: customFields ?? this.customFields,
      );
}

// Sentinel value for distinguishing "not provided" from null in copyWith.
const _absent = Object();

extension ContactToInput on Contact {
  ContactInput toInput() => ContactInput(
    orgId:        orgId,
    firstName:    firstName,
    lastName:     lastName,
    email:        email,
    phone:        phone,
    title:        title,
    status:       status,
    tags:         tags,
    notes:        notes,
    companyId:    companyId,
    customFields: customFields,
  );
}
