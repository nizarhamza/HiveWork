import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';
import '../models/quote.dart';

class InvoiceRepository {
  const InvoiceRepository(this._client);
  final SupabaseClient _client;

  static const _table      = 'invoices';
  static const _linesTable = 'invoice_lines';
  static const _selectJoin = '*, companies(id, name), contacts(id, first_name, last_name)';
  static const _selectInvoice =
      'id, org_id, number, company_id, contact_id, client_snapshot, quote_id, currency, '
      'subtotal, tax, total, issue_date, due_date, status, notes, '
      'created_at, updated_at, objet, contract_number, payment_mode, '
      'payment_term_template_id, payment_term_snapshot, '
      'fodec_enabled, fodec_rate, timbre_enabled, timbre_amount, rs_enabled, rs_rate';
  static const _selectLines =
      'id, org_id, invoice_id, product_id, parent_id, label, unit, '
      'qty, unit_price, tax_rate, discount_rate, line_total, position, fodec_applicable';

  // ── List ─────────────────────────────────────────────────────────────────────

  Future<List<InvoiceWithClient>> fetchAll(String orgId) async {
    final rows = await _client
        .from(_table)
        .select(_selectJoin)
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(1000);
    return (rows as List)
        .map((r) => InvoiceWithClient.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Single ────────────────────────────────────────────────────────────────────

  Future<Invoice?> fetchById(String id, String orgId) async {
    final row = await _client
        .from(_table)
        .select(_selectInvoice)
        .eq('id', id)
        .eq('org_id', orgId)
        .maybeSingle();
    if (row == null) return null;

    final linesRows = await _client
        .from(_linesTable)
        .select(_selectLines)
        .eq('invoice_id', id)
        .order('position', ascending: true);

    final lines = (linesRows as List)
        .map((r) => InvoiceLine.fromJson(r as Map<String, dynamic>))
        .toList();

    return Invoice.fromJson(row).copyWith(lines: lines);
  }

  // ── Create ────────────────────────────────────────────────────────────────────

  Future<InvoiceWithClient> create(InvoiceInput input) async {
    final number = await _client
        .rpc('generate_invoice_number', params: {'p_org_id': input.orgId}) as String;

    final row = await _client
        .from(_table)
        .insert({...input.toInvoiceJson(), 'number': number})
        .select(_selectJoin)
        .single();
    final created = InvoiceWithClient.fromJson(row);

    await _insertLinesWithHierarchy(input.orgId, created.invoice.id, input.lines);

    return created;
  }

  // ── Update ────────────────────────────────────────────────────────────────────

  Future<InvoiceWithClient> update(String id, InvoiceInput input) async {
    final existingRows = await _client
        .from(_linesTable)
        .select('id')
        .eq('invoice_id', id) as List;
    final existingIds =
        existingRows.map((r) => r['id'] as String).toList();

    await _insertLinesWithHierarchy(input.orgId, id, input.lines);

    if (existingIds.isNotEmpty) {
      await _client
          .from(_linesTable)
          .delete()
          .inFilter('id', existingIds);
    }

    final row = await _client
        .from(_table)
        .update(input.toInvoiceJson())
        .eq('id', id)
        .select(_selectJoin)
        .single();

    return InvoiceWithClient.fromJson(row);
  }

  // ── Update status ─────────────────────────────────────────────────────────────

  Future<void> updateStatus(String id, String orgId, InvoiceStatus status) async {
    await _client
        .from(_table)
        .update({'status': status.name})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  Future<void> delete(String id, String orgId) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
  }

  // ── Convert from quote ────────────────────────────────────────────────────────

  /// Creates an invoice from an approved [quote] and marks the quote converted.
  Future<InvoiceWithClient> convertFromQuote(Quote quote) async {
    final flatLines = _flattenQuoteLines(quote.lines);
    final input = InvoiceInput(
      orgId:         quote.orgId,
      companyId:     quote.companyId,
      contactId:     quote.contactId,
      clientName:         quote.clientSnapshotName,
      clientAddress:      quote.clientSnapshotAddress,
      clientPhone:        quote.clientSnapshotPhone,
      clientTaxId:        quote.clientSnapshotTaxId,
      clientCustomFields: quote.clientSnapshotCustomFields.isEmpty ? null : quote.clientSnapshotCustomFields,
      quoteId:            quote.id,
      currency:      quote.currency,
      status:        InvoiceStatus.draft,
      issueDate:     DateTime.now(),
      dueDate:       DateTime.now().add(const Duration(days: 30)),
      notes:         quote.notes,
      objet:                 quote.objet,
      contractNumber:        quote.contractNumber,
      paymentMode:           quote.paymentMode,
      paymentTermTemplateId: quote.paymentTermTemplateId,
      paymentTermSnapshot:   quote.paymentTermSnapshot,
      fodecEnabled:    quote.fodecEnabled,
      fodecRate:       quote.fodecRate,
      timbreEnabled:   quote.timbreEnabled,
      timbreAmount:    quote.timbreAmount,
      rsEnabled:       quote.rsEnabled,
      rsRate:          quote.rsRate,
      lines: flatLines,
    );

    final created = await create(input);

    // Mark the quote as converted.
    await _client
        .from('quotes')
        .update({
          'status':               'converted',
          'converted_invoice_id': created.invoice.id,
        })
        .eq('id', quote.id)
        .eq('org_id', quote.orgId);

    return created;
  }

  // ── Internal: hierarchical line insert ───────────────────────────────────────

  Future<void> _insertLinesWithHierarchy(
    String orgId,
    String invoiceId,
    List<InvoiceLineInput> lines,
  ) async {
    if (lines.isEmpty) return;

    final stack     = <int>[];
    final parentIdx = List<int?>.filled(lines.length, null);
    for (var i = 0; i < lines.length; i++) {
      final level = lines[i].level;
      while (stack.length > level) {
        stack.removeLast();
      }
      parentIdx[i] = stack.isEmpty ? null : stack.last;
      stack.add(i);
    }

    final realId   = List<String?>.filled(lines.length, null);
    final maxLevel = lines.map((l) => l.level).fold(0, (a, b) => a > b ? a : b);

    for (var level = 0; level <= maxLevel; level++) {
      final idxAtLevel = [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].level == level) i,
      ];
      if (idxAtLevel.isEmpty) continue;

      final payload = idxAtLevel
          .map((i) => lines[i].toJson(
                orgId,
                invoiceId,
                parentId: parentIdx[i] == null ? null : realId[parentIdx[i]!],
              ))
          .toList();

      final rows =
          await _client.from(_linesTable).insert(payload).select('id') as List;
      for (var k = 0; k < idxAtLevel.length; k++) {
        realId[idxAtLevel[k]] = rows[k]['id'] as String;
      }
    }
  }
}

// Flattens quote lines into the level-tagged list that InvoiceLineInput expects.
List<InvoiceLineInput> _flattenQuoteLines(List<QuoteLine> lines) {
  final byParent = <String?, List<QuoteLine>>{};
  for (final l in lines) {
    byParent.putIfAbsent(l.parentId, () => []).add(l);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.position.compareTo(b.position));
  }
  final out = <InvoiceLineInput>[];
  void walk(QuoteLine l, int depth) {
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
    for (final child in byParent[l.id] ?? const <QuoteLine>[]) {
      walk(child, depth + 1);
    }
  }
  for (final root in byParent[null] ?? const <QuoteLine>[]) {
    walk(root, 0);
  }
  return out;
}
