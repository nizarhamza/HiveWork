import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/payment_term_template.dart';
import '../org/org_providers.dart';
import 'payment_term_repository.dart';

class PaymentTermsNotifier
    extends AsyncNotifier<List<PaymentTermTemplate>> {
  @override
  Future<List<PaymentTermTemplate>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(paymentTermRepositoryProvider).fetchAll(orgId);
  }

  Future<void> create(PaymentTermTemplateInput input) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    final t =
        await ref.read(paymentTermRepositoryProvider).create(orgId, input);
    state = AsyncData([...?state.value, t]);
  }

  Future<void> save(String id, PaymentTermTemplateInput input) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    final t = await ref
        .read(paymentTermRepositoryProvider)
        .update(id, orgId, input);
    state = AsyncData(
      state.value?.map((e) => e.id == id ? t : e).toList() ?? [t],
    );
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(paymentTermRepositoryProvider).delete(id, orgId);
    state = AsyncData(
      state.value?.where((e) => e.id != id).toList() ?? [],
    );
  }
}

final paymentTermsProvider =
    AsyncNotifierProvider<PaymentTermsNotifier, List<PaymentTermTemplate>>(
  PaymentTermsNotifier.new,
);
