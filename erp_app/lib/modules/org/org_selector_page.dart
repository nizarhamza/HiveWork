import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_repository.dart';
import '../../theme/linear_tokens.dart';
import 'org_providers.dart';
import 'org_role.dart';

class OrgSelectorPage extends ConsumerStatefulWidget {
  const OrgSelectorPage({super.key});

  @override
  ConsumerState<OrgSelectorPage> createState() => _OrgSelectorPageState();
}

class _OrgSelectorPageState extends ConsumerState<OrgSelectorPage> {
  static const _timeout = Duration(seconds: 4);

  bool _timedOut = false;
  bool _navigating = false;
  Timer? _timer;

  // Returns true and sets the flag atomically if no navigation has started yet.
  bool _claimNavigation() {
    if (_navigating) return false;
    _navigating = true;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(_timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final orgId = await ref.read(currentOrgIdProvider.future);
      if (mounted && orgId != null && _claimNavigation()) {
        context.go('/crm/contacts');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(userOrgsProvider);
    if (orgsAsync.hasValue) _timer?.cancel();

    final body = orgsAsync.when(
      loading: () =>
          _timedOut ? const _EmptyState() : const _OrgListSkeleton(),
      error: (err, stack) => const _EmptyState(),
      data: (orgs) =>
          orgs.isEmpty ? const _EmptyState() : _OrgList(orgs: orgs, onWillNavigate: _claimNavigation),
    );

    return Scaffold(
      backgroundColor: context.linearExt.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(ref: ref),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      height: 56,
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LinearSpacing.lg),
      decoration: BoxDecoration(
        color: ext.surfaceBase,
        border: Border(bottom: BorderSide(color: ext.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6872D6), LinearColors.accent],
              ),
              borderRadius: BorderRadius.circular(LinearRadii.sm),
            ),
            alignment: Alignment.center,
            child: const Text(
              'E',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Text('ERP', style: context.text.titleMedium),
          const Spacer(),
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            style: TextButton.styleFrom(
              foregroundColor: ext.textMuted,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: LinearSpacing.base,
                vertical: LinearSpacing.xs,
              ),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

// ── Org list ───────────────────────────────────────────────────────────────────

class _OrgList extends ConsumerWidget {
  const _OrgList({required this.orgs, required this.onWillNavigate});
  final List<OrgMembership> orgs;
  // Returns true if navigation is allowed (first caller), false if already in progress.
  final bool Function() onWillNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
          LinearSpacing.lg, 48, LinearSpacing.lg, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select a workspace', style: context.text.headlineMedium),
          const SizedBox(height: LinearSpacing.xs),
          Text(
            'Choose a workspace to continue.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: LinearSpacing.xl),
          ...orgs.asMap().entries.map(
                (entry) => _AnimatedOrgCard(
                  index: entry.key,
                  org: entry.value,
                  onTap: () => _select(context, ref, entry.value.orgId),
                ),
              ),
          const SizedBox(height: LinearSpacing.sm),
          _NewWorkspaceRow(),
        ],
      ),
    );
  }

  Future<void> _select(
      BuildContext context, WidgetRef ref, String orgId) async {
    final canNavigate = onWillNavigate();
    try {
      await ref.read(currentOrgIdProvider.notifier).select(orgId);
    } catch (_) {
      ref.read(currentOrgIdProvider.notifier).forceLocal(orgId);
    }
    // Only navigate if we were the first to claim navigation rights.
    // If the initState auto-redirect already started, skip to avoid a
    // second context.go() that duplicates the ShellRoute's navigator key.
    if (canNavigate && context.mounted) context.go('/crm/contacts');
  }
}

// ── Animated card wrapper ──────────────────────────────────────────────────────

class _AnimatedOrgCard extends StatefulWidget {
  const _AnimatedOrgCard({
    required this.index,
    required this.org,
    required this.onTap,
  });
  final int index;
  final OrgMembership org;
  final VoidCallback onTap;

  @override
  State<_AnimatedOrgCard> createState() => _AnimatedOrgCardState();
}

class _AnimatedOrgCardState extends State<_AnimatedOrgCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 55 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _OrgCard(org: widget.org, onTap: widget.onTap),
        ),
      ),
    );
  }
}

// ── Org card ───────────────────────────────────────────────────────────────────

class _OrgCard extends StatefulWidget {
  const _OrgCard({required this.org, required this.onTap});
  final OrgMembership org;
  final VoidCallback onTap;

  @override
  State<_OrgCard> createState() => _OrgCardState();
}

