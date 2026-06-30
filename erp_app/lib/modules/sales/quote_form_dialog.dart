import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../data/models/company.dart';
import '../../data/models/contact.dart';
import '../../data/models/payment_term_template.dart';
import '../../data/models/product.dart';
import '../../data/models/quote.dart';
import '../../data/providers/companies_provider.dart';
import '../../data/providers/contacts_provider.dart';
import '../../data/providers/product_bundle_provider.dart';
import '../../modules/inventory/bundle_picker_dialog.dart';
import '../../modules/inventory/product_picker_dialog.dart';
import '../../modules/org/org_providers.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/atoms/app_button.dart';
import '../../ui/organisms/app_dialog.dart';
import 'payment_term_providers.dart';

// ── Helper ─────────────────────────────────────────────────────────────────────

Future<QuoteInput?> showQuoteForm(
  BuildContext context, {
  required QuoteInput initial,
}) {
  return showDialog<QuoteInput>(
    context: context,
    builder: (_) => _QuoteFormDialog(initial: initial),
  );
}

// ── Line controller ────────────────────────────────────────────────────────────

const _kMaxLineLevel = 2; // category (0) / sub-category (1) / detail (2)

// Single source of truth for the line-items table's column widths, shared
// by the header row and every data row so they can never drift apart.
const _kColIndentW  = 52.0;
const _kColProductW = 28.0;
const _kColUnitW    = 60.0;
const _kColQtyW     = 60.0;
const _kColPriceW   = 96.0;
const _kColDiscW    = 64.0;
const _kColTaxW     = 64.0;
const _kColFodW     = 30.0;
const _kColTotalW   = 100.0;
const _kColDeleteW  = 28.0;
const _kColGap      = LinearSpacing.xs;

class _LineState {
  _LineState({
    String label        = '',
    double qty          = 1,
    double unitPrice    = 0,
    double taxRate      = 0,
    double discountRate = 0,
    String unit         = '',
    this.fodecApplicable = false,
    this.level            = 0,
    this.productId,
  })  : labelCtrl = TextEditingController(text: label),
        qtyCtrl   = TextEditingController(text: _n(qty)),
        priceCtrl = TextEditingController(text: _n(unitPrice)),
        taxCtrl   = TextEditingController(text: _n(taxRate)),
        discCtrl  = TextEditingController(text: _n(discountRate)),
        unitCtrl  = TextEditingController(text: unit);

  factory _LineState.empty() => _LineState();

  factory _LineState.fromInput(QuoteLineInput l) => _LineState(
        label:           l.label,
        qty:             l.qty,
        unitPrice:       l.unitPrice,
        taxRate:         l.taxRate,
        discountRate:    l.discountRate,
        unit:            l.unit ?? '',
        fodecApplicable: l.fodecApplicable,
        level:           l.level.clamp(0, _kMaxLineLevel).toInt(),
        productId:       l.productId,
      );

  final TextEditingController labelCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController taxCtrl;
  final TextEditingController discCtrl;
  final TextEditingController unitCtrl;
  String? productId;
  bool fodecApplicable;
  int  level; // 0 = category, 1 = sub-category, 2 = detail row

  void dispose() {
    labelCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    taxCtrl.dispose();
    discCtrl.dispose();
    unitCtrl.dispose();
  }

  void applyProduct(Product p) {
    productId      = p.id;
    labelCtrl.text = p.displayLabel;
    priceCtrl.text = _n(p.unitPrice);
    taxCtrl.text   = _n(p.taxRate);
    if (p.unit != null) unitCtrl.text = p.unit!;
  }

  double get _qty   => double.tryParse(qtyCtrl.text.replaceAll(',', '.'))   ?? 0;
  double get _price => double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _tax    => double.tryParse(taxCtrl.text.replaceAll(',', '.'))   ?? 0;
  double get _disc   => double.tryParse(discCtrl.text.replaceAll(',', '.'))  ?? 0;

  double get lineTotal => _qty * _price * (1 - _disc / 100);
  double get taxAmount => lineTotal * _tax / 100;

  QuoteLineInput toInput(int pos) => QuoteLineInput(
        label:           labelCtrl.text.trim(),
        qty:             _qty,
        unitPrice:       _price,
        taxRate:         _tax,
        discountRate:    _disc,
        position:        pos,
        unit:            unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
        fodecApplicable: fodecApplicable,
        level:           level,
        productId:       productId,
      );

  static String _n(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ── Dialog ─────────────────────────────────────────────────────────────────────

class _QuoteFormDialog extends ConsumerStatefulWidget {
  const _QuoteFormDialog({required this.initial});
  final QuoteInput initial;

  @override
  ConsumerState<_QuoteFormDialog> createState() => _QuoteFormDialogState();
}

class _QuoteFormDialogState extends ConsumerState<_QuoteFormDialog> {
  late final QuoteStatus _status   = widget.initial.status;
  late final String      _currency = widget.initial.currency;
  late DateTime    _issueDate = DateTime.now();
  late DateTime?   _dueDate  = widget.initial.validUntil
      ?? (widget.initial.lines.isEmpty
          ? DateTime.now().add(const Duration(days: 30))
          : null);

  // Client is now selected from contacts/companies, not a free-text field
  late String? _clientId      = widget.initial.clientId;
  late String? _clientName    = widget.initial.clientName;
  late String? _clientAddress = widget.initial.clientAddress;
  late String? _clientPhone   = widget.initial.clientPhone;
  late String? _clientTaxId   = widget.initial.clientTaxId;

  late final _notesCtrl = TextEditingController(text: widget.initial.notes ?? '');
  late final List<_LineState> _lines = widget.initial.lines.isNotEmpty
      ? widget.initial.lines.map(_LineState.fromInput).toList()
      : [_LineState.empty()];

  // ── Document fields (Tunisian devis/facture format) ───────────────────────────
  late final _objetCtrl          = TextEditingController(text: widget.initial.objet ?? '');
  late final _contractNumberCtrl = TextEditingController(text: widget.initial.contractNumber ?? '');
  // Payment term: structured template selection
  late String? _selectedTermId       = widget.initial.paymentTermTemplateId;
  late List<Map<String, dynamic>>? _selectedTermSnapshot =
      widget.initial.paymentTermSnapshot;
  late String? _selectedTermName     = widget.initial.paymentMode;
  String? _orgInitializedId;

  // FODEC / timbre fiscal / RS are configured once in Settings > Quote/Invoice,
  // not per quote — see `_save()`, which pulls org defaults for new quotes and
  // keeps whatever was already saved when editing.

  String? _error;
  String _effectiveCurrency = 'USD';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _objetCtrl.dispose();
    _contractNumberCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_LineState.empty()));

