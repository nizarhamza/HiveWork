import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/app_module.dart';
import 'pipeline_page.dart';
import 'quotes_page.dart';

class SalesModule implements AppModule {
  const SalesModule();

  @override
  String get id => 'sales';
  @override
  String get title => 'Sales';
  @override
  IconData get icon => Icons.trending_up;
  @override
  String get basePath => '/sales';
  @override
  String? get requiredPermission => null;

  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(label: 'Pipeline', icon: Icons.view_kanban_outlined,    path: '/sales/pipeline'),
        ModuleNavItem(label: 'Quotes',   icon: Icons.request_quote_outlined,  path: '/sales/quotes'),
      ];

  @override
  List<RouteBase> get routes => [
        GoRoute(path: basePath, redirect: (_, _) => '/sales/pipeline'),
        GoRoute(
          path: '/sales/pipeline',
          builder: (_, state) => PipelinePage(
            initialDealId: state.uri.queryParameters['deal'],
          ),
        ),
        GoRoute(
          path: '/sales/quotes',
          builder: (_, state) => QuotesPage(
            initialQuoteId: state.uri.queryParameters['quote'],
          ),
        ),
      ];
}
