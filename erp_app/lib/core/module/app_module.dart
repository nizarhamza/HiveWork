import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A nav sub-page within a module (shown nested in the sidebar when the module
/// is active).
class ModuleNavItem {
  const ModuleNavItem({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

/// The contract every feature module must implement.
///
/// Add a module: create a class implementing [AppModule] and append it to
/// [kAppModules] in `core/module/modules.dart`. No other file changes needed.
abstract interface class AppModule {
  String get id;
  String get title;
  IconData get icon;
  String get basePath;

  /// Permission key that gates this module (null = always visible).
  String? get requiredPermission;

  /// Sub-pages shown nested in the sidebar when this module is active.
  List<ModuleNavItem> get navItems;

  /// go_router routes contributed by this module.
  List<RouteBase> get routes;
}

// ── Registry ──────────────────────────────────────────────────────────────────

class ModuleRegistry {
  const ModuleRegistry(this.modules);
  final List<AppModule> modules;

  AppModule? moduleForLocation(String path) {
    for (final m in modules) {
      if (path.startsWith(m.basePath)) return m;
    }
    return null;
  }

  List<RouteBase> get allRoutes => [
        for (final m in modules) ...m.routes,
      ];
}
