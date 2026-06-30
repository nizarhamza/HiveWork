import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quote.dart';

class QuoteRepository {
  const QuoteRepository(this._client);
  final SupabaseClient _client;

  static const _table      = 'quotes';
  static const _linesTable = 'quote_lines';
  static const _selectJoin = '*, clients(id, name)';
  static const _selectQuote =
      'id, org_id, number, client_id, client_snapshot, currency, '
      'subtotal, tax, total, valid_until, status, converted_invoice_id, notes, '
      'created_at, updated_at, objet, contract_number, payment_mode, '
      'payment_term_template_id, payment_term_snapshot, '
      'fodec_enabled, fodec_rate, timbre_enabled, timbre_amount, rs_enabled, rs_rate';
  static const _selectLines =
      'id, org_id, quote_id, product_id, parent_id, label, unit, '
      'qty, unit_price, tax_rate, discount_rate, line_total, position, fodec_applicable';

  // ── List ─────────────────────────────────────────────────────────────────────

  /// Returns quotes for [orgId], newest first.  Capped at 1000 rows; add
  /// cursor pagination once tenants approach that threshold (D-3).
  Future<List<QuoteWithClient>> fetchAll(String orgId) async {  // S-2: orgId required
    final rows = await _client
        .from(_table)
        .select(_selectJoin)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(1000);
    return (rows as List)
        .map((r) => QuoteWithClient.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Single ────────────────────────────────────────────────────────────────────

  Future<Quote?> fetchById(String id, String orgId) async {  // S-3: orgId required
    final row = await _client
        .from(_table)
        .select(_selectQuote)
        .eq('id', id)
        .eq('org_id', orgId)    // ownership check in query
        .maybeSingle();
    if (row == null) return null;

    final linesRows = await _client
        .from(_linesTable)
        .select(_selectLines)
        .eq('quote_id', id)
        .order('position', ascending: true);

    final lines = (linesRows as List)
        .map((r) => QuoteLine.fromJson(r as Map<String, dynamic>))
        .toList();

    return Quote.fromJson(row).copyWith(lines: lines);
  }

  // ── Create ────────────────────────────────────────────────────────────────────

  Future<QuoteWithClient> create(QuoteInput input) async {
    // S-4: number generated atomically server-side — no race condition.
    // Requires migration 20260626000002_quote_number_atomic.sql to be applied.
    final number = await _client
        .rpc('generate_quote_number', params: {'p_org_id': input.orgId}) as String;

    final row = await _client
        .from(_table)
        .insert({...input.toQuoteJson(), 'number': number})
        .select(_selectJoin)
        .single();
    final created = QuoteWithClient.fromJson(row);

    await _insertLinesWithHierarchy(input.orgId, created.quote.id, input.lines);

    return created;
  }

  // ── Update (D-1: insert-then-delete so data survives a mid-flight error) ──────

  Future<QuoteWithClient> update(String id, QuoteInput input) async {
    // Snapshot the IDs of existing lines before changing anything.
    final existingRows = await _client
        .from(_linesTable)
        .select('id')
        .eq('quote_id', id) as List;
    final existingIds =
        existingRows.map((r) => r['id'] as String).toList();

    // 1. Insert new lines first.  If this throws, old lines are still intact.
    await _insertLinesWithHierarchy(input.orgId, id, input.lines);

    // 2. Delete old lines only after new ones are safely committed.
    if (existingIds.isNotEmpty) {
      await _client
          .from(_linesTable)
          .delete()
          .inFilter('id', existingIds);
    }

    // 3. Update the quote header.
    final row = await _client
        .from(_table)
        .update(input.toQuoteJson())
        .eq('id', id)
        .select(_selectJoin)
        .single();

    return QuoteWithClient.fromJson(row);
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  Future<void> delete(String id, String orgId) async {
    // Soft-delete the quote header. Lines remain associated but become
    // inaccessible once the parent is filtered out by deleted_at IS NULL.
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  // ── Internal: hierarchical line insert ───────────────────────────────────────

  /// Inserts [lines] level-by-level so that a category/sub-category row's
  /// real id is known before its children are inserted (the FK requires a
  /// real `parent_id`). A line's parent is the nearest preceding line in
  /// the list whose level is exactly one less — i.e. outline-style indent,
  /// matching the OBAT template's 1 / 1.1 / 1.1.1 numbering.
  Future<void> _insertLinesWithHierarchy(
    String orgId,
    String quoteId,
    List<QuoteLineInput> lines,
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
                quoteId,
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