  Future<void> _insertBundle() async {
    final result = await showBundlePicker(context);
    if (result == null || !mounted) return;

    final repo = ref.read(productBundleRepositoryProvider);
    final flat = await repo.flattenBundle(result.bundle.id, parentQty: result.qty);
    if (flat.isEmpty || !mounted) return;

    setState(() {
      // Bundle name becomes the parent row (level 0 = category header)
      _lines.add(_LineState(label: result.bundle.name, level: 0));
      // Each product is a child row (level 1 = sub-item)
      for (final leaf in flat) {
        _lines.add(_LineState(
          label:     leaf.product.name,
          qty:       leaf.qty,
          unitPrice: leaf.product.unitPrice,
          taxRate:   leaf.product.taxRate,
          unit:      leaf.product.unit ?? '',
          productId: leaf.product.id,
          level:     1,
        ));
      }
    });
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    _lines.removeAt(i).dispose();
    setState(() {});
  }

  /// A row can only be indented one level deeper than the row immediately
  /// above it (outline-style: can't jump straight from category to detail).
  void _indent(int i) {
    if (i == 0) return;
    final maxAllowed = (_lines[i - 1].level + 1).clamp(0, _kMaxLineLevel);
    if (_lines[i].level >= maxAllowed) return;
    setState(() => _lines[i].level++);
  }

  void _outdent(int i) {
    if (_lines[i].level <= 0) return;
    setState(() => _lines[i].level--);
  }

  /// Returns a dotted number string for each row, e.g. "1", "1.1", "2.3".
  List<String> _computeLineNumbers() {
    final numbers  = <String>[];
    final counters = <int>[];
    for (final line in _lines) {
      final d = line.level;
      while (counters.length <= d) counters.add(0);
      if (counters.length > d + 1) counters.removeRange(d + 1, counters.length);
      counters[d]++;
      numbers.add(counters.join('.'));
    }
    return numbers;
  }

  /// Whether row [i] has children (i.e. the next row is indented deeper) —
  /// such rows hide their numeric fields and show a rolled-up subtotal.
  bool _hasChildren(int i) =>
      i + 1 < _lines.length && _lines[i + 1].level > _lines[i].level;

  double _rollupTotal(int i) {
    if (!_hasChildren(i)) return _lines[i].lineTotal;
    var sum = 0.0;
    final level = _lines[i].level;
    for (var j = i + 1; j < _lines.length && _lines[j].level > level; j++) {
      if (!_hasChildren(j)) sum += _lines[j].lineTotal;
    }
    return sum;
  }

  double get _subtotal => _lines
      .asMap()
      .entries
      .where((e) => !_hasChildren(e.key))
      .fold(0.0, (s, e) => s + e.value.lineTotal);
  double get _tax => _lines
      .asMap()
      .entries
      .where((e) => !_hasChildren(e.key))
      .fold(0.0, (s, e) => s + e.value.taxAmount);

  String _money(double v) {
    final sym = _sym(_effectiveCurrency);
    return '$sym${v.toStringAsFixed(2)}';
  }

  static String _sym(String c) => switch (c.toUpperCase()) {
        'EUR' => '€',
        'USD' => '\$',
        'GBP' => '£',
        _     => '$c ',
      };

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _issueDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _issueDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final lines = _lines
        .asMap()
        .entries
        .map((e) => e.value.toInput(e.key))
        .where((l) => l.label.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      setState(() => _error = 'Add at least one line item with a description.');
      return;
    }

    // FODEC / timbre fiscal / RS are configured org-wide in
    // Settings > Quote/Invoice, not per quote. New quotes inherit whatever
    // the org currently has switched on (at the org's standard rates);
    // edits keep whatever was already saved on the quote.
    final isNew = widget.initial.lines.isEmpty;
    final org   = ref.read(orgDetailsProvider).value;
    final fodecEnabled  = isNew ? (org?.enableFodec ?? false)        : widget.initial.fodecEnabled;
    final timbreEnabled = isNew ? (org?.enableTimbreFiscal ?? false) : widget.initial.timbreEnabled;
    final rsEnabled     = isNew ? (org?.enableRetenuSource ?? false) : widget.initial.rsEnabled;

