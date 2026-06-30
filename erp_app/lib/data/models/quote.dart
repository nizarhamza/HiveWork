import 'package:flutter/material.dart';

// ── Status ─────────────────────────────────────────────────────────────────────

enum QuoteStatus { draft, sent, approved, rejected, expired, converted }

extension QuoteStatusX on QuoteStatus {
  String get label => switch (this) {
        QuoteStatus.draft     => 'Draft',
        QuoteStatus.sent      => 'Sent',
        QuoteStatus.approved  => 'Approved',
        QuoteStatus.rejected  => 'Rejected',
        QuoteStatus.expired   => 'Expired',
        QuoteStatus.converted => 'Converted',
      };

  Color get color => switch (this) {
        QuoteStatus.draft     => const Color(0xFF71717A),
        QuoteStatus.sent      => const Color(0xFF3A87C2),
        QuoteStatus.approved  => const Color(0xFF4CAF72),
        QuoteStatus.rejected  => const Color(0xFFC2554D),
        QuoteStatus.expired   => const Color(0xFFF5A623),
        QuoteStatus.converted => const Color(0xFF9D5BD2),
      };

  static QuoteStatus fromString(String s) => switch (s) {
        'sent'      => QuoteStatus.sent,
        'approved'  => QuoteStatus.approved,
        'rejected'  => QuoteStatus.rejected,
        'expired'   => QuoteStatus.expired,
        'converted' => QuoteStatus.converted,
        _           => QuoteStatus.draft,
      };
}

// ── Line item (read model) ─────────────────────────────────────────────────────

class QuoteLine {
  const QuoteLine({
    required this.id,
    required this.orgId,
    required this.quoteId,
    required this.label,
    required this.qty,
    required this.unitPrice,
    required this.taxRate,
    required this.lineTotal,
    required this.position,
    this.discountRate = 0.0,
    this.productId,
    this.parentId,
    this.unit,
    this.fodecApplicable = false,
  });

  final String  id;
  final String  orgId;
  final String  quoteId;
  final String? productId;
  final String? parentId; // self-reference: null = top-level row
  final String  label;
  final String? unit;
  final double  qty;
  final double  unitPrice;
  final double  taxRate;
  final double  discountRate;
  final double  lineTotal;
  final int     position;
  final bool    fodecApplicable;

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        id:              json['id']               as String,
        orgId:           json['org_id']           as String,
        quoteId:         json['quote_id']         as String,
        productId:       json['product_id']       as String?,
        parentId:        json['parent_id']        as String?,
        label:           json['label']            as String,
        unit:            json['unit']             as String?,
        qty:             (json['qty']              as num).toDouble(),
        unitPrice:       (json['unit_price']       as num).toDouble(),
        taxRate:         (json['tax_rate']         as num).toDouble(),
        discountRate:    (json['discount_rate']    as num? ?? 0).toDouble(),
        lineTotal:       (json['line_total']       as num).toDouble(),
        position:        json['position']          as int,
        fodecApplicable: json['fodec_applicable']  as bool? ?? false,
      );
}

// ── Line input (write model) ───────────────────────────────────────────────────

class QuoteLineInput {
  const QuoteLineInput({
    required this.label,
    required this.qty,
    required this.unitPrice,
    required this.position,
    this.taxRate         = 0.0,
    this.discountRate    = 0.0,
    this.productId,
    this.unit,
    this.fodecApplicable = false,
    this.level           = 0,
  });

  final String? productId;
  final String  label;
  final String? unit;
  final double  qty;
  final double  unitPrice;
  final double  taxRate;
  final double  discountRate;
  final int     position;
  final bool    fodecApplicable;

  /// Nesting depth in the category/sub-category/detail outline (0 = top
  /// level). Lines are saved in order; a line's parent is resolved as the
  /// nearest preceding line with `level == this.level - 1` (outline-style
  /// indent, like the OBAT template's 1 / 1.1 / 1.1.1 numbering).
  final int level;

  double get lineTotal => qty * unitPrice * (1 - discountRate / 100);
  double get taxAmount => lineTotal * taxRate / 100;

  /// [parentId] is the *real* DB id of this line's parent, resolved by the
  /// repository from [level] right before insert (rows must be inserted
  /// parent-first to satisfy the FK).
  Map<String, dynamic> toJson(String orgId, String quoteId, {String? parentId}) => {
        'org_id':            orgId,
        'quote_id':          quoteId,
        'label':             label,
        'qty':               qty,
        'unit_price':        unitPrice,
        'tax_rate':          taxRate,
        'discount_rate':     discountRate,
        'line_total':        lineTotal,
        'position':          position,
        'fodec_applicable':  fodecApplicable,
        if (unit      != null) 'unit':       unit,
        if (productId != null) 'product_id': productId,
        // ignore: use_null_aware_elements
        if (parentId  != null) 'parent_id':  parentId,
      };

