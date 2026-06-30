import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/app_module.dart';
import 'bundles_page.dart';
import 'products_page.dart';
import 'suppliers_page.dart';

class InventoryModule implements AppModule {
  const InventoryModule();

  @override
  String get id => 'inventory';
  @override
  String get title => 'Inventory';
  @override
  IconData get icon => Icons.inventory_2_outlined;
  @override
  String get basePath => '/inventory';
  @override
  String? get requiredPermission => null;

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(
          label: 'Products',
          icon:  Icons.category_outlined,
          path:  '/inventory/products',
        ),
        ModuleNavItem(
          label: 'Bundles',
          icon:  Icons.layers_outlined,
          path:  '/inventory/bundles',
        ),
        ModuleNavItem(
          label: 'Suppliers',
          icon:  Icons.local_shipping_outlined,
          path:  '/inventory/suppliers',
        ),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(path: basePath, redirect: (_, _) => '/inventory/products'),
        GoRoute(
          path:    '/inventory/products',
          builder: (_, _) => const ProductsPage(),
        ),
        GoRoute(
          path:    '/inventory/bundles',
          builder: (_, _) => const BundlesPage(),
        ),
        GoRoute(
          path:    '/inventory/suppliers',
          builder: (_, _) => const SuppliersPage(),
        ),
      ];
}
