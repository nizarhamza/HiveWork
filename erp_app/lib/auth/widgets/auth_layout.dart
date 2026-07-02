import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

const double _kBreakpoint = 900;

/// Two-column responsive shell for all auth and onboarding pages.
///
/// Wide (≥900 dp): brand panel (left) │ form panel (right).
/// Narrow (<900 dp): accent bar + single-column form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.child,
    this.onBack,
    this.trailingActions,
  });

  final Widget child;
  final VoidCallback? onBack;
  final List<Widget>? trailingActions;

  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _kBreakpoint;

  @override
  Widget build(BuildContext context) =>
      _isWide(context) ? _WideLayout(this) : _NarrowLayout(this);
}

// ── Wide layout ────────────────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout(this.data);
  final AuthLayout data;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final hasNav = data.onBack != null ||
        (data.trailingActions?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: ext.pageBg,
      body: Row(
        children: [
          const Expanded(child: _BrandPanel()),
          Expanded(
            child: ColoredBox(
              color: ext.surfaceBase,
              child: Column(
                children: [
                  if (hasNav)
                    SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            const SizedBox(width: LinearSpacing.sm),
                            if (data.onBack != null)
                              _BackButton(onPressed: data.onBack!),
                            const Spacer(),
                            ...?data.trailingActions,
                            const SizedBox(width: LinearSpacing.md),
                          ],
                        ),
                      ),
                    ),
                  Expanded(child: data.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Narrow layout ──────────────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout(this.data);
  final AuthLayout data;

  @override
  Widget build(BuildContext context) {
    final hasNav = data.onBack != null ||
        (data.trailingActions?.isNotEmpty ?? false);

    final ext = context.linearExt;
    return Scaffold(
      backgroundColor: ext.pageBg,
      body: Column(
        children: [
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [LinearColors.accent, LinearColors.accentHover],
              ),
            ),
          ),
          if (hasNav)
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: LinearSpacing.sm),
                    if (data.onBack != null)
                      _BackButton(onPressed: data.onBack!),
                    const Spacer(),
                    ...?data.trailingActions,
                    const SizedBox(width: LinearSpacing.md),
                  ],
                ),
              ),
            )
          else
            const SafeArea(bottom: false, child: SizedBox(height: LinearSpacing.sm)),
          Expanded(child: data.child),
        ],
      ),
    );
  }
}

// ── Back button ────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Semantics(
      label: 'Go back',
      button: true,
      child: IconButton(
        icon: const Icon(Icons.arrow_back, size: 16),
        onPressed: onPressed,
        tooltip: 'Back',
        style: IconButton.styleFrom(
          foregroundColor: ext.textMuted,
          backgroundColor: ext.borderSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LinearRadii.md),
          ),
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(LinearSpacing.xs),
        ),
      ),
    );
  }
}

// ── Brand panel ────────────────────────────────────────────────────────────────

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    const features = [
      (icon: Icons.receipt_long_rounded,    label: 'Invoices & Payments'),
      (icon: Icons.people_rounded,           label: 'CRM & Contacts'),
      (icon: Icons.trending_up_rounded,      label: 'Sales Pipeline'),
      (icon: Icons.folder_open_rounded,      label: 'Projects & Tasks'),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: ext.pageBg),
        // Ambient indigo glow — top-center
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.9),
                radius: 0.9,
                colors: [Color(0x335E6AD2), Colors.transparent],
              ),
            ),
          ),
        ),
        // Subtle secondary glow — bottom-right
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.9, 0.8),
                radius: 0.6,
                colors: [Color(0x0F5E6AD2), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _NetworkGraphPainter())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + name
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6872D6), LinearColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(LinearRadii.md),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'E',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: LinearSpacing.sm),
                    Text(
                      'HiveWork',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ext.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Tagline
                Text(
                  'Run your\nbusiness smarter.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: ext.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: LinearSpacing.base),
                Text(
                  'One workspace for CRM, invoicing, projects,\nand your whole team.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: ext.textSecondary,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 40),

                // Feature mini-cards (2×2)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _FeatureCard(feature: features[0])),
                        const SizedBox(width: LinearSpacing.sm),
                        Expanded(child: _FeatureCard(feature: features[1])),
                      ],
                    ),
                    const SizedBox(height: LinearSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: _FeatureCard(feature: features[2])),
                        const SizedBox(width: LinearSpacing.sm),
                        Expanded(child: _FeatureCard(feature: features[3])),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                Text(
                  'Trusted by teams worldwide',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: ext.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});
  final ({IconData icon, String label}) feature;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.base,
        vertical: LinearSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ext.overlay,
        borderRadius: BorderRadius.circular(LinearRadii.lg),
        border: Border.all(color: ext.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0x265E6AD2),
              borderRadius: BorderRadius.circular(LinearRadii.sm),
            ),
            child: Icon(feature.icon, color: LinearColors.accentHover, size: 14),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Expanded(
            child: Text(
              feature.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ext.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative network graph ───────────────────────────────────────────────────

class _NetworkGraphPainter extends CustomPainter {
  static const _nodes = [
    Offset(0.12, 0.20), Offset(0.38, 0.14), Offset(0.68, 0.22),
    Offset(0.85, 0.45), Offset(0.72, 0.70), Offset(0.42, 0.78),
    Offset(0.15, 0.62), Offset(0.55, 0.48),
  ];
  static const _edges = [
    (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 0),
    (1, 7), (2, 7), (4, 7), (5, 7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = const Color(0x085E6AD2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final nodeFill = Paint()
      ..color = const Color(0x125E6AD2)
      ..style = PaintingStyle.fill;
    final nodeBorder = Paint()
      ..color = const Color(0x1E5E6AD2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final (a, b) in _edges) {
      canvas.drawLine(
        Offset(_nodes[a].dx * size.width, _nodes[a].dy * size.height),
        Offset(_nodes[b].dx * size.width, _nodes[b].dy * size.height),
        edgePaint,
      );
    }
    for (var i = 0; i < _nodes.length; i++) {
      final p = Offset(_nodes[i].dx * size.width, _nodes[i].dy * size.height);
      final r = i == 7 ? 5.0 : 3.5;
      canvas.drawCircle(p, r, nodeFill);
      canvas.drawCircle(p, r, nodeBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