    Navigator.pop(
      context,
      widget.initial.copyWith(
        clientId:      _clientId,
        clientName:    _clientName,
        clientAddress: _clientAddress,
        clientPhone:   _clientPhone,
        clientTaxId:   _clientTaxId,
        lines:      lines,
        status:     _status,
        currency:   _effectiveCurrency,
        validUntil: _dueDate,
        notes:      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        objet:                 _objetCtrl.text.trim().isEmpty ? null : _objetCtrl.text.trim(),
        contractNumber:        _contractNumberCtrl.text.trim().isEmpty ? null : _contractNumberCtrl.text.trim(),
        paymentMode:           _selectedTermName,
        paymentTermTemplateId: _selectedTermId,
        paymentTermSnapshot:   _selectedTermSnapshot,
        fodecEnabled:  fodecEnabled,
        timbreEnabled: timbreEnabled,
        rsEnabled:     rsEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(orgDetailsProvider);

    _effectiveCurrency = (widget.initial.lines.isEmpty && orgAsync.value != null)
        ? orgAsync.value!.currency
        : _currency;

    // Pre-fill notes with org default once, for new quotes only.
    final org = orgAsync.value;
    if (org != null && _orgInitializedId == null) {
      _orgInitializedId = org.id;
      if (widget.initial.lines.isEmpty && _notesCtrl.text.isEmpty) {
        Future.microtask(() {
          if (mounted) setState(() => _notesCtrl.text = org.defaultQuoteNotes ?? '');
        });
      }
    }

    // ── Tax breakdown for the totals section ─────────────────────────────────
    final fodecEnabled  = org?.enableFodec          ?? false;
    final timbreEnabled = org?.enableTimbreFiscal    ?? false;
    final rsEnabled     = org?.enableRetenuSource    ?? false;
    const fodecRate     = 1.0;
    const timbreFlat    = 1.0;
    const rsRate        = 3.0;

    final fodecAmt = fodecEnabled
        ? _lines
              .asMap()
              .entries
              .where((e) => !_hasChildren(e.key) && e.value.fodecApplicable)
              .fold(0.0, (s, e) => s + e.value.lineTotal) *
            fodecRate /
            100
        : 0.0;
    final tvaAmt     = _tax;
    final totalTtc   = _subtotal + fodecAmt + tvaAmt;
    final rsAmt      = rsEnabled ? totalTtc * rsRate / 100 : 0.0;
    final timbreAmt  = timbreEnabled ? timbreFlat : 0.0;
    final netToPay   = totalTtc + timbreAmt - rsAmt;

    return AppDialog(
      title:   widget.initial.lines.isEmpty ? 'New quote' : 'Edit quote',
      width:   980,
      actions: [
        AppButton(
          label:     'Cancel',
          variant:   AppButtonVariant.ghost,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label:     'Save quote',
          variant:   AppButtonVariant.filled,
          size:      AppButtonSize.lg,
          icon:      Icons.check_rounded,
          onPressed: _save,
        ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Client ──────────────────────────────────────────────────────────
          const _SectionLabel('Client'),
          const SizedBox(height: LinearSpacing.xs),
          _ClientPicker(
            clientId:   _clientId,
            clientName: _clientName,
            onSelect:   (c) => setState(() {
              _clientId      = c.id;
              _clientName    = c.name;
              _clientAddress = c.address;
              _clientPhone   = c.phone;
              _clientTaxId   = c.taxId;
            }),
            onClear: () => setState(() {
              _clientId      = null;
              _clientName    = null;
              _clientAddress = null;
              _clientPhone   = null;
              _clientTaxId   = null;
            }),
          ),
          const SizedBox(height: LinearSpacing.lg),

          // ── Dates ────────────────────────────────────────────────────────────
          const _SectionLabel('Dates'),
          const SizedBox(height: LinearSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Issue date',
                  date:  _issueDate,
                  onTap: _pickIssueDate,
                ),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _DateField(
                  label:   'Due date',
                  date:    _dueDate,
                  onTap:   _pickDueDate,
                  onClear: () => setState(() => _dueDate = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.lg),

          // ── Document (devis/facture fields) ───────────────────────────────────
          const _SectionLabel('Document'),
          const SizedBox(height: LinearSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _LabeledField(label: 'Objet', controller: _objetCtrl, hint: 'Mission, chantier…'),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _LabeledField(label: 'Contract #', controller: _contractNumberCtrl, hint: 'Optional'),
              ),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: _PaymentTermSelector(
                  templates: ref.watch(paymentTermsProvider).value ?? const [],
                  selectedId: _selectedTermId,
                  onChanged: (template) => setState(() {
                    _selectedTermId       = template?.id;
                    _selectedTermSnapshot = template?.installments
                        .map((i) => i.toJson())
                        .toList();
                    _selectedTermName     = template?.name;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: LinearSpacing.lg),

          // ── Line items ────────────────────────────────────────────────────────
          const _SectionLabel('Line items'),
          const SizedBox(height: LinearSpacing.xs),
          _LineItemsTable(
            lines:           _lines,
            lineNumbers:     _computeLineNumbers(),
            subtotal:        _subtotal,
            tvaAmount:       tvaAmt,
            fodecEnabled:    fodecEnabled,
            fodecAmount:     fodecAmt,
            timbreEnabled:   timbreEnabled,
            timbreAmount:    timbreAmt,
            rsEnabled:       rsEnabled,
            rsAmount:        rsAmt,
            rsRate:          rsRate,
            netToPay:        netToPay,
            moneyFmt:        _money,
            onAddLine:       _addLine,
            onInsertBundle:  _insertBundle,
            onRemoveLine:    _removeLine,
            onIndent:        _indent,
            onOutdent:       _outdent,
            hasChildren:     _hasChildren,
            rollupTotal:     _rollupTotal,
            onChanged:       () => setState(() {}),
          ),
          const SizedBox(height: LinearSpacing.lg),

          // ── Notes ─────────────────────────────────────────────────────────────
          const _SectionLabel('Notes'),
          const SizedBox(height: LinearSpacing.xs),
          _NotesField(controller: _notesCtrl),

          if (_error != null) ...[
            const SizedBox(height: LinearSpacing.sm),
            _ErrorBanner(_error!),
          ],
        ],
      ),
    );
  }
}

// ── Client picker data model ───────────────────────────────────────────────────

sealed class _Client {
  const _Client();
  String get id;
  String get name;
  String get subtitle;
  String get type;
  Color  get avatarColor;
  String get initials;
  String? get address;
  String? get phone;
  String? get taxId;
}

class _ContactClient extends _Client {
  const _ContactClient(this.contact);
  final Contact contact;
  @override String get id          => contact.id;
  @override String get name        => contact.fullName;
  @override String get subtitle    => contact.email ?? contact.companyName ?? '';
  @override String get type        => 'Contact';
  @override Color  get avatarColor => contact.avatarColor;
  @override String get initials    => contact.initials;
  @override String? get address    => null;
  @override String? get phone      => contact.phone;
  @override String? get taxId      => null;
}

class _CompanyClient extends _Client {
  const _CompanyClient(this.company);
  final Company company;
  @override String? get address    => company.address;
  @override String? get phone      => company.phone;
  @override String? get taxId      => company.taxId;
  @override String get id          => company.id;
  @override String get name        => company.name;
  @override String get subtitle    => company.industry ?? '';
  @override String get type        => 'Company';
  @override Color  get avatarColor => company.avatarColor;
  @override String get initials    => company.initials;
}

// ── Client picker ──────────────────────────────────────────────────────────────

class _ClientPicker extends ConsumerStatefulWidget {
  const _ClientPicker({
    required this.clientId,
    required this.clientName,
    required this.onSelect,
    required this.onClear,
  });

  final String? clientId;
  final String? clientName;
  final void Function(_Client client) onSelect;
  final VoidCallback onClear;

  @override
  ConsumerState<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<_ClientPicker> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    // Only open on focus gain — closing is handled by TapRegion.onTapOutside
    // and by the onSelect callback, so focus-loss never closes the list.
    _focus.addListener(() {
      if (_focus.hasFocus && !_open) setState(() => _open = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Client> _filter(List<Contact> contacts, List<Company> companies) {
    final q   = _ctrl.text.trim().toLowerCase();
    final all = <_Client>[
      ...contacts.map(_ContactClient.new),
      ...companies.map(_CompanyClient.new),
    ];
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.subtitle.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    // Already selected — show the chip row
    if (widget.clientName != null) {
      return _SelectedClientChip(
        name:    widget.clientName!,
        onClear: widget.onClear,
      );
    }

    final contactsAsync  = ref.watch(contactsProvider);
    final companiesAsync = ref.watch(companiesProvider);
    final contacts  = contactsAsync.value  ?? [];
    final companies = companiesAsync.value ?? [];
    final isLoading = contactsAsync.isLoading || companiesAsync.isLoading;
    final results   = _filter(contacts, companies);

    return TapRegion(
      onTapOutside: (_) {
        _focus.unfocus();
        if (_open) setState(() => _open = false);
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color:        ext.surfaceBase,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border: Border.all(
          color: _open ? LinearColors.accent : ext.borderBase,
          width: _open ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input row
          Row(
            children: [
              const SizedBox(width: LinearSpacing.base),
              Icon(
                Icons.search,
                size:  15,
                color: _open ? LinearColors.accent : ext.textMuted,
              ),
              const SizedBox(width: LinearSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode:  _focus,
                  onChanged:  (_) => setState(() {}),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: ext.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search contacts and companies…',
                    hintStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: ext.textMuted),
                    border:         InputBorder.none,
                    enabledBorder:  InputBorder.none,
                    focusedBorder:  InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: LinearSpacing.base,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _ctrl.clear()),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LinearSpacing.sm,
                      ),
                      child: Icon(Icons.close, size: 13, color: ext.textMuted),
                    ),
                  ),
                )
              else
                const SizedBox(width: LinearSpacing.base),
            ],
          ),

          // Results dropdown (visible while focused)
          if (_open) ...[
            Divider(height: 1, color: ext.borderSubtle),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _buildResults(isLoading, results),
            ),
          ],
        ],
      ),
      ), // TapRegion
    );
  }

