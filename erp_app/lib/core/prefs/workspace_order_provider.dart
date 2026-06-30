import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/org/org_providers.dart';
import '../module/app_module.dart';
import 'view_prefs_service.dart';

class WorkspaceOrderNotifier extends AsyncNotifier<List<String>> {
  String _key = 'sidebar.workspaceOrder';

  @override
  Future<List<String>> build() async {
    final orgId = await ref.watch(currentOrgIdProvider.future);
    _key = orgId != null
        ? 'sidebar.workspaceOrder.$orgId'
        : 'sidebar.workspaceOrder';
    return await ViewPrefsService.getStringList(_key) ?? [];
  }

  Future<void> reorder(
      int oldIndex, int newIndex, List<AppModule> modules) async {
    final defaultOrder = modules.map((m) => m.id).toList();
    final current =
        (state.value?.isNotEmpty ?? false) ? state.value! : defaultOrder;
    final updated = List<String>.from(current);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = AsyncData(updated);
    await ViewPrefsService.setStringList(_key, updated);
  }

  List<AppModule> applyTo(List<AppModule> modules) {
    final order = state.value ?? [];
    if (order.isEmpty) return modules;
    final map = {for (final m in modules) m.id: m};
    final result = <AppModule>[];
    for (final id in order) {
      if (map.containsKey(id)) result.add(map[id]!);
    }
    for (final m in modules) {
      if (!order.contains(m.id)) result.add(m);
    }
    return result;
  }
}

final workspaceOrderProvider =
    AsyncNotifierProvider<WorkspaceOrderNotifier, List<String>>(
  WorkspaceOrderNotifier.new,
);
