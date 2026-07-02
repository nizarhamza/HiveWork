// ── Payment (read model) ───────────────────────────────────────────────────────

class Payment {
  const Payment({
    required this.id,
    required this.orgId,
    required this.invoiceId,
    required this.paidOn,
    required this.amount,
    required this.createdAt,
    this.method,
    this.reference,
  });

  final String    id;
  final String    orgId;
  final String    invoiceId;
  final DateTime  paidOn;
  final double    amount;
  final String?   method;
  final String?   reference;
  final DateTime  createdAt;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id:        json['id']         as String,
        orgId:     json['org_id']     as String,
        invoiceId: json['invoice_id'] as String,
        paidOn:    DateTime.parse(json['paid_on'] as String),
        amount:    (json['amount']    as num).toDouble(),
        method:    json['method']     as String?,
        reference: json['reference']  as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ── PaymentInput (write model) ─────────────────────────────────────────────────

class PaymentInput {
  const PaymentInput({
    required this.orgId,
    required this.invoiceId,
    required this.amount,
    required this.paidOn,
    this.method,
    this.reference,
  });

  final String    orgId;
  final String    invoiceId;
  final double    amount;
  final DateTime  paidOn;
  final String?   method;
  final String?   reference;

  Map<String, dynamic> toJson() => {
        'org_id':     orgId,
        'invoice_id': invoiceId,
        'amount':     amount,
        'paid_on':    paidOn.toIso8601String().split('T').first,
        if (method    != null) 'method':    method,
        if (reference != null) 'reference': reference,
      };
}