  Widget _buildResults(bool isLoading, List<_Client> results) {
    final ext = context.linearExt;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(LinearSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color:       LinearColors.accent,
            ),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(LinearSpacing.md),
        child: Text(
          'No contacts or companies found',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: ext.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding:     const EdgeInsets.symmetric(vertical: LinearSpacing.xs),
      shrinkWrap:  true,
      itemCount:   results.length,
      itemBuilder: (_, i) => _ClientResultTile(
        client:   results[i],
        onSelect: (c) {
          widget.onSelect(c);
          _ctrl.clear();
          _focus.unfocus();
          setState(() => _open = false);
        },
      ),
    );
  }
}

// ── Selected client chip ───────────────────────────────────────────────────────

class _SelectedClientChip extends StatelessWidget {
  const _SelectedClientChip({required this.name, required this.onClear});
  final String       name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ext      = context.linearExt;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();
    final color = _colorFromName(name);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.base,
        vertical:   LinearSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color:        ext.surfaceBase,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border:       Border.all(color: ext.borderBase),
      ),
      child: Row(
        children: [
          _Avatar(initials: initials, color: color, size: 26),
          const SizedBox(width: LinearSpacing.sm),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ext.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(left: LinearSpacing.sm),
                child: Icon(Icons.close, size: 13, color: ext.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorFromName(String name) {
    const palette = [
      Color(0xFF5E6AD2), Color(0xFF2BA87E), Color(0xFFD9730D),
      Color(0xFFC2554D), Color(0xFF9D5BD2), Color(0xFF3A87C2),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }
}

// ── Search result tile ─────────────────────────────────────────────────────────

class _ClientResultTile extends StatefulWidget {
  const _ClientResultTile({required this.client, required this.onSelect});
  final _Client client;
  final void Function(_Client) onSelect;

  @override
  State<_ClientResultTile> createState() => _ClientResultTileState();
}

class _ClientResultTileState extends State<_ClientResultTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.client),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _hovered ? ext.overlayActive : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base,
            vertical:   LinearSpacing.sm,
          ),
          child: Row(
            children: [
              _Avatar(
                initials: widget.client.initials,
                color:    widget.client.avatarColor,
                size:     28,
              ),
              const SizedBox(width: LinearSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      widget.client.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:      ext.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.client.subtitle.isNotEmpty)
                      Text(
                        widget.client.subtitle,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: ext.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              _TypeBadge(widget.client.type),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar circle ──────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color, required this.size});
  final String initials;
  final Color  color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(LinearRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            fontSize:   size * 0.35,
            fontWeight: FontWeight.w700,
            color:      color,
          ),
        ),
      );
}

