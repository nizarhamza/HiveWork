import 'package:flutter/material.dart';

enum CustomFieldType { text, number, select, boolean }

extension CustomFieldTypeX on CustomFieldType {
  String get label => switch (this) {
        CustomFieldType.text    => 'Text',
        CustomFieldType.number  => 'Number',
        CustomFieldType.select  => 'Select',
        CustomFieldType.boolean => 'True / False',
      };

  IconData get icon => switch (this) {
        CustomFieldType.text    => Icons.text_fields_rounded,
        CustomFieldType.number  => Icons.numbers_rounded,
        CustomFieldType.select  => Icons.list_rounded,
        CustomFieldType.boolean => Icons.toggle_on_outlined,
      };

  static CustomFieldType fromString(String s) => switch (s) {
        'number'  => CustomFieldType.number,
        'select'  => CustomFieldType.select,
        'boolean' => CustomFieldType.boolean,
        _         => CustomFieldType.text,
      };
}

class CustomFieldDef {
  const CustomFieldDef({
    required this.id,
    required this.orgId,
    required this.entityType,
    required this.label,
    required this.fieldKey,
    required this.fieldType,
    this.options   = const [],
    this.isUnique  = false,
    this.sortOrder = 0,
  });

  final String id;
  final String orgId;
  final String entityType; // 'contact' | 'company'
  final String label;
  final String fieldKey;   // snake_case, unique within (org, entityType)
  final CustomFieldType fieldType;
  final List<String> options; // only used when fieldType == select
  final bool isUnique;
  final int  sortOrder;

  factory CustomFieldDef.fromJson(Map<String, dynamic> json) => CustomFieldDef(
        id:         json['id']          as String,
        orgId:      json['org_id']      as String,
        entityType: json['entity_type'] as String,
        label:      json['label']       as String,
        fieldKey:   json['field_key']   as String,
        fieldType:  CustomFieldTypeX.fromString(json['field_type'] as String),
        options:    (json['options'] as List<dynamic>?)?.cast<String>() ?? [],
        isUnique:   json['is_unique']   as bool? ?? false,
        sortOrder:  json['sort_order']  as int?  ?? 0,
      );
}

class CustomFieldDefInput {
  const CustomFieldDefInput({
    required this.orgId,
    required this.entityType,
    required this.label,
    required this.fieldKey,
    required this.fieldType,
    this.options   = const [],
    this.isUnique  = false,
    this.sortOrder = 0,
  });

  final String orgId;
  final String entityType;
  final String label;
  final String fieldKey;
  final CustomFieldType fieldType;
  final List<String> options;
  final bool isUnique;
  final int  sortOrder;

  Map<String, dynamic> toJson() => {
        'org_id':      orgId,
        'entity_type': entityType,
        'label':       label,
        'field_key':   fieldKey,
        'field_type':  fieldType.name,
        'options':     options,
        'is_unique':   isUnique,
        'sort_order':  sortOrder,
      };

  // Derive a safe snake_case key from a user-supplied label.
  static String keyFromLabel(String label) {
    final raw = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return raw.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
