import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/app_module.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../theme/linear_tokens.dart';

/// Lightweight placeholder modules. Each follows the exact same [AppModule]
/// contract as CRM — replace their pages with real ones as you build them.

class ProjectsModule implements AppModule {
  const ProjectsModule();
  @override
  String get id => 'projects';
  @override
  String get title => 'Projects';
  @override
  IconData get icon => Icons.folder_outlined;
  @override
  String get basePath => '/projects';
  @override
  String? get requiredPermission => null;
  @override
  List<ModuleNavItem> get navItems => const [
        ModuleNavItem(label: 'All projects', icon: Icons.folder_outlined, path: '/projects/all'),
        ModuleNavItem(label: 'Templates', icon: Icons.dashboard_customize_outlined, path: '/projects/templates'),
      ];
  @override
  List<RouteBase> get routes => [
        GoRoute(path: basePath, redirect: (_, _) => '/projects/all'),
        GoRoute(path: '/projects/all', builder: (_, _) => const ComingSoon(icon: Icons.folder_outlined, title: 'All projects')),
        GoRoute(path: '/projects/templates', builder: (_, _) => const ComingSoon(icon: Icons.dashboard_customize_outlined, title: 'Templates')),
      ];
}

/// Shared placeholder page using the standard view header.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearViewHeader(icon: icon, title: title),
        Expanded(
          child: Center(
            child: Text(
              '$title — coming soon',
              style: text.bodyMedium?.copyWith(color: LinearColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