// ── Type badge (Contact / Company) ─────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        ext.overlayActive,
        borderRadius: BorderRadius.circular(LinearRadii.pill),
        border:       Border.all(color: ext.borderSubtle),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color:      ext.textMuted,
          fontSize:   9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color:         context.linearExt.textMuted,
          letterSpacing: 0.8,
          fontWeight:    FontWeight.w600,
        ),
      );
}

// ── Labeled text field (Document section) ──────────────────────────────────────

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint = '',
  });

  final String                 label;
  final TextEditingController  controller;
  final String                 hint;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ext.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ext.textPrimary),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: ext.textMuted),
            isDense:        true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              borderSide:   BorderSide(color: ext.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Date field ─────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String        label;
  final DateTime?     date;
  final VoidCallback  onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: ext.textMuted),
            floatingLabelStyle: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: ext.textMuted, fontSize: 10),
            suffixIcon: date != null && onClear != null
                ? GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close, size: 13, color: ext.textMuted),
                  )
                : Icon(Icons.calendar_today_outlined, size: 14, color: ext.textMuted),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: LinearSpacing.base,
              vertical:   LinearSpacing.sm,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              borderSide:   BorderSide(color: ext.borderBase),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              borderSide:   BorderSide(color: ext.borderBase),
            ),
          ),
          child: Text(
            date != null ? _fmt(date!) : '—',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: date != null ? ext.textPrimary : ext.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Line items table ───────────────────────────────────────────────────────────

class _LineItemsTable extends StatelessWidget {
  const _LineItemsTable({
    required this.lines,
    required this.lineNumbers,
    required this.subtotal,
    required this.tvaAmount,
    required this.fodecEnabled,
    required this.fodecAmount,
    required this.timbreEnabled,
    required this.timbreAmount,
    required this.rsEnabled,
    required this.rsAmount,
    required this.rsRate,
    required this.netToPay,
    required this.moneyFmt,
    required this.onAddLine,
    required this.onInsertBundle,
    required this.onRemoveLine,
    required this.onIndent,
    required this.onOutdent,
    required this.hasChildren,
    required this.rollupTotal,
    required this.onChanged,
  });

  final List<_LineState>        lines;
  final List<String>            lineNumbers;
  final double                  subtotal;
  final double                  tvaAmount;
  final bool                    fodecEnabled;
  final double                  fodecAmount;
  final bool                    timbreEnabled;
  final double                  timbreAmount;
  final bool                    rsEnabled;
  final double                  rsAmount;
  final double                  rsRate;
  final double                  netToPay;
  final String Function(double) moneyFmt;
  final VoidCallback            onAddLine;
  final Future<void> Function() onInsertBundle;
  final void Function(int)      onRemoveLine;
  final void Function(int)      onIndent;
  final void Function(int)      onOutdent;
  final bool Function(int)      hasChildren;
  final double Function(int)    rollupTotal;
  final VoidCallback            onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    return ClipRRect(
      borderRadius: BorderRadius.circular(LinearRadii.md),
      child: Container(
        decoration: BoxDecoration(
          color:        ext.surfaceBase,
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border:       Border.all(color: ext.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row — tinted to distinguish from data
            Container(
              color: ext.overlay,
              padding: const EdgeInsets.symmetric(
                horizontal: LinearSpacing.base,
                vertical:   LinearSpacing.xs + 2,
              ),
              child: Row(
                children: [
                  const SizedBox(width: _kColIndentW),  // indent controls column
                  const SizedBox(width: _kColProductW), // product picker column
                  Expanded(
                    flex: 5,
                    child: _ColHdr('Description', padding: const EdgeInsets.only(left: 8)),
                  ),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColUnitW,  child: _ColHdr('Unit',       right: true, padding: const EdgeInsets.only(right: 8))),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColQtyW,   child: _ColHdr('Qty',        right: true, padding: const EdgeInsets.only(right: 8))),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColPriceW, child: _ColHdr('Unit price', right: true, padding: const EdgeInsets.only(right: 8))),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColDiscW,  child: _ColHdr('Disc %',     right: true, padding: const EdgeInsets.only(right: 6))),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColTaxW,   child: _ColHdr('Tax %',      right: true, padding: const EdgeInsets.only(right: 6))),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColFodW,   child: _ColHdr('FOD', center: true)),
                  const SizedBox(width: _kColGap),
                  SizedBox(width: _kColTotalW, child: _ColHdr('Total', right: true)),
                  const SizedBox(width: _kColDeleteW),
                ],
              ),
            ),
            Divider(height: 1, color: ext.borderSubtle),

            // Data rows
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LinearSpacing.base,
                vertical:   LinearSpacing.xs,
              ),
              child: Column(
                children: List.generate(
                  lines.length,
                  (i) => _LineRow(
                    key:         ValueKey(i),
                    state:       lines[i],
                    number:      lineNumbers[i],
                    canDelete:   lines.length > 1,
                    canOutdent:  lines[i].level > 0,
                    canIndent:   i > 0 && lines[i].level < (lines[i - 1].level + 1).clamp(0, _kMaxLineLevel),
                    isParent:    hasChildren(i),
                    rollup:      rollupTotal(i),
                    onChanged:   onChanged,
                    onDelete:    () => onRemoveLine(i),
                    onIndent:    () => onIndent(i),
                    onOutdent:   () => onOutdent(i),
                  ),
                ),
              ),
            ),

            // Add line / Insert bundle
            Divider(height: 1, color: ext.borderSubtle),
            _TableFooterActions(
              onAddLine:      onAddLine,
              onInsertBundle: onInsertBundle,
            ),

            // Totals
            Divider(height: 1, color: ext.borderSubtle),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base,
                LinearSpacing.sm,
                LinearSpacing.base + 28,
                LinearSpacing.base,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: IntrinsicWidth(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TotalRow(label: 'Subtotal', value: moneyFmt(subtotal), bold: false),
                  if (fodecEnabled && fodecAmount > 0) ...[
                    const SizedBox(height: LinearSpacing.xs),
                    _TotalRow(label: 'FODEC (1%)', value: moneyFmt(fodecAmount), bold: false),
                  ],
                  if (tvaAmount > 0) ...[
                    const SizedBox(height: LinearSpacing.xs),
                    _TotalRow(label: 'TVA', value: moneyFmt(tvaAmount), bold: false),
                  ],
                  if (fodecEnabled || timbreEnabled || rsEnabled) ...[
                    const SizedBox(height: LinearSpacing.xs),
                    _TotalRow(
                      label: 'TTC',
                      value: moneyFmt(subtotal + fodecAmount + tvaAmount),
                      bold:  false,
                    ),
                  ],
                  if (timbreEnabled) ...[
                    const SizedBox(height: LinearSpacing.xs),
                    _TotalRow(label: 'Timbre fiscal', value: moneyFmt(timbreAmount), bold: false),
                  ],
                  if (rsEnabled && rsAmount > 0) ...[
                    const SizedBox(height: LinearSpacing.xs),
                    _TotalRow(
                      label: 'RS (${rsRate % 1 == 0 ? rsRate.toInt() : rsRate}%)',
                      value: '− ${moneyFmt(rsAmount)}',
                      bold:  false,
                    ),
                  ],
                  const SizedBox(height: LinearSpacing.xs),
                  _TotalRow(
                    label: (fodecEnabled || timbreEnabled || rsEnabled) ? 'Net à payer' : 'Total',
                    value: moneyFmt(netToPay),
                    bold:  true,
                  ),
                ],
              ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table footer: Add line + Insert bundle ─────────────────────────────────────