  QuoteLineInput copyWith({
    String? label,
    double? qty,
    double? unitPrice,
    double? taxRate,
    double? discountRate,
    int?    position,
    Object? unit            = _absent,
    bool?   fodecApplicable,
    int?    level,
  }) =>
      QuoteLineInput(
        label:           label           ?? this.label,
        qty:             qty             ?? this.qty,
        unitPrice:       unitPrice       ?? this.unitPrice,
        taxRate:         taxRate         ?? this.taxRate,
        discountRate:    discountRate    ?? this.discountRate,
        position:        position        ?? this.position,
        unit:            identical(unit, _absent) ? this.unit : unit as String?,
        fodecApplicable: fodecApplicable ?? this.fodecApplicable,
        level:           level           ?? this.level,
        productId:       productId,
      );
}

// ── Quote (read model) ─────────────────────────────────────────────────────────

class Quote {
  const Quote({
    required this.id,
    required this.orgId,
    required this.number,
    required this.currency,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.clientId,
    this.clientSnapshot,
    this.validUntil,
    this.convertedInvoiceId,
    this.notes,
    this.lines = const [],
    this.objet,
    this.contractNumber,
    this.paymentMode,
    this.paymentTermTemplateId,
    this.paymentTermSnapshot,
    this.fodecEnabled  = false,
    this.fodecRate     = 1.0,
    this.timbreEnabled = false,
    this.timbreAmount  = 1.0,
    this.rsEnabled     = false,
    this.rsRate        = 3.0,
  });

  final String      id;
  final String      orgId;
  final String      number;
  final String?     clientId;
  final Map<String, dynamic>? clientSnapshot;
  final String      currency;
  final double      subtotal;
  final double      tax;
  final double      total;
  final DateTime?   validUntil;
  final QuoteStatus status;
  final String?     convertedInvoiceId;
  final String?     notes;
  final DateTime    createdAt;
  final DateTime    updatedAt;
  final List<QuoteLine> lines;

  // ── Document fields (Tunisian "facture/devis" format) ────────────────────────
  final String? objet;           // subject / chantier / mission line
  final String? contractNumber;
  final String? paymentMode;     // display name (kept for backwards compat)
  final String? paymentTermTemplateId;
  final List<Map<String, dynamic>>? paymentTermSnapshot; // installments snapshot
  final bool    fodecEnabled;
  final double  fodecRate;       // % — applies to fodec-flagged lines
  final bool    timbreEnabled;
  final double  timbreAmount;    // flat amount added to TTC
  final bool    rsEnabled;
  final double  rsRate;          // % — retenue à la source, deducted from TTC

  String? get clientSnapshotName    => clientSnapshot?['name']    as String?;
  String? get clientSnapshotAddress => clientSnapshot?['address'] as String?;
  String? get clientSnapshotPhone   => clientSnapshot?['phone']   as String?;
  String? get clientSnapshotTaxId   => clientSnapshot?['tax_id']  as String?;

  String get displayTotal {
    final sym = _sym(currency);
    if (total == total.truncateToDouble()) return '$sym${total.toInt()}';
    return '$sym${total.toStringAsFixed(2)}';
  }

  String displayAmount(double v) {
    final sym = _sym(currency);
    if (v == v.truncateToDouble()) return '$sym${v.toInt()}';
    return '$sym${v.toStringAsFixed(2)}';
  }

