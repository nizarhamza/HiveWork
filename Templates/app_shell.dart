import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/module/app_module.dart';
import '../core/module/modules.dart';
import '../theme/linear_tokens.dart';
import 'widgets/linear_sidebar_item.dart';
import 'widgets/resizable_pane_layout.dart';

/// Below this width the sidebar collapses into a drawer.
const double kExpandedBreakpoint = 820;

const double _kSidebarMin = 160.0;
const double _kSidebarMax = 400.0;

/// The workspace name shown in the sidebar switcher.
const String kWorkspaceName = 'Enernetpro';

/// Wraps every routed page: one sidebar (workspace switcher + grouped nav) plus
/// the routed [child] as content. The sidebar edge is draggable to resize.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late double _sidebarWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sidebarWidth = context.linearTokens.sidebarWidth;
  }

  void _onSidebarDrag(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(_kSidebarMin, _kSidebarMax);
    });
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(moduleRegistryProvider);
    final location = GoRouterState.of(context).uri.path;
    final activeModule = registry.moduleForLocation(location);
    final isWide = MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;

    final sidebar = _Sidebar(
      modules: registry.modules,
      activeModule: activeModule,
      location: location,
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: LinearColors.pageBg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: _sidebarWidth, child: sidebar),
            ResizablePaneDivider(onDrag: _onSidebarDrag),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: LinearColors.pageBg,
      appBar: AppBar(title: const Text(kWorkspaceName)),
      drawer: Drawer(
        width: _sidebarWidth,
        backgroundColor: LinearColors.surfaceBase,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(child: sidebar),
      ),
      body: widget.child,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.modules,
    required this.activeModule,
    required this.location,
  });

  final List<AppModule> modules;
  final AppModule? activeModule;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LinearColors.surfaceBase,
      padding: const EdgeInsets.all(LinearSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WorkspaceSwitcher(),
          const SizedBox(height: LinearSpacing.xs),

          // Top cluster
          LinearSidebarItem(
            label: 'Inbox',
            icon: Icons.inbox_outlined,
            onTap: () {},
          ),
          LinearSidebarItem(
            label: 'My work',
            icon: Icons.grid_view_outlined,
            onTap: () {},
          ),

          // Workspace = the modules, with the active module's pages nested
          const _SectionLabel('Workspace'),
          for (final m in modules) ...[
            LinearSidebarItem(
              label: m.title,
              icon: m.icon,
              onTap: () => context.go(m.basePath),
            ),
            if (m.id == activeModule?.id)
              for (final item in m.navItems)
                LinearSidebarItem(
                  label: item.label,
                  icon: item.icon,
                  indent: LinearSpacing.xl,
                  selected: location == item.path,
                  onTap: () => context.go(item.path),
                ),
          ],

          // Favorites
          const _SectionLabel('Favorites'),
          LinearSidebarItem(
            label: 'Contacts',
            icon: Icons.person_outline,
            trailing: const Icon(Icons.star, size: 12, color: LinearColors.textMuted),
            onTap: () => context.go('/crm/contacts'),
          ),

          const Spacer(),
          const _UserRow(),
        ],
      ),
    );
  }
}

class _WorkspaceSwitcher extends StatelessWidget {
  const _WorkspaceSwitcher();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: const WidgetStatePropertyAll(LinearColors.overlay),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: LinearColors.accent,
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'E',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Text(kWorkspaceName, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: LinearSpacing.xxs),
              const Icon(Icons.keyboard_arrow_down, size: 14, color: LinearColors.textMuted),
              const Spacer(),
              const _MiniIcon(Icons.search),
              const _MiniIcon(Icons.edit_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: LinearSpacing.xxs),
      child: Icon(icon, size: 15, color: LinearColors.textMuted),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LinearSpacing.sm,
        LinearSpacing.base,
        LinearSpacing.sm,
        LinearSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: LinearColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: LinearSpacing.xs),
          const Icon(Icons.keyboard_arrow_down, size: 13, color: LinearColors.textMuted),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF6E56CF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'NT',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: LinearSpacing.sm),
            Expanded(
              child: Text('Nizar Thabouti',
                  style: text.bodySmall?.copyWith(color: LinearColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 14, color: LinearColors.textMuted),
              tooltip: '',
              color: LinearColors.surfaceBase,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LinearRadii.sm),
                side: const BorderSide(color: LinearColors.borderSubtle),
              ),
              elevation: 4,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: const [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: LinearColors.textSecondary),
                      SizedBox(width: 8),
                      Text('Switch org', style: TextStyle(fontSize: 13, color: LinearColors.textSecondary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: const [
                      Icon(Icons.logout_rounded, size: 14, color: LinearColors.textSecondary),
                      SizedBox(width: 8),
                      Text('Sign out', style: TextStyle(fontSize: 13, color: LinearColors.textSecondary)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                // wire up sign-out / switch-org via providers
              },
            ),
          ],
        ),
      ),
    );
  }
}
