import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../modules/org/org_providers.dart';
import 'view_prefs_service.dart';

class FavoritesNotifier extends AsyncNotifier<List<String>> {
  String _key = 'sidebar.favorites';

  @override
  Future<List<String>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    _key = orgId != null ? 'sidebar.favorites.$orgId' : 'sidebar.favorites';
    return await ViewPrefsService.getStringList(_key) ?? [];
  }

  Future<void> toggle(String path) async {
    final current = state.value ?? [];
    final updated = current.contains(path)
        ? current.where((p) => p != path).toList()
        : [...current, path];
    state = AsyncData(updated);
    await ViewPrefsService.setStringList(_key, updated);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value ?? [];
    if (current.length < 2) return;
    final updated = List<String>.from(current);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = AsyncData(updated);
    await ViewPrefsService.setStringList(_key, updated);
  }

  bool contains(String path) => state.value?.contains(path) ?? false;
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<String>>(
  FavoritesNotifier.new,
);
