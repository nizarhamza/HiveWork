import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../modules/org/org_providers.dart';
import '../models/company.dart';
import '../repositories/company_repository.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(supabaseClientProvider));
});

class CompaniesNotifier extends AsyncNotifier<List<Company>> {
  @override
  Future<List<Company>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    if (orgId == null) return [];
    return ref.read(companyRepositoryProvider).fetchAll(orgId);
  }

  Future<void> create(CompanyInput input) async {
    final company = await ref.read(companyRepositoryProvider).create(input);
    state = AsyncData([...?state.value, company]);
  }

  Future<void> updateCompany(String id, CompanyInput input) async {
    final updated = await ref.read(companyRepositoryProvider).update(id, input);
    state = AsyncData(
      state.value?.map((c) => c.id == id ? updated : c).toList() ?? [],
    );
  }

  Future<void> delete(String id) async {
    final orgId = await ref.read(currentOrgIdProvider.future);
    if (orgId == null) return;
    await ref.read(companyRepositoryProvider).delete(id, orgId);
    state = AsyncData(state.value?.where((c) => c.id != id).toList() ?? []);
  }
}

final companiesProvider =
    AsyncNotifierProvider<CompaniesNotifier, List<Company>>(
        CompaniesNotifier.new);