class _TableFooterActions extends StatelessWidget {
  const _TableFooterActions({
    required this.onAddLine,
    required this.onInsertBundle,
  });

  final VoidCallback            onAddLine;
  final Future<void> Function() onInsertBundle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AddLineButton(onTap: onAddLine),
        SizedBox(
          height: 36,
          child: VerticalDivider(
            width: 1,
            color: context.linearExt.borderSubtle,
          ),
        ),
        _InsertBundleButton(onTap: onInsertBundle),
      ],
    );
  }
}

// ── Add line button ────────────────────────────────────────────────────────────

class _AddLineButton extends StatefulWidget {
  const _AddLineButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddLineButton> createState() => _AddLineButtonState();
}

class _AddLineButtonState extends State<_AddLineButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? ext.overlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base,
            vertical:   LinearSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size:  13,
                color: _hovered ? LinearColors.accent : ext.textMuted,
              ),
              const SizedBox(width: LinearSpacing.xs),
              Text(
                'Add line',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _hovered ? LinearColors.accent : ext.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Insert bundle button ───────────────────────────────────────────────────────

class _InsertBundleButton extends StatefulWidget {
  const _InsertBundleButton({required this.onTap});
  final Future<void> Function() onTap;

  @override
  State<_InsertBundleButton> createState() => _InsertBundleButtonState();
}

class _InsertBundleButtonState extends State<_InsertBundleButton> {
  bool _hovered  = false;
  bool _loading  = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  await widget.onTap();
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? ext.overlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base,
            vertical:   LinearSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color:       _hovered ? LinearColors.accent : ext.textMuted,
                  ),
                )
              else
                Icon(
                  Icons.layers_outlined,
                  size:  13,
                  color: _hovered ? LinearColors.accent : ext.textMuted,
                ),
              const SizedBox(width: LinearSpacing.xs),
              Text(
                'Insert bundle',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _hovered ? LinearColors.accent : ext.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payment term visual selector ───────────────────────────────────────────────

class _PaymentTermSelector extends StatelessWidget {
  const _PaymentTermSelector({
    required this.templates,
    required this.selectedId,
    required this.onChanged,
  });

  final List<PaymentTermTemplate>          templates;
  final String?                            selectedId;
  final ValueChanged<PaymentTermTemplate?> onChanged;

  PaymentTermTemplate? get _selected =>
      templates.where((t) => t.id == selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    final sel  = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Terms',
            style: text.labelSmall?.copyWith(color: ext.textMuted)),
        const SizedBox(height: 4),
        PopupMenuButton<String>(
          tooltip: '',
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
          color: ext.surfaceBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LinearRadii.md),
            side: BorderSide(color: ext.borderSubtle),
          ),
          offset: const Offset(0, 4),
          onSelected: (val) {
            if (val == '__manage__') {
              Navigator.of(context, rootNavigator: false).maybePop();
              context.go('/settings');
              return;
            }
            if (val == '__clear__') {
              onChanged(null);
              return;
            }
            final t = templates.firstWhere((t) => t.id == val);
            onChanged(t);
          },
          itemBuilder: (ctx) => [
            // Clear / none
            if (sel != null)
              PopupMenuItem<String>(
                value: '__clear__',
                padding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.md, vertical: LinearSpacing.sm),
                child: Text('— None',
                    style:
                        text.bodySmall?.copyWith(color: ext.textMuted)),
              ),
            if (sel != null)
              PopupMenuDivider(height: 1),
            // Template options
            ...templates.map((t) => PopupMenuItem<String>(
                  value: t.id,
                  padding: const EdgeInsets.symmetric(
                      horizontal: LinearSpacing.md,
                      vertical: LinearSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.name,
                                style: text.bodySmall?.copyWith(
                                  color: ext.textPrimary,
                                  fontWeight: t.id == selectedId
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                )),
                          ),
                          if (t.id == selectedId)
                            Icon(Icons.check, size: 13,
                                color: LinearColors.accent),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.summary,
                        style: text.labelSmall?.copyWith(
                            color: ext.textMuted),
                      ),
                    ],
                  ),
                )),
            PopupMenuDivider(height: 1),
            // Manage link
            PopupMenuItem<String>(
              value: '__manage__',
              padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.md, vertical: LinearSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 13, color: ext.textMuted),
                  const SizedBox(width: LinearSpacing.xs),
                  Text('Manage payment terms',
                      style: text.labelSmall
                          ?.copyWith(color: ext.textSecondary)),
                ],
              ),
            ),
          ],
          // ── Compact trigger view ────────────────────────────────────────────
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LinearRadii.sm),
              border: Border.all(color: ext.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: sel == null
                      ? Text(
                          templates.isEmpty
                              ? 'Define terms in settings…'
                              : 'Select…',
                          style: text.bodySmall
                              ?.copyWith(color: ext.textMuted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sel.name,
                                style: text.bodySmall
                                    ?.copyWith(color: ext.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              sel.installments
                                  .map((i) =>
                                      '● ${i.percent}% ${i.label}')
                                  .join('  '),
                              style: text.labelSmall
                                  ?.copyWith(color: ext.textMuted),
                            ),
                          ],
                        ),
                ),
                Icon(Icons.expand_more, size: 16, color: ext.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Notes field ────────────────────────────────────────────────────────────────

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      decoration: BoxDecoration(
        color:        ext.surfaceBase,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border:       Border.all(color: ext.borderSubtle),
      ),
      padding: const EdgeInsets.all(LinearSpacing.base),
      child: TextField(
        controller: controller,
        maxLines:   4,
        minLines:   3,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: ext.textPrimary),
        decoration: InputDecoration.collapsed(
          hintText:  'Additional notes, delivery conditions…',
          hintStyle: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: ext.textMuted),
        ),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.base,
          vertical:   LinearSpacing.sm,
        ),
        decoration: BoxDecoration(
          color:        LinearColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border: Border.all(
            color: LinearColors.danger.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size:  14,
              color: LinearColors.danger,
            ),
            const SizedBox(width: LinearSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: LinearColors.danger,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Column header ──────────────────────────────────────────────────────────────

class _ColHdr extends StatelessWidget {
  const _ColHdr(
    this.label, {
    this.right   = false,
    this.center  = false,
    this.padding = EdgeInsets.zero,
  });
  final String     label;
  final bool       right;
  final bool       center;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(
          label,
          textAlign: center ? TextAlign.center : (right ? TextAlign.end : TextAlign.start),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:         context.linearExt.textMuted,
            letterSpacing: 0.2,
          ),
        ),
      );
}

