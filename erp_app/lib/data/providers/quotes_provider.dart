import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/quote.dart';
import '../repositories/quote_repository.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(ref.watch(supabaseClientProvider));
});

/// Loads a single quote with its line items, org-scoped (S-3).
final quoteWithLinesProvider =
    FutureProvider.family<Quote?, String>((ref, id) async {
  final orgId = await ref.watch(currentOrgIdProvider.future);
  if (orgId == null) return null;
  return ref.read(quoteRepositoryProvider).fetchById(id, orgId);
});

// ── All quotes (list view) ─────────────────────────────────────────────────────

class QuotesNotifier extends AsyncNotifier<List<QuoteWithClient>> {
  @override
  Future<List<QuoteWithClient>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);  // S-2
    if (orgId == null) return [];
    return ref.read(quoteRepositoryProvider).fetchAll(orgId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> create(QuoteInput input) async {
    await ref.read(quoteRepositoryProvider).create(input);
    await refresh();
  }

  Future<void> updateQuote(String id, QuoteInput input) async {
    await ref.read(quoteRepositoryProvider).update(id, input);
    ref.invalidate(quoteWithLinesProvider(id));
    await refresh();
  }

  Future<void> updateStatus(String id, QuoteStatus status) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(quoteRepositoryProvider).updateStatus(id, orgId, status);
    ref.invalidate(quoteWithLinesProvider(id));
    await refresh();
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(quoteRepositoryProvider).delete(id, orgId);
    state = AsyncData(
      state.value?.where((q) => q.quote.id != id).toList() ?? [],
    );
  }
}

final quotesProvider =
    AsyncNotifierProvider<QuotesNotifier, List<QuoteWithClient>>(
        QuotesNotifier.new);