class _OrgCardState extends State<_OrgCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final initial = widget.org.orgName.isNotEmpty
        ? widget.org.orgName[0].toUpperCase()
        : '?';

    return Semantics(
      button: true,
      label: '${widget.org.orgName}, ${widget.org.role.label}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown:  (_) => setState(() => _pressed = true),
          onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
          onTapCancel:    () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: LinearSpacing.md, vertical: LinearSpacing.base),
            decoration: BoxDecoration(
              color: _pressed
                  ? ext.overlayActive
                  : _hovered
                      ? ext.overlay
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(LinearRadii.lg),
              border: Border.all(
                color: _hovered
                    ? ext.borderBase
                    : ext.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                _OrgAvatar(orgName: widget.org.orgName, logoUrl: widget.org.orgLogoUrl, initial: initial),
                const SizedBox(width: LinearSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.org.orgName,
                        style: context.text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: LinearSpacing.xxs),
                      _RolePill(role: widget.org.role),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: LinearSpacing.sm),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: ext.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Org avatar ─────────────────────────────────────────────────────────────────

class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({
    required this.orgName,
    required this.logoUrl,
    required this.initial,
  });
  final String orgName;
  final String? logoUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(LinearRadii.lg),
        child: Image.network(
          logoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _InitialsAvatar(initial: initial),
        ),
      );
    }
    return _InitialsAvatar(initial: initial);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initial});
  final String initial;

  static Color _colorFor(String letter) {
    const palette = [
      LinearColors.accent,
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      LinearColors.success,
      LinearColors.warning,
    ];
    return palette[letter.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(initial);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(LinearRadii.lg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

// ── Role pill ──────────────────────────────────────────────────────────────────

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});
  final OrgRole role;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final (bg, fg) = switch (role) {
      OrgRole.owner     => (const Color(0x265E6AD2), LinearColors.accentHover),
      OrgRole.admin     => (const Color(0x1F4CAF72), LinearColors.success),
      OrgRole.manager   => (ext.overlay,    ext.textSecondary),
      OrgRole.technical => (ext.overlay,    ext.textSecondary),
      OrgRole.guest     => (ext.overlay,    ext.textMuted),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LinearSpacing.sm, vertical: LinearSpacing.xxs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(LinearRadii.pill),
      ),
      child: Text(
        role.label,
        style: context.text.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

// ── New workspace row ──────────────────────────────────────────────────────────

class _NewWorkspaceRow extends StatefulWidget {
  @override
  State<_NewWorkspaceRow> createState() => _NewWorkspaceRowState();
}

class _NewWorkspaceRowState extends State<_NewWorkspaceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Semantics(
      button: true,
      label: 'New workspace',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.push('/org/create'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: LinearSpacing.md, vertical: LinearSpacing.base),
            decoration: BoxDecoration(
              color: _hovered ? ext.overlay : Colors.transparent,
              borderRadius: BorderRadius.circular(LinearRadii.lg),
              border: Border.all(
                color: _hovered
                    ? ext.borderBase
                    : ext.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 120),
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: ext.textMuted,
                  ),
                ),
                const SizedBox(width: LinearSpacing.sm),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 120),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _hovered
                        ? ext.textSecondary
                        : ext.textMuted,
                  ),
                  child: const Text('New workspace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
          LinearSpacing.lg, 48, LinearSpacing.lg, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select a workspace', style: context.text.headlineMedium),
          const SizedBox(height: LinearSpacing.xs),
          Text('Choose a workspace to continue.', style: context.text.bodyMedium),
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: LinearColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.linearExt.borderBase),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    size: 24,
                    color: LinearColors.accentHover,
                  ),
                ),
                const SizedBox(height: LinearSpacing.lg),
                Text(
                  'No workspaces yet',
                  style: context.text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LinearSpacing.sm),
                Text(
                  'Create your first workspace to get started.',
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LinearSpacing.xl),
                SizedBox(width: double.infinity, child: _NewWorkspaceRow()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

class _OrgListSkeleton extends StatefulWidget {
  const _OrgListSkeleton();

  @override
  State<_OrgListSkeleton> createState() => _OrgListSkeletonState();
}

class _OrgListSkeletonState extends State<_OrgListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            LinearSpacing.lg, 48, LinearSpacing.lg, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 180, height: 20, radius: LinearRadii.sm, opacity: _pulse.value),
            const SizedBox(height: LinearSpacing.sm),
            _SkeletonBox(width: 240, height: 13, radius: LinearRadii.sm, opacity: _pulse.value * 0.6),
            const SizedBox(height: LinearSpacing.xl),
            for (var i = 0; i < 3; i++) ...[
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: LinearSpacing.md, vertical: LinearSpacing.base),
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.transparent, ext.overlay, _pulse.value),
                  borderRadius: BorderRadius.circular(LinearRadii.lg),
                  border: Border.all(color: ext.borderSubtle),
                ),
                child: Row(
                  children: [
                    _SkeletonBox(width: 40, height: 40, radius: LinearRadii.lg, opacity: _pulse.value),
                    const SizedBox(width: LinearSpacing.base),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 130, height: 13, radius: LinearRadii.xs, opacity: _pulse.value),
                        const SizedBox(height: LinearSpacing.xs),
                        _SkeletonBox(width: 52, height: 18, radius: LinearRadii.pill, opacity: _pulse.value * 0.7),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < 2) const SizedBox(height: LinearSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.opacity,
  });
  final double width;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.transparent, ext.borderBase, opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
