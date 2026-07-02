import 'package:flutter/material.dart';

// ── Status ─────────────────────────────────────────────────────────────────────

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }

extension InvoiceStatusX on InvoiceStatus {
  String get label => switch (this) {
        InvoiceStatus.draft     => 'Draft',
        InvoiceStatus.sent      => 'Sent',
        InvoiceStatus.paid      => 'Paid',
        InvoiceStatus.overdue   => 'Overdue',
        InvoiceStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        InvoiceStatus.draft     => const Color(0xFF71717A),
        InvoiceStatus.sent      => const Color(0xFF3A87C2),
        InvoiceStatus.paid      => const Color(0xFF4CAF72),
        InvoiceStatus.overdue   => const Color(0xFFC2554D),
        InvoiceStatus.cancelled => const Color(0xFF9D5BD2),
      };

  static InvoiceStatus fromString(String s) => switch (s) {
        'sent'      => InvoiceStatus.sent,
        'paid'      => InvoiceStatus.paid,
        'overdue'   => InvoiceStatus.overdue,
        'cancelled' => InvoiceStatus.cancelled,
        _           => InvoiceStatus.draft,
      };
}

// ── Line item (read model) ─────────────────────────────────────────────────────

class InvoiceLine {
  const InvoiceLine({
    required this.id,
    required this.orgId,
    required this.invoiceId,
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
  final String  invoiceId;
  final String? productId;
  final String? parentId;
  final String  label;
  final String? unit;
  final double  qty;
  final double  unitPrice;
  final double  taxRate;
  final double  discountRate;
  final double  lineTotal;
  final int     position;
  final bool    fodecApplicable;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => InvoiceLine(
        id:              json['id']               as String,
        orgId:           json['org_id']           as String,
        invoiceId:       json['invoice_id']       as String,
        productId:       json['product_id']       as String?,
        parentId:        json['parent_id']        as String?,
        label:           json['label']            as String,
        unit:            json['unit']             as String?,
        qty:             (json['qty']             as num).toDouble(),
        unitPrice:       (json['unit_price']      as num).toDouble(),
        taxRate:         (json['tax_rate']        as num).toDouble(),
        discountRate:    (json['discount_rate']   as num? ?? 0).toDouble(),
        lineTotal:       (json['line_total']      as num).toDouble(),
        position:        json['position']         as int,
        fodecApplicable: json['fodec_applicable'] as bool? ?? false,
      );
}

// ── Line input (write model) ───────────────────────────────────────────────────

class InvoiceLineInput {
  const InvoiceLineInput({
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
  final int     level;

  double get lineTotal => qty * unitPrice * (1 - discountRate / 100);
  double get taxAmount => lineTotal * taxRate / 100;

  Map<String, dynamic> toJson(String orgId, String invoiceId, {String? parentId}) => {
        'org_id':           orgId,
        'invoice_id':       invoiceId,
        'label':            label,
        'qty':              qty,
        'unit_price':       unitPrice,
        'tax_rate':         taxRate,
        'discount_rate':    discountRate,
        'line_total':       lineTotal,
        'position':         position,
        'fodec_applicable': fodecApplicable,
        if (unit      != null) 'unit':       unit,
        if (productId != null) 'product_id': productId,
        // ignore: use_null_aware_elements
        if (parentId  != null) 'parent_id':  parentId,
      };

  InvoiceLineInput copyWith({
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
      InvoiceLineInput(
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

// ── Invoice (read model) ───────────────────────────────────────────────────────

class Invoice {
  const Invoice({
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
    this.companyId,
    this.contactId,
    this.clientSnapshot,
    this.quoteId,
    this.issueDate,
    this.dueDate,
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
  final String?     companyId;
  final String?     contactId;
  final Map<String, dynamic>? clientSnapshot;
  final String?     quoteId;
  final String      currency;
  final double      subtotal;
  final double      tax;
  final double      total;
  final DateTime?   issueDate;
  final DateTime?   dueDate;
  final InvoiceStatus status;
  final String?     notes;
  final DateTime    createdAt;
  final DateTime    updatedAt;
  final List<InvoiceLine> lines;

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

  String? get clientSnapshotName    => clientSnapshot?['name']    as String?;
  String? get clientSnapshotAddress => clientSnapshot?['address'] as String?;
  String? get clientSnapshotPhone   => clientSnapshot?['phone']   as String?;
  String? get clientSnapshotTaxId   => clientSnapshot?['tax_id']  as String?;
  Map<String, dynamic> get clientSnapshotCustomFields =>
      (clientSnapshot?['custom_fields'] as Map<String, dynamic>?) ?? {};

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

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id:             json['id']                  as String,
        orgId:          json['org_id']              as String,
        number:         json['number']              as String,
        companyId:      json['company_id']          as String?,
        contactId:      json['contact_id']          as String?,
        clientSnapshot: json['client_snapshot']     as Map<String, dynamic>?,
        quoteId:        json['quote_id']            as String?,
        currency:       json['currency']            as String? ?? 'TND',
        subtotal:       (json['subtotal']           as num? ?? 0).toDouble(),
        tax:            (json['tax']                as num? ?? 0).toDouble(),
        total:          (json['total']              as num? ?? 0).toDouble(),
        issueDate: json['issue_date'] != null
            ? DateTime.parse(json['issue_date'] as String)
            : null,
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        status: InvoiceStatusX.fromString(json['status'] as String? ?? 'draft'),
        notes:  json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        objet:          json['objet']           as String?,
        contractNumber: json['contract_number'] as String?,
        paymentMode:    json['payment_mode']    as String?,
        paymentTermTemplateId: json['payment_term_template_id'] as String?,
        paymentTermSnapshot: (json['payment_term_snapshot'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        fodecEnabled:    json['fodec_enabled']  as bool?   ?? false,
        fodecRate:       (json['fodec_rate']    as num?    ?? 1).toDouble(),
        timbreEnabled:   json['timbre_enabled'] as bool?   ?? false,
        timbreAmount:    (json['timbre_amount'] as num?    ?? 1).toDouble(),
        rsEnabled:       json['rs_enabled']     as bool?   ?? false,
        rsRate:          (json['rs_rate']       as num?    ?? 3).toDouble(),
      );

  Invoice copyWith({List<InvoiceLine>? lines}) => Invoice(
        id:             id,
        orgId:          orgId,
        number:         number,
        companyId:      companyId,
        contactId:      contactId,
        clientSnapshot: clientSnapshot,
        quoteId:        quoteId,
        currency:       currency,
        subtotal:       subtotal,
        tax:            tax,
        total:          total,
        issueDate:      issueDate,
        dueDate:        dueDate,
        status:         status,
        notes:          notes,
        createdAt:      createdAt,
        updatedAt:      updatedAt,
        lines:          lines ?? this.lines,
        objet:               objet,
        contractNumber:      contractNumber,
        paymentMode:         paymentMode,
        paymentTermTemplateId: paymentTermTemplateId,
        paymentTermSnapshot:   paymentTermSnapshot,
        fodecEnabled:    fodecEnabled,
        fodecRate:       fodecRate,
        timbreEnabled:   timbreEnabled,
        timbreAmount:    timbreAmount,
        rsEnabled:       rsEnabled,
        rsRate:          rsRate,
      );
}

// ── InvoiceInput (write model) ─────────────────────────────────────────────────

class InvoiceInput {
  const InvoiceInput({
    required this.orgId,
    required this.lines,
    this.companyId,
    this.contactId,
    this.clientName,
    this.clientAddress,
    this.clientPhone,
    this.clientTaxId,
    this.clientCustomFields,
    this.quoteId,
    this.currency   = 'TND',
    this.status     = InvoiceStatus.draft,
    this.issueDate,
    this.dueDate,
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
  final String?         companyId;
  final String?         contactId;
  final String?         clientName;
  final String?         clientAddress;
  final String?         clientPhone;
  final String?         clientTaxId;
  final Map<String, dynamic>? clientCustomFields;
  final String?         quoteId;
  final List<InvoiceLineInput> lines;
  final String          currency;
  final InvoiceStatus   status;
  final DateTime?       issueDate;
  final DateTime?       dueDate;
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

  double get fodecAmount => fodecEnabled
      ? lines.where((l) => l.fodecApplicable).fold(0.0, (s, l) => s + l.lineTotal) *
          fodecRate /
          100
      : 0.0;

  double get total    => subtotal + tax;
  double get totalTtc => subtotal + fodecAmount + tax;
  double get timbre   => timbreEnabled ? timbreAmount : 0.0;
  double get rsAmount => rsEnabled ? totalTtc * rsRate / 100 : 0.0;
  double get netToPay => totalTtc + timbre - rsAmount;

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

  Map<String, dynamic> toInvoiceJson() => {
        'org_id':   orgId,
        'currency': currency,
        'status':   status.name,
        'subtotal': subtotal,
        'tax':      tax,
        'total':    total,
        if (companyId != null) 'company_id': companyId,
        if (contactId != null) 'contact_id': contactId,
        if (quoteId   != null) 'quote_id':   quoteId,
        if (clientName != null)
          'client_snapshot': {
            'name':    clientName,
            if (clientAddress != null) 'address': clientAddress,
            if (clientPhone   != null) 'phone':   clientPhone,
            if (clientTaxId   != null) 'tax_id':  clientTaxId,
            if (clientCustomFields != null && clientCustomFields!.isNotEmpty)
              'custom_fields': clientCustomFields,
          },
        'issue_date': (issueDate ?? DateTime.now()).toIso8601String().split('T').first,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String().split('T').first,
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

  InvoiceInput copyWith({
    String?              orgId,
    Object?              companyId          = _absent,
    Object?              contactId          = _absent,
    Object?              clientName         = _absent,
    Object?              clientAddress      = _absent,
    Object?              clientPhone        = _absent,
    Object?              clientTaxId        = _absent,
    Object?              clientCustomFields = _absent,
    Object?              quoteId            = _absent,
    List<InvoiceLineInput>? lines,
    String?              currency,
    InvoiceStatus?       status,
    Object?              issueDate              = _absent,
    Object?              dueDate                = _absent,
    Object?              notes                  = _absent,
    Object?              objet                  = _absent,
    Object?              contractNumber         = _absent,
    Object?              paymentMode            = _absent,
    Object?              paymentTermTemplateId  = _absent,
    Object?              paymentTermSnapshot    = _absent,
    bool?                fodecEnabled,
    double?              fodecRate,
    bool?                timbreEnabled,
    double?              timbreAmount,
    bool?                rsEnabled,
    double?              rsRate,
  }) =>
      InvoiceInput(
        orgId:         orgId         ?? this.orgId,
        companyId:     identical(companyId,     _absent) ? this.companyId     : companyId     as String?,
        contactId:     identical(contactId,     _absent) ? this.contactId     : contactId     as String?,
        clientName:    identical(clientName,    _absent) ? this.clientName    : clientName    as String?,
        clientAddress: identical(clientAddress, _absent) ? this.clientAddress : clientAddress as String?,
        clientPhone:   identical(clientPhone,   _absent) ? this.clientPhone   : clientPhone   as String?,
        clientTaxId:   identical(clientTaxId,   _absent) ? this.clientTaxId   : clientTaxId   as String?,
        clientCustomFields: identical(clientCustomFields, _absent) ? this.clientCustomFields : clientCustomFields as Map<String, dynamic>?,
        quoteId:       identical(quoteId,       _absent) ? this.quoteId       : quoteId       as String?,
        lines:         lines         ?? this.lines,
        currency:      currency      ?? this.currency,
        status:        status        ?? this.status,
        issueDate:     identical(issueDate, _absent) ? this.issueDate : issueDate as DateTime?,
        dueDate:       identical(dueDate,   _absent) ? this.dueDate   : dueDate   as DateTime?,
        notes:         identical(notes,     _absent) ? this.notes     : notes     as String?,
        objet:               identical(objet,                _absent) ? this.objet               : objet               as String?,
        contractNumber:      identical(contractNumber,       _absent) ? this.contractNumber      : contractNumber      as String?,
        paymentMode:         identical(paymentMode,          _absent) ? this.paymentMode         : paymentMode         as String?,
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

extension InvoiceToInput on Invoice {
  InvoiceInput toInput() => InvoiceInput(
        orgId:              orgId,
        companyId:          companyId,
        contactId:          contactId,
        clientName:         clientSnapshotName,
        clientAddress:      clientSnapshotAddress,
        clientPhone:        clientSnapshotPhone,
        clientTaxId:        clientSnapshotTaxId,
        clientCustomFields: clientSnapshotCustomFields.isEmpty ? null : clientSnapshotCustomFields,
        quoteId:            quoteId,
        currency:      currency,
        status:        status,
        issueDate:     issueDate,
        dueDate:       dueDate,
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

List<InvoiceLineInput> _flattenForEdit(List<InvoiceLine> lines) {
  final byParent = <String?, List<InvoiceLine>>{};
  for (final l in lines) {
    byParent.putIfAbsent(l.parentId, () => []).add(l);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.position.compareTo(b.position));
  }
  final out = <InvoiceLineInput>[];
  void walk(InvoiceLine l, int depth) {
    out.add(InvoiceLineInput(
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
    for (final child in byParent[l.id] ?? const <InvoiceLine>[]) {
      walk(child, depth + 1);
    }
  }
  for (final root in byParent[null] ?? const <InvoiceLine>[]) {
    walk(root, 0);
  }
  return out;
}

extension InvoiceTotals on Invoice {
  double get fodecAmount => fodecEnabled
      ? lines.where((l) => l.fodecApplicable).fold(0.0, (s, l) => s + l.lineTotal) *
          fodecRate /
          100
      : 0.0;

  double get totalTtc => subtotal + fodecAmount + tax;
  double get timbre   => timbreEnabled ? timbreAmount : 0.0;
  double get rsAmount => rsEnabled ? totalTtc * rsRate / 100 : 0.0;
  double get netToPay => totalTtc + timbre - rsAmount;

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

// ── InvoiceWithClient (list-view join model) ───────────────────────────────────

class InvoiceWithClient {
  const InvoiceWithClient({
    required this.invoice,
    this.clientName,
  });

  final Invoice invoice;
  final String? clientName;

  factory InvoiceWithClient.fromJson(Map<String, dynamic> json) {
    final companyRow = json['companies'] as Map<String, dynamic>?;
    final contactRow = json['contacts']  as Map<String, dynamic>?;
    final invoice    = Invoice.fromJson(json);
    final joinedName = companyRow?['name'] as String?
        ?? (contactRow != null
            ? '${contactRow['first_name'] ?? ''} ${contactRow['last_name'] ?? ''}'.trim()
            : null);
    return InvoiceWithClient(
      invoice:    invoice,
      clientName: (joinedName?.isNotEmpty ?? false) ? joinedName : invoice.clientSnapshotName,
    );
  }
}
