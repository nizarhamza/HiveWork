import 'package:flutter/material.dart';

enum DealStage { lead, qualified, proposal, negotiation, won, lost }

extension DealStageX on DealStage {
  String get label => switch (this) {
        DealStage.lead        => 'Lead',
        DealStage.qualified   => 'Qualified',
        DealStage.proposal    => 'Proposal',
        DealStage.negotiation => 'Negotiation',
        DealStage.won         => 'Won',
        DealStage.lost        => 'Lost',
      };

  Color get color => switch (this) {
        DealStage.lead        => const Color(0xFF71717A),
        DealStage.qualified   => const Color(0xFF3A87C2),
        DealStage.proposal    => const Color(0xFF9D5BD2),
        DealStage.negotiation => const Color(0xFFF5A623),
        DealStage.won         => const Color(0xFF4CAF72),
        DealStage.lost        => const Color(0xFFC2554D),
      };

  bool get isTerminal => this == DealStage.won || this == DealStage.lost;

  static DealStage fromString(String s) {
    return DealStage.values.firstWhere(
      (e) => e.name == s,
      orElse: () => DealStage.lead,
    );
  }
}

class Deal {
  const Deal({
    required this.id,
    required this.orgId,
    required this.title,
    required this.value,
    required this.currency,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    this.contactId,
    this.contactName,
    this.companyId,
    this.companyName,
    this.probability,
    this.closeDate,
    this.ownerId,
    this.ownerName,
    this.notes,
    this.createdByName,
    this.quoteId,
    this.quoteTotal,
    this.quoteCurrency,
  });

  final String    id;
  final String    orgId;
  final String    title;
  final double    value;
  final String    currency;
  final DealStage stage;
  final String?   contactId;
  final String?   contactName;
  final String?   companyId;
  final String?   companyName;
  final int?      probability;
  final DateTime? closeDate;
  final String?   ownerId;
  final String?   ownerName;
  final String?   notes;
  final String?   createdByName;
  final DateTime  createdAt;
  final DateTime  updatedAt;
  final String?   quoteId;
  final double?   quoteTotal;
  final String?   quoteCurrency;

