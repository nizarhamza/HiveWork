const kMilestoneLabels = [
  'Deposit',
  'Delivery',
  'Handover',
  'End of Works',
  'End of Warranty',
];

// ── Installment ────────────────────────────────────────────────────────────────

class PaymentInstallment {
  const PaymentInstallment({
    required this.order,
    required this.percent,
    required this.label,
  });

  final int    order;
  final int    percent;
  final String label;

  factory PaymentInstallment.fromJson(Map<String, dynamic> json) =>
      PaymentInstallment(
        order:   json['order']   as int,
        percent: json['percent'] as int,
        label:   json['label']   as String,
      );

  Map<String, dynamic> toJson() => {
        'order':   order,
        'percent': percent,
        'label':   label,
      };

  PaymentInstallment copyWith({int? order, int? percent, String? label}) =>
      PaymentInstallment(
        order:   order   ?? this.order,
        percent: percent ?? this.percent,
        label:   label   ?? this.label,
      );
}

// ── Template (read model) ──────────────────────────────────────────────────────

class PaymentTermTemplate {
  const PaymentTermTemplate({
    required this.id,
    required this.name,
    required this.installments,
    required this.createdAt,
  });

  final String                   id;
  final String                   name;
  final List<PaymentInstallment> installments;
  final DateTime                 createdAt;

  factory PaymentTermTemplate.fromJson(Map<String, dynamic> json) =>
      PaymentTermTemplate(
        id:   json['id']   as String,
        name: json['name'] as String,
        installments: (json['installments'] as List<dynamic>)
            .map((e) => PaymentInstallment.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Dot-separated inline summary: "30% Avance · 70% Livraison"
  String get summary =>
      installments.map((i) => '${i.percent}% ${i.label}').join(' · ');
}

// ── Input (write model) ────────────────────────────────────────────────────────

class PaymentTermTemplateInput {
  const PaymentTermTemplateInput({
    required this.name,
    required this.installments,
  });

  final String                   name;
  final List<PaymentInstallment> installments;

  int get total => installments.fold(0, (s, i) => s + i.percent);

  bool get isValid =>
      name.trim().isNotEmpty &&
      installments.isNotEmpty &&
      installments.length <= 5 &&
      total == 100 &&
      installments.every((i) => i.percent > 0 && i.label.isNotEmpty);

  Map<String, dynamic> toJson(String orgId) => {
        'org_id':       orgId,
        'name':         name.trim(),
        'installments': installments.map((i) => i.toJson()).toList(),
      };

  /// Auto-generates a display name from the installment breakdown.
  static String autoName(List<PaymentInstallment> installments) {
    if (installments.isEmpty) return '';
    final hasLabels = installments.any((i) => i.label.isNotEmpty);
    if (installments.length == 1) {
      final pct = installments[0].percent;
      final lbl = installments[0].label;
      return hasLabels ? '${pct > 0 ? pct : 100}% $lbl' : '';
    }
    final percents = installments.map((i) => i.percent.toString()).join('/');
    if (!hasLabels) return percents;
    final labels = installments
        .where((i) => i.label.isNotEmpty)
        .map((i) => i.label)
        .join(' / ');
    return '$percents — $labels';
  }
}
