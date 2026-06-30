import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/app_module.dart';
import 'companies_page.dart';
import 'contacts_page.dart';

class CrmModule implements AppModule {
  const CrmModule();

  @override
  String get id => 'crm';
  @override
  String get title => 'CRM';
  @override
  IconData get icon => Icons.people_outline;
  @override
  String get basePath => '/crm';
  @override
  String? get requiredPermission => null;

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(label: 'Contacts',  icon: Icons.person_outline,    path: '/crm/contacts'),
        ModuleNavItem(label: 'Companies', icon: Icons.business_outlined,  path: '/crm/companies'),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(path: basePath, redirect: (_, _) => '/crm/contacts'),
        GoRoute(
          path: '/crm/contacts',
          builder: (_, state) => ContactsPage(
            initialContactId: state.uri.queryParameters['contact'],
          ),
        ),
        GoRoute(
          path: '/crm/companies',
          builder: (_, _) => const CompaniesPage(),
        ),
      ];
}