  static String _sym(String code) => switch (code.toUpperCase()) {
        'EUR' => '€',
        'USD' => '\$',
        'GBP' => '£',
        _     => '$code ',
      };

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        id:                 json['id']                    as String,
        orgId:              json['org_id']                as String,
        number:             json['number']                as String,
        clientId:           json['client_id']             as String?,
        clientSnapshot:     json['client_snapshot']       as Map<String, dynamic>?,
        currency:           json['currency']              as String? ?? 'EUR',
        subtotal:           (json['subtotal']             as num? ?? 0).toDouble(),
        tax:                (json['tax']                  as num? ?? 0).toDouble(),
        total:              (json['total']                as num? ?? 0).toDouble(),
        validUntil: json['valid_until'] != null
            ? DateTime.parse(json['valid_until'] as String)
            : null,
        status: QuoteStatusX.fromString(json['status'] as String? ?? 'draft'),
        convertedInvoiceId: json['converted_invoice_id'] as String?,
        notes:    json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        objet:           json['objet']            as String?,
        contractNumber:  json['contract_number']   as String?,
        paymentMode:     json['payment_mode']      as String?,
        paymentTermTemplateId: json['payment_term_template_id'] as String?,
        paymentTermSnapshot: (json['payment_term_snapshot'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        fodecEnabled:    json['fodec_enabled']     as bool?   ?? false,
        fodecRate:       (json['fodec_rate']       as num?    ?? 1).toDouble(),
        timbreEnabled:   json['timbre_enabled']    as bool?   ?? false,
        timbreAmount:    (json['timbre_amount']    as num?    ?? 1).toDouble(),
        rsEnabled:       json['rs_enabled']        as bool?   ?? false,
        rsRate:          (json['rs_rate']          as num?    ?? 3).toDouble(),
      );

  Quote copyWith({List<QuoteLine>? lines}) => Quote(
        id:                 id,
        orgId:              orgId,
        number:             number,
        clientId:           clientId,
        clientSnapshot:     clientSnapshot,
        currency:           currency,
        subtotal:           subtotal,
        tax:                tax,
        total:              total,
        validUntil:         validUntil,
        status:             status,
        convertedInvoiceId: convertedInvoiceId,
        notes:              notes,
        createdAt:          createdAt,
        updatedAt:          updatedAt,
        lines:              lines ?? this.lines,
        objet:              objet,
        contractNumber:     contractNumber,
        paymentMode:            paymentMode,
        paymentTermTemplateId:  paymentTermTemplateId,
        paymentTermSnapshot:    paymentTermSnapshot,
        fodecEnabled:       fodecEnabled,
        fodecRate:          fodecRate,
        timbreEnabled:      timbreEnabled,
        timbreAmount:       timbreAmount,
        rsEnabled:          rsEnabled,
        rsRate:             rsRate,
      );
}

// ── QuoteInput (write model) ───────────────────────────────────────────────────

class QuoteInput {
  const QuoteInput({
    required this.orgId,
    required this.lines,
    this.clientId,
    this.clientName,
    this.clientAddress,
    this.clientPhone,
    this.clientTaxId,
    this.currency   = 'USD',
    this.status     = QuoteStatus.draft,
    this.validUntil,
    this.notes,
    this.objet,
    this.contractNumber,
    this.paymentMode,
    this.paymentTermTemplateId,
    this.paymentTermSnapshot,
    this.fodecEnabled  = false,
    this.fodecRate     = 1.0,
    this.timbreEnabled = false,
    this.timbreAmount  = 1.0,
    this.rsEnabled     = false,
    this.rsRate        = 3.0,
  });

  final String          orgId;
  final String?         clientId;
  final String?         clientName;
  final String?         clientAddress;
  final String?         clientPhone;
  final String?         clientTaxId;
  final List<QuoteLineInput> lines;
  final String          currency;
  final QuoteStatus     status;
  final DateTime?       validUntil;
  final String?         notes;

  final String? objet;
  final String? contractNumber;
  final String? paymentMode;
  final String? paymentTermTemplateId;
  final List<Map<String, dynamic>>? paymentTermSnapshot;
  final bool    fodecEnabled;
  final double  fodecRate;
  final bool    timbreEnabled;
  final double  timbreAmount;
  final bool    rsEnabled;
  final double  rsRate;

  double get subtotal => lines.fold(0.0, (s, l) => s + l.lineTotal);
  double get tax      => lines.fold(0.0, (s, l) => s + l.taxAmount);

  /// FODEC base for fodec-flagged lines (added to the TVA base, per the
  /// "Base TVA = HT + FODEC" rule).
  double get fodecAmount => fodecEnabled
      ? lines.where((l) => l.fodecApplicable).fold(0.0, (s, l) => s + l.lineTotal) *
          fodecRate /
          100
      : 0.0;

  double get total => subtotal + tax;

  /// TTC = HT + FODEC's own TVA effect is already inside [tax] only if the
  /// caller recomputed tax on (HT+FODEC); to keep the simple per-line tax
  /// model intact, FODEC is shown as its own totals-column line and added
  /// to TTC directly (matches the OBAT template's totals breakdown).
  double get totalTtc => subtotal + fodecAmount + tax;

  double get timbre => timbreEnabled ? timbreAmount : 0.0;

  double get rsAmount => rsEnabled ? totalTtc * rsRate / 100 : 0.0;