// ── Line row ───────────────────────────────────────────────────────────────────

class _LineRow extends StatefulWidget {
  const _LineRow({
    super.key,
    required this.state,
    required this.number,
    required this.canDelete,
    required this.canIndent,
    required this.canOutdent,
    required this.isParent,
    required this.rollup,
    required this.onChanged,
    required this.onDelete,
    required this.onIndent,
    required this.onOutdent,
  });

  final _LineState   state;
  final String       number;
  final bool         canDelete;
  final bool         canIndent;
  final bool         canOutdent;
  final bool         isParent;
  final double       rollup;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  bool _hovered = false;

  static const _levelLabels = ['Category', 'Sub-category', 'Detail'];

  @override
  Widget build(BuildContext context) {
    final ext      = context.linearExt;
    final isParent = widget.isParent;
    final totalStr = (isParent ? widget.rollup : widget.state.lineTotal).toStringAsFixed(2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color:        _hovered ? ext.overlay : Colors.transparent,
          borderRadius: BorderRadius.circular(LinearRadii.xs),
        ),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Indent / outdent controls — plain tap targets (no IconButton,
            // whose default min tap target overflows this narrow column).
            SizedBox(
              width: _kColIndentW,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ChevronTap(
                    icon:     Icons.chevron_left,
                    enabled:  widget.canOutdent,
                    tooltip:  'Outdent',
                    onTap:    widget.onOutdent,
                  ),
                  Tooltip(
                    message: _levelLabels[widget.state.level],
                    child: Text(
                      widget.number,
                      style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color: [LinearColors.accent, ext.textSecondary, ext.textMuted][widget.state.level],
                      ),
                    ),
                  ),
                  _ChevronTap(
                    icon:     Icons.chevron_right,
                    enabled:  widget.canIndent,
                    tooltip:  'Indent',
                    onTap:    widget.onIndent,
                  ),
                ],
              ),
            ),
            // Product link button (mirrors header spacer)
            SizedBox(
              width: _kColProductW,
              child: isParent
                  ? const SizedBox()
                  : AnimatedOpacity(
                      opacity:  _hovered || widget.state.productId != null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 100),
                      child: Tooltip(
                        message: widget.state.productId != null
                            ? 'Change product'
                            : 'Link product',
                        child: IconButton(
                          icon: Icon(
                            Icons.inventory_2_outlined,
                            size:  12,
                            color: widget.state.productId != null
                                ? LinearColors.accent
                                : context.linearExt.textMuted,
                          ),
                          padding:   EdgeInsets.zero,
                          onPressed: () async {
                            final result = await showProductPicker(
                              context,
                              currentProductId: widget.state.productId,
                              filter: ProductPickerFilter.brandModel,
                            );
                            if (!mounted) return;
                            if (result.cleared) {
                              setState(() => widget.state.productId = null);
                              widget.onChanged();
                            } else if (result.product != null) {
                              setState(() => widget.state.applyProduct(result.product!));
                              widget.onChanged();
                            }
                          },
                        ),
                      ),
                    ),
            ),
            Expanded(
              flex: 5,
              child: _Cell(
                controller: widget.state.labelCtrl,
                hint:       isParent ? 'Category…' : 'Description…',
                bold:       isParent,
                onChanged:  (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColUnitW,
              child: isParent
                  ? const SizedBox()
                  : _Cell(
                      controller: widget.state.unitCtrl,
                      hint:       'u.',
                      textAlign:  TextAlign.end,
                      onChanged:  (_) => widget.onChanged(),
                    ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColQtyW,
              child: isParent
                  ? const SizedBox()
                  : _Cell(
                      controller:      widget.state.qtyCtrl,
                      hint:            '1',
                      textAlign:       TextAlign.end,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                      onChanged: (_) {
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColPriceW,
              child: isParent
                  ? const SizedBox()
                  : _Cell(
                      controller:      widget.state.priceCtrl,
                      hint:            '0.00',
                      textAlign:       TextAlign.end,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                      onChanged: (_) {
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColDiscW,
              child: isParent
                  ? const SizedBox()
                  : _PercentCell(
                      controller: widget.state.discCtrl,
                      onChanged: (_) {
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColTaxW,
              child: isParent
                  ? const SizedBox()
                  : _PercentCell(
                      controller: widget.state.taxCtrl,
                      onChanged: (_) {
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColFodW,
              child: isParent
                  ? const SizedBox()
                  : Center(
                      child: Tooltip(
                        message: 'FODEC 1% (industrial products)',
                        child: Checkbox(
                          value:     widget.state.fodecApplicable,
                          onChanged: (v) {
                            setState(() => widget.state.fodecApplicable = v ?? false);
                            widget.onChanged();
                          },
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: _kColGap),
            SizedBox(
              width: _kColTotalW,
              child: Text(
                totalStr,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:      ext.textPrimary,
                  fontWeight: isParent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: _kColDeleteW,
              child: widget.canDelete
                  ? AnimatedOpacity(
                      opacity:  _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 100),
                      child: IconButton(
                        icon:      Icon(Icons.close, size: 12, color: ext.textMuted),
                        tooltip:   'Remove',
                        padding:   EdgeInsets.zero,
                        onPressed: widget.onDelete,
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chevron tap target (compact — IconButton's default min size overflows) ─────

class _ChevronTap extends StatelessWidget {
  const _ChevronTap({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  final IconData     icon;
  final bool         enabled;
  final String       tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final color = enabled ? ext.textMuted : ext.borderSubtle;
    final child = SizedBox(
      width: 16,
      height: 16,
      child: Icon(icon, size: 13, color: color),
    );
    if (!enabled) return child;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
      ),
    );
  }
}

// ── Text cell ──────────────────────────────────────────────────────────────────

class _Cell extends StatelessWidget {
  const _Cell({
    required this.controller,
    this.hint            = '',
    this.textAlign       = TextAlign.start,
    this.inputFormatters,
    this.onChanged,
    this.bold            = false,
  });

  final TextEditingController     controller;
  final String                    hint;
  final TextAlign                 textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>?     onChanged;
  final bool                      bold;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return TextField(
      controller:      controller,
      textAlign:       textAlign,
      inputFormatters: inputFormatters,
      onChanged:       onChanged,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: ext.textPrimary, fontWeight: bold ? FontWeight.w600 : null),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: ext.textMuted),
        isDense:        true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          borderSide:   BorderSide(color: ext.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ── Percent cell ───────────────────────────────────────────────────────────────

class _PercentCell extends StatelessWidget {
  const _PercentCell({required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return TextField(
      controller:      controller,
      textAlign:       TextAlign.end,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      onChanged:       onChanged,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: ext.textPrimary),
      decoration: InputDecoration(
        hintText: '0',
        suffix: Text(
          ' %',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: ext.textMuted),
        ),
        isDense:        true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          borderSide:   BorderSide(color: ext.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          borderSide: const BorderSide(color: LinearColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ── Total summary row ──────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.bold,
  });

  final String label;
  final String value;
  final bool   bold;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(width: LinearSpacing.xl),
        Text(
          value,
          style: bold
              ? text.bodyMedium?.copyWith(
                  color:      ext.textPrimary,
                  fontWeight: FontWeight.w600,
                )
              : text.bodySmall?.copyWith(color: ext.textSecondary),
        ),
      ],
    );
  }
}

// ── Currency chip ──────────────────────────────────────────────────────────────

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip(this.currency);
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        ext.overlayActive,
        borderRadius: BorderRadius.circular(LinearRadii.pill),
        border:       Border.all(color: ext.borderBase),
      ),
      child: Text(
        currency.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color:         ext.textMuted,
          fontSize:      9,
          letterSpacing: 0.5,
          fontWeight:    FontWeight.w600,
        ),
      ),
    );
  }
}
