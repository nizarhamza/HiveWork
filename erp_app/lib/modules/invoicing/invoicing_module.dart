import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/app_module.dart';
import 'invoices_page.dart';
import 'payments_page.dart';

class InvoicingModule implements AppModule {
  const InvoicingModule();

  @override
  String get id => 'invoicing';
  @override
  String get title => 'Invoicing';
  @override
  IconData get icon => Icons.description_outlined;
  @override
  String get basePath => '/invoicing';
  @override
  String? get requiredPermission => null;

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(
          label: 'Invoices',
          icon:  Icons.receipt_long_outlined,
          path:  '/invoicing/invoices',
        ),
        ModuleNavItem(
          label: 'Payments',
          icon:  Icons.payments_outlined,
          path:  '/invoicing/payments',
        ),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(path: basePath, redirect: (_, _) => '/invoicing/invoices'),
        GoRoute(
          path: '/invoicing/invoices',
          builder: (_, state) => InvoicesPage(
            initialInvoiceId: state.uri.queryParameters['invoice'],
          ),
        ),
        GoRoute(
          path: '/invoicing/payments',
          builder: (_, _) => const PaymentsPage(),
        ),
      ];
}