  double get netToPay => totalTtc + timbre - rsAmount;

  /// TVA grouped by rate, for the "récapitulatif des taxes" table.
  Map<double, ({double base, double amount})> get tvaByRate {
    final out = <double, ({double base, double amount})>{};
    for (final l in lines) {
      if (l.taxRate <= 0) continue;
      final base = l.lineTotal + (fodecEnabled && l.fodecApplicable ? l.lineTotal * fodecRate / 100 : 0.0);
      final amt  = base * l.taxRate / 100;
      final prev = out[l.taxRate];
      out[l.taxRate] = (
        base:   (prev?.base   ?? 0) + base,
        amount: (prev?.amount ?? 0) + amt,
      );
    }
    return out;
  }

  Map<String, dynamic> toQuoteJson() => {
        'org_id':   orgId,
        'currency': currency,
        'status':   status.name,
        'subtotal': subtotal,
        'tax':      tax,
        'total':    total,
        if (clientId != null) 'client_id': clientId,
        if (clientName != null)
          'client_snapshot': {
            'name':    clientName,
            if (clientAddress != null) 'address': clientAddress,
            if (clientPhone   != null) 'phone':   clientPhone,
            if (clientTaxId   != null) 'tax_id':  clientTaxId,
          },
        if (validUntil != null)
          'valid_until': validUntil!.toIso8601String().split('T').first,
        if (notes != null) 'notes': notes,
        if (objet                 != null) 'objet':                    objet,
        if (contractNumber        != null) 'contract_number':          contractNumber,
        if (paymentMode           != null) 'payment_mode':             paymentMode,
        if (paymentTermTemplateId != null) 'payment_term_template_id': paymentTermTemplateId,
        if (paymentTermSnapshot   != null) 'payment_term_snapshot':    paymentTermSnapshot,
        'fodec_enabled':  fodecEnabled,
        'fodec_rate':     fodecRate,
        'timbre_enabled': timbreEnabled,
        'timbre_amount':  timbreAmount,
        'rs_enabled':     rsEnabled,
        'rs_rate':        rsRate,
      };