  String get displayValue {
    // Prefer quote total; fall back to manually-set value.
    final amount = quoteTotal ?? (value > 0 ? value : null);
    if (amount == null) return '—';
    final curr = quoteTotal != null ? (quoteCurrency ?? currency) : currency;
    final sym  = _currencySymbol(curr);
    if (amount == amount.truncateToDouble()) return '$sym${amount.toInt()}';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  static String _currencySymbol(String code) => switch (code.toUpperCase()) {
        'EUR' => '€',
        'USD' => '\$',
        'GBP' => '£',
        _     => '$code ',
      };

  factory Deal.fromJson(Map<String, dynamic> json) {
    final contact = json['contacts'] as Map<String, dynamic>?;
    final company = json['companies'] as Map<String, dynamic>?;
    final owner   = json['owner'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>?;

    String? contactName;
    if (contact != null) {
      final first = contact['first_name'] as String? ?? '';
      final last  = contact['last_name']  as String? ?? '';
      contactName = '$first $last'.trim().isEmpty ? null : '$first $last'.trim();
    }

    return Deal(
      id:            json['id'] as String,
      orgId:         json['org_id'] as String,
      title:         json['title'] as String,
      value:         (json['value'] as num).toDouble(),
      currency:      json['currency'] as String? ?? 'EUR',
      stage:         DealStageX.fromString(json['stage'] as String? ?? 'lead'),
      contactId:     json['contact_id'] as String?,
      contactName:   contactName,
      companyId:     json['company_id'] as String?,
      companyName:   company?['name'] as String?,
      probability:   json['probability'] as int?,
      closeDate:     json['close_date'] != null
          ? DateTime.parse(json['close_date'] as String)
          : null,
      ownerId:       json['owner_id'] as String?,
      ownerName:     owner?['display_name'] as String?,
      notes:         json['notes'] as String?,
      createdByName: creator?['display_name'] as String?,
      createdAt:     DateTime.parse(json['created_at'] as String),
      updatedAt:     DateTime.parse(json['updated_at'] as String),
      quoteId:       json['quote_id']       as String?,
      quoteTotal:    (json['quote_total']   as num?)?.toDouble(),
      quoteCurrency: json['quote_currency'] as String?,
    );
  }
}

class DealInput {
  const DealInput({
    required this.orgId,
    required this.title,
    this.value = 0,
    this.currency = 'EUR',
    this.stage = DealStage.lead,
    this.contactId,
    this.companyId,
    this.probability,
    this.closeDate,
    this.ownerId,
    this.notes,
    this.quoteId,
    this.quoteTotal,
    this.quoteCurrency,
  });

  final String    orgId;
  final String    title;
  final double    value;
  final String    currency;
  final DealStage stage;
  final String?   contactId;
  final String?   companyId;
  final int?      probability;
  final DateTime? closeDate;
  final String?   ownerId;
  final String?   notes;
  final String?   quoteId;
  final double?   quoteTotal;
  final String?   quoteCurrency;

  Map<String, dynamic> toJson() => {
        'org_id':   orgId,
        'title':    title,
        'value':    quoteTotal ?? value,
        'currency': quoteCurrency ?? currency,
        'stage':    stage.name,
        if (contactId     != null) 'contact_id':    contactId,
        if (companyId     != null) 'company_id':    companyId,
        if (probability   != null) 'probability':   probability,
        if (closeDate     != null) 'close_date':    closeDate!.toIso8601String().substring(0, 10),
        if (ownerId       != null) 'owner_id':      ownerId,
        if (notes         != null) 'notes':         notes,
        if (quoteId       != null) 'quote_id':      quoteId,
        if (quoteTotal    != null) 'quote_total':   quoteTotal,
        if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      };

  DealInput copyWith({
    String?    orgId,
    String?    title,
    double?    value,
    String?    currency,
    DealStage? stage,
    Object?    contactId     = _absent,
    Object?    companyId     = _absent,
    Object?    probability   = _absent,
    Object?    closeDate     = _absent,
    Object?    ownerId       = _absent,
    Object?    notes         = _absent,
    Object?    quoteId       = _absent,
    Object?    quoteTotal    = _absent,
    Object?    quoteCurrency = _absent,
  }) =>
      DealInput(
        orgId:         orgId      ?? this.orgId,
        title:         title      ?? this.title,
        value:         value      ?? this.value,
        currency:      currency   ?? this.currency,
        stage:         stage      ?? this.stage,
        contactId:     identical(contactId,     _absent) ? this.contactId     : contactId     as String?,
        companyId:     identical(companyId,     _absent) ? this.companyId     : companyId     as String?,
        probability:   identical(probability,   _absent) ? this.probability   : probability   as int?,
        closeDate:     identical(closeDate,     _absent) ? this.closeDate     : closeDate     as DateTime?,
        ownerId:       identical(ownerId,       _absent) ? this.ownerId       : ownerId       as String?,
        notes:         identical(notes,         _absent) ? this.notes         : notes         as String?,
        quoteId:       identical(quoteId,       _absent) ? this.quoteId       : quoteId       as String?,
        quoteTotal:    identical(quoteTotal,    _absent) ? this.quoteTotal    : quoteTotal    as double?,
        quoteCurrency: identical(quoteCurrency, _absent) ? this.quoteCurrency : quoteCurrency as String?,
      );
}

const _absent = Object();

extension DealToInput on Deal {
  DealInput toInput() => DealInput(
        orgId:         orgId,
        title:         title,
        value:         value,
        currency:      currency,
        stage:         stage,
        contactId:     contactId,
        companyId:     companyId,
        probability:   probability,
        closeDate:     closeDate,
        ownerId:       ownerId,
        notes:         notes,
        quoteId:       quoteId,
        quoteTotal:    quoteTotal,
        quoteCurrency: quoteCurrency,
      );
}
