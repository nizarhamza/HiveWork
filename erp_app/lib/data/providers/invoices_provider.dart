import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/invoice.dart';
import '../models/quote.dart';
import '../repositories/invoice_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(supabaseClientProvider));
});

/// Loads a single invoice with its line items, org-scoped.
final invoiceWithLinesProvider =
    FutureProvider.family<Invoice?, String>((ref, id) async {
  final orgId = await ref.watch(currentOrgIdProvider.future);
  if (orgId == null) return null;
  return ref.read(invoiceRepositoryProvider).fetchById(id, orgId);
});

// ── All invoices (list view) ───────────────────────────────────────────────────

class InvoicesNotifier extends AsyncNotifier<List<InvoiceWithClient>> {
  @override
  Future<List<InvoiceWithClient>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(invoiceRepositoryProvider).fetchAll(orgId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> create(InvoiceInput input) async {
    await ref.read(invoiceRepositoryProvider).create(input);
    await refresh();
  }

  Future<void> updateInvoice(String id, InvoiceInput input) async {
    await ref.read(invoiceRepositoryProvider).update(id, input);
    ref.invalidate(invoiceWithLinesProvider(id));
    await refresh();
  }

  Future<void> updateStatus(String id, InvoiceStatus status) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(invoiceRepositoryProvider).updateStatus(id, orgId, status);
    ref.invalidate(invoiceWithLinesProvider(id));
    state = AsyncData(
      state.value?.map((i) {
        if (i.invoice.id != id) return i;
        return InvoiceWithClient(
          invoice: i.invoice.copyWith(),
          clientName: i.clientName,
        );
      }).toList() ?? [],
    );
    await refresh();
  }

  Future<InvoiceWithClient?> convertFromQuote(Quote quote) async {
    final result = await ref.read(invoiceRepositoryProvider).convertFromQuote(quote);
    await refresh();
    return result;
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(invoiceRepositoryProvider).delete(id, orgId);
    state = AsyncData(
      state.value?.where((i) => i.invoice.id != id).toList() ?? [],
    );
  }
}

final invoicesProvider =
    AsyncNotifierProvider<InvoicesNotifier, List<InvoiceWithClient>>(
        InvoicesNotifier.new);
