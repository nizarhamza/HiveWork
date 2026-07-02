import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import '../core/module/app_module.dart';
import '../core/module/modules.dart';
import '../core/prefs/favorites_provider.dart';
import '../core/prefs/view_prefs_service.dart';
import '../core/prefs/workspace_order_provider.dart';
import '../data/providers/auth_providers.dart';
import '../modules/org/org_providers.dart';
import '../theme/linear_tokens.dart';
import '../ui/organisms/app_toast.dart';
import '../ui/organisms/command_palette.dart';
import 'app_commands.dart';
import 'widgets/linear_sidebar_item.dart';
import 'widgets/resizable_pane_layout.dart';

const double kExpandedBreakpoint = 820;
const String kWorkspaceName = 'Enernetpro';
const double _kSidebarMin = 160.0;
const double _kSidebarMax = 400.0;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // sidebarWidth matches LinearTokens.sidebarWidth constant (232).
  double _sidebarWidth = 232;
  Timer? _saveSidebarTimer;
  String? _lastSavedRoute;

  @override
  void initState() {
    super.initState();
    ViewPrefsService.getDouble('shell.sidebarWidth', 232).then((w) {
      if (mounted) setState(() => _sidebarWidth = w);
    });
  }

  @override
  void dispose() {
    _saveSidebarTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry     = ref.watch(moduleRegistryProvider);
    final location     = GoRouterState.of(context).uri.path;
    if (location != _lastSavedRoute) {
      _lastSavedRoute = location;
      ViewPrefsService.setString('shell.lastRoute', location);
    }
    final activeModule = registry.moduleForLocation(location);
    final isWide       = MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;
    final paletteOpen  = ref.watch(commandPaletteOpenProvider);

    final sidebar = _Sidebar(
      modules: registry.modules,
      activeModule: activeModule,
      location: location,
    );

    final child = widget.child;

    final body = isWide
        ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: _sidebarWidth, child: sidebar),
            ResizablePaneDivider(
              onDrag: (delta) {
                setState(() {
                  _sidebarWidth = (_sidebarWidth + delta)
                      .clamp(_kSidebarMin, _kSidebarMax);
                });
                _saveSidebarTimer?.cancel();
                _saveSidebarTimer = Timer(const Duration(milliseconds: 400), () {
                  ViewPrefsService.setDouble('shell.sidebarWidth', _sidebarWidth);
                });
              },
            ),
            Expanded(child: child),
          ])
        : child;

    return AppCommands(
      child: Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const ShowCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const ShowCommandPaletteIntent(),
      },
      child: Actions(
        actions: {
          ShowCommandPaletteIntent: CallbackAction<ShowCommandPaletteIntent>(
            onInvoke: (_) {
              ref.read(commandPaletteOpenProvider.notifier).open();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Builder(builder: (ctx) {
            final ext = ctx.linearExt;
            return Scaffold(
            backgroundColor: ext.pageBg,
            appBar: isWide
                ? null
                : AppBar(
                    title: const Text(kWorkspaceName),
                    backgroundColor: ext.surfaceBase,
                  ),
            drawer: isWide
                ? null
                : Drawer(
                    width: _sidebarWidth,
                    backgroundColor: ext.surfaceBase,
                    shape: const RoundedRectangleBorder(),
                    child: SafeArea(child: sidebar),
                  ),
            body: Stack(
              children: [
                body,
                if (paletteOpen) const CommandPalette(),
                const ToastOverlay(),
              ],
            ),
          );
          }),
        ),
      ),
    ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

// Tracks whether the last sidebar navigation came from Favorites.
// When true, the Workspace module sub-items stay collapsed.
class _FromFavoritesNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final _fromFavoritesProvider =
    NotifierProvider<_FromFavoritesNotifier, bool>(_FromFavoritesNotifier.new);

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({
    required this.modules,
    required this.activeModule,
    required this.location,
  });

  final List<AppModule> modules;
  final AppModule? activeModule;
  final String location;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  bool _workspaceCollapsed = false;
  bool _favoritesCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final ext         = context.linearExt;
    final favorites   = ref.watch(favoritesProvider).value ?? [];
    final favNotifier = ref.read(favoritesProvider.notifier);
    final fromFavs    = ref.watch(_fromFavoritesProvider);
    final fromFavsSet = ref.read(_fromFavoritesProvider.notifier);
    final wsOrder     = ref.watch(workspaceOrderProvider);
    final wsNotifier  = ref.read(workspaceOrderProvider.notifier);

    final allNavItems = <String, ModuleNavItem>{
      for (final m in widget.modules)
        for (final item in m.navItems) item.path: item,
    };

    final orderedModules = wsOrder.maybeWhen(
      data: (_) => wsNotifier.applyTo(widget.modules),
      orElse: () => widget.modules,
    );

    void goWorkspace(String path) {
      fromFavsSet.set(false);
      context.go(path);
    }

    void goFavorite(String path) {
      fromFavsSet.set(true);
      context.go(path);
    }

    final expandedModuleId = fromFavs ? null : widget.activeModule?.id;

    // Favorites list filtered to only known nav items.
    final visibleFavs =
        favorites.where((p) => allNavItems.containsKey(p)).toList();

    return Container(
      color: ext.surfaceBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fixed top ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LinearSpacing.sm, LinearSpacing.sm, LinearSpacing.sm, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WorkspaceSwitcher(),
                const SizedBox(height: LinearSpacing.xs),
                const _SearchButton(),
                const SizedBox(height: LinearSpacing.xs),
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
                LinearSidebarItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  selected: widget.location.startsWith('/settings'),
                  onTap: () => goWorkspace('/settings'),
                ),
              ],
            ),
          ),

          // ── Scrollable middle ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Workspace section
                  _SectionLabel(
                    'Workspace',
                    isCollapsed: _workspaceCollapsed,
                    onToggle: () => setState(
                        () => _workspaceCollapsed = !_workspaceCollapsed),
                  ),
                  if (!_workspaceCollapsed)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      padding: EdgeInsets.zero,
                      onReorderItem: (oldIndex, newIndex) => wsNotifier.reorder(
                          oldIndex, newIndex, orderedModules),
                      children: [
                        for (int i = 0; i < orderedModules.length; i++)
                          Column(
                            key: ValueKey(orderedModules[i].id),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LinearSidebarItem(
                                label: orderedModules[i].title,
                                icon: orderedModules[i].icon,
                                reorderIndex: i,
                                onTap: () =>
                                    goWorkspace(orderedModules[i].basePath),
                              ),
                              if (orderedModules[i].id == expandedModuleId)
                                for (final item in orderedModules[i].navItems)
                                  LinearSidebarItem(
                                    label: item.label,
                                    icon: item.icon,
                                    indent: LinearSpacing.xl,
                                    selected: widget.location == item.path,
                                    isFavorited: favorites.contains(item.path),
                                    onFavorite: () =>
                                        favNotifier.toggle(item.path),
                                    onTap: () => goWorkspace(item.path),
                                  ),
                            ],
                          ),
                      ],
                    ),

                  // Favorites section
                  if (visibleFavs.isNotEmpty) ...[
                    _SectionLabel(
                      'Favorites',
                      isCollapsed: _favoritesCollapsed,
                      onToggle: () => setState(
                          () => _favoritesCollapsed = !_favoritesCollapsed),
                    ),
                    if (!_favoritesCollapsed)
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        padding: EdgeInsets.zero,
                        onReorderItem: (oldIndex, newIndex) =>
                            favNotifier.reorder(oldIndex, newIndex),
                        children: [
                          for (int i = 0; i < visibleFavs.length; i++)
                            LinearSidebarItem(
                              key: ValueKey(visibleFavs[i]),
                              label: allNavItems[visibleFavs[i]]!.label,
                              icon: allNavItems[visibleFavs[i]]!.icon,
                              selected: widget.location == visibleFavs[i],
                              isFavorited: true,
                              reorderIndex: i,
                              onFavorite: () =>
                                  favNotifier.toggle(visibleFavs[i]),
                              onTap: () => goFavorite(visibleFavs[i]),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),

          // ── Fixed bottom ───────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(
              LinearSpacing.sm, 0, LinearSpacing.sm, LinearSpacing.sm,
            ),
            child: _UserRow(),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _WorkspaceSwitcher extends ConsumerWidget {
  const _WorkspaceSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentOrgMembershipProvider);
    // Show blank while loading so we never flash the hardcoded fallback.
    final orgName = membership.isLoading
        ? ''
        : (membership.value?.orgName ?? kWorkspaceName);
    final logoUrl = membership.value?.orgLogoUrl;
    final initial = orgName.isNotEmpty ? orgName[0].toUpperCase() : 'E';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: WidgetStatePropertyAll(context.linearExt.overlay),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm, vertical: 6,
          ),
          child: Row(
            children: [
              if (logoUrl != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 60, minWidth: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    child: Image.network(
                      logoUrl,
                      height: 20, fit: BoxFit.contain,
                      errorBuilder: (_, e, s) => _OrgInitialBox(initial: initial),
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  child: _OrgInitialBox(initial: initial),
                ),
              const SizedBox(width: LinearSpacing.sm),
              Text(orgName,
                style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgInitialBox extends StatelessWidget {
  const _OrgInitialBox({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF6872D6), LinearColors.accent],
        ),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      alignment: Alignment.center,
      child: Text(initial,
        style: const TextStyle(
          color: Colors.white, fontSize: 11,
          fontWeight: FontWeight.w700, fontFamily: 'Inter',
        )),
    );
  }
}

class _SearchButton extends ConsumerWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = context.linearExt;
    return GestureDetector(
      onTap: () => ref.read(commandPaletteOpenProvider.notifier).open(),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm),
        decoration: BoxDecoration(
          color: ext.surfaceRaised,
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border: Border.all(color: ext.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 12, color: ext.textMuted),
            const SizedBox(width: LinearSpacing.xs),
            Expanded(
              child: Text(
                'Search…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ext.textMuted,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LinearRadii.xs),
                border: Border.all(color: ext.borderSubtle),
              ),
              child: Text(
                '⌘K',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ext.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
    this.label, {
    this.isCollapsed = false,
    this.onToggle,
  });

  final String label;
  final bool isCollapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return GestureDetector(
      onTap: onToggle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ext.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: LinearSpacing.xs),
              AnimatedRotation(
                turns: isCollapsed ? -0.25 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                child: Icon(Icons.keyboard_arrow_down,
                    size: 12, color: ext.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow();

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
    final s = parts[0];
    return s.substring(0, s.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(userDisplayNameProvider) ?? '';
    final membership  = ref.watch(currentOrgMembershipProvider);
    final orgName     = membership.isLoading
        ? ''
        : (membership.value?.orgName ?? kWorkspaceName);
    final roleLabel   = membership.value?.role.label ?? '';
    // Don't render until we have something to show.
    if (displayName.isEmpty && orgName.isEmpty) return const SizedBox.shrink();

    return Semantics(
      button: true, label: 'User menu',
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm, vertical: 7,
          ),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF6E56CF), shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(_initials(displayName),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w600, fontFamily: 'Inter',
                  )),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: context.linearExt.textMuted, fontSize: 9,
                            )),
                        ),
                        if (roleLabel.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _RoleBadge(roleLabel),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Builder(builder: (ctx) {
                final menuExt = ctx.linearExt;
                return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 14, color: menuExt.textMuted),
                tooltip: '',
                color: menuExt.surfaceBase,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LinearRadii.sm),
                  side: BorderSide(color: menuExt.borderSubtle),
                ),
                elevation: 4,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'switch',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded,
                            size: 14, color: menuExt.textSecondary),
                        const SizedBox(width: 8),
                        Text('Switch org',
                            style: TextStyle(
                                fontSize: 13,
                                color: menuExt.textSecondary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 14, color: menuExt.textSecondary),
                        const SizedBox(width: 8),
                        Text('Sign out',
                            style: TextStyle(
                                fontSize: 13,
                                color: menuExt.textSecondary)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'switch') {
                    await ref.read(currentOrgIdProvider.notifier).clear();
                    if (context.mounted) context.go('/org');
                  } else if (value == 'signout') {
                    await ref.read(authRepositoryProvider).signOut();
                  }
                },
              );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.role);
  final String role;

  Color get _color => switch (role.toLowerCase()) {
    'owner'     => const Color(0xFFF59E0B),
    'admin'     => LinearColors.accent,
    'manager'   => const Color(0xFF22C55E),
    'technical' => const Color(0xFF3B82F6),
    'guest'     => LinearColors.textMuted,
    _           => LinearColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(LinearRadii.xs),
      ),
      child: Text(
        role,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _color, fontSize: 9, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