  QuoteInput copyWith({
    String?           orgId,
    Object?           clientId      = _absent,
    Object?           clientName    = _absent,
    Object?           clientAddress = _absent,
    Object?           clientPhone   = _absent,
    Object?           clientTaxId   = _absent,
    List<QuoteLineInput>? lines,
    String?           currency,
    QuoteStatus?      status,
    Object?           validUntil             = _absent,
    Object?           notes                  = _absent,
    Object?           objet                  = _absent,
    Object?           contractNumber         = _absent,
    Object?           paymentMode            = _absent,
    Object?           paymentTermTemplateId  = _absent,
    Object?           paymentTermSnapshot    = _absent,
    bool?             fodecEnabled,
    double?           fodecRate,
    bool?             timbreEnabled,
    double?           timbreAmount,
    bool?             rsEnabled,
    double?           rsRate,
  }) =>
      QuoteInput(
        orgId:         orgId         ?? this.orgId,
        clientId:      identical(clientId,      _absent) ? this.clientId      : clientId      as String?,
        clientName:    identical(clientName,    _absent) ? this.clientName    : clientName    as String?,
        clientAddress: identical(clientAddress, _absent) ? this.clientAddress : clientAddress as String?,
        clientPhone:   identical(clientPhone,   _absent) ? this.clientPhone   : clientPhone   as String?,
        clientTaxId:   identical(clientTaxId,   _absent) ? this.clientTaxId   : clientTaxId   as String?,
        lines:         lines         ?? this.lines,
        currency:      currency      ?? this.currency,
        status:        status        ?? this.status,
        validUntil:    identical(validUntil, _absent) ? this.validUntil : validUntil as DateTime?,
        notes:         identical(notes,      _absent) ? this.notes      : notes      as String?,
        objet:               identical(objet,                 _absent) ? this.objet               : objet               as String?,
        contractNumber:      identical(contractNumber,        _absent) ? this.contractNumber      : contractNumber      as String?,
        paymentMode:         identical(paymentMode,           _absent) ? this.paymentMode          : paymentMode          as String?,
        paymentTermTemplateId: identical(paymentTermTemplateId, _absent) ? this.paymentTermTemplateId : paymentTermTemplateId as String?,
        paymentTermSnapshot:   identical(paymentTermSnapshot,   _absent) ? this.paymentTermSnapshot   : paymentTermSnapshot   as List<Map<String, dynamic>>?,
        fodecEnabled:  fodecEnabled  ?? this.fodecEnabled,
        fodecRate:     fodecRate     ?? this.fodecRate,
        timbreEnabled: timbreEnabled ?? this.timbreEnabled,
        timbreAmount:  timbreAmount  ?? this.timbreAmount,
        rsEnabled:     rsEnabled     ?? this.rsEnabled,
        rsRate:        rsRate        ?? this.rsRate,
      );
}

const _absent = Object();

extension QuoteToInput on Quote {
  QuoteInput toInput() => QuoteInput(
        orgId:         orgId,
        clientId:      clientId,
        clientName:    clientSnapshotName,
        clientAddress: clientSnapshotAddress,
        clientPhone:   clientSnapshotPhone,
        clientTaxId:   clientSnapshotTaxId,
        currency:      currency,
        status:        status,
        validUntil:    validUntil,
        notes:         notes,
        objet:                 objet,
        contractNumber:        contractNumber,
        paymentMode:           paymentMode,
        paymentTermTemplateId: paymentTermTemplateId,
        paymentTermSnapshot:   paymentTermSnapshot,
        fodecEnabled:    fodecEnabled,
        fodecRate:       fodecRate,
        timbreEnabled:   timbreEnabled,
        timbreAmount:    timbreAmount,
        rsEnabled:       rsEnabled,
        rsRate:          rsRate,
        lines: _flattenForEdit(lines),
      );
}

/// Walks the persisted parent/child line tree (pre-order) and converts it
/// back into the flat, level-tagged list the editor works with.
List<QuoteLineInput> _flattenForEdit(List<QuoteLine> lines) {
  final byParent = <String?, List<QuoteLine>>{};
  for (final l in lines) {
    byParent.putIfAbsent(l.parentId, () => []).add(l);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.position.compareTo(b.position));
  }
  final out = <QuoteLineInput>[];
  void walk(QuoteLine l, int depth) {
    out.add(QuoteLineInput(
      label:           l.label,
      qty:             l.qty,
      unitPrice:       l.unitPrice,
      taxRate:         l.taxRate,
      discountRate:    l.discountRate,
      position:        out.length,
      productId:       l.productId,
      unit:            l.unit,
      fodecApplicable: l.fodecApplicable,
      level:           depth,
    ));
    for (final child in byParent[l.id] ?? const <QuoteLine>[]) {
      walk(child, depth + 1);
    }
  }
  for (final root in byParent[null] ?? const <QuoteLine>[]) {
    walk(root, 0);
  }
  return out;
}

/// Tax/total computations shared by the PDF and detail view, mirroring
/// the equivalent getters on [QuoteInput] but operating on the persisted
/// [Quote.lines] (read model) instead of the editor's write model.
extension QuoteTotals on Quote {
  double get fodecAmount => fodecEnabled
      ? lines.where((l) => l.fodecApplicable).fold(0.0, (s, l) => s + l.lineTotal) *
          fodecRate /
          100
      : 0.0;

  double get totalTtc => subtotal + fodecAmount + tax;

  double get timbre => timbreEnabled ? timbreAmount : 0.0;

  double get rsAmount => rsEnabled ? totalTtc * rsRate / 100 : 0.0;

  double get netToPay => totalTtc + timbre - rsAmount;

  /// TVA grouped by rate, for the "récapitulatif des taxes" table.
  Map<double, ({double base, double amount})> get tvaByRate {
    final out = <double, ({double base, double amount})>{};
    for (final l in lines) {
      if (l.taxRate <= 0) continue;
      final base = l.lineTotal +
          (fodecEnabled && l.fodecApplicable ? l.lineTotal * fodecRate / 100 : 0.0);
      final amt  = base * l.taxRate / 100;
      final prev = out[l.taxRate];
      out[l.taxRate] = (
        base:   (prev?.base   ?? 0) + base,
        amount: (prev?.amount ?? 0) + amt,
      );
    }
    return out;
  }
}

// ── QuoteWithClient (list-view join model) ─────────────────────────────────────

class QuoteWithClient {
  const QuoteWithClient({
    required this.quote,
    this.clientName,
  });

  final Quote   quote;
  final String? clientName;

  factory QuoteWithClient.fromJson(Map<String, dynamic> json) {
    final clientRow = json['clients'] as Map<String, dynamic>?;
    final quote     = Quote.fromJson(json);
    return QuoteWithClient(
      quote:      quote,
      clientName: clientRow?['name'] as String? ?? quote.clientSnapshotName,
    );
  }
}
