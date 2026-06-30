import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

// ── Field label ────────────────────────────────────────────────────────────────

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.linearExt.textSecondary,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

// ── "or" divider ───────────────────────────────────────────────────────────────

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: context.linearExt.borderSubtle, thickness: 1, height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.linearExt.textMuted,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: context.linearExt.borderSubtle, thickness: 1, height: 1,
          ),
        ),
      ],
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.base,
        vertical: LinearSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LinearColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border: Border.all(color: LinearColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 14,
            color: LinearColors.danger,
          ),
          const SizedBox(width: LinearSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LinearColors.danger,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info banner ────────────────────────────────────────────────────────────────

class AuthInfoBanner extends StatelessWidget {
  const AuthInfoBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.base,
        vertical: LinearSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LinearColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border: Border.all(color: LinearColors.success.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 14,
            color: LinearColors.success,
          ),
          const SizedBox(width: LinearSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LinearColors.success,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer link row ────────────────────────────────────────────────────────────

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.linearExt.textSecondary,
              ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.xs),
            minimumSize: const Size(0, 28),
            foregroundColor: LinearColors.accent,
          ),
          child: Text(
            action,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LinearColors.accent,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Button spinner ─────────────────────────────────────────────────────────────

class AuthButtonSpinner extends StatelessWidget {
  const AuthButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    );
  }
}

// ── Google sign-in button ──────────────────────────────────────────────────────

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign in with Google',
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 40),
          backgroundColor: context.linearExt.surfaceBase,
          foregroundColor: context.linearExt.textPrimary,
          side: BorderSide(color: context.linearExt.borderBase),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleLogo(size: 18),
                  const SizedBox(width: LinearSpacing.sm),
                  Text(
                    'Sign in with Google',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: context.linearExt.textPrimary,
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GoogleGPainter()),
      );
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r  = size.width * 0.44;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final sw = size.width * 0.19;
    final rc = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    Paint p(Color c) => Paint()
      ..color = c
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    // Four colored arcs, clockwise from gap-bottom (~30°) to gap-top (~-20°)
    canvas.drawArc(rc, 0.52, 1.05, false, p(const Color(0xFFEA4335))); // red
    canvas.drawArc(rc, 1.57, 1.05, false, p(const Color(0xFFFBBC05))); // yellow
    canvas.drawArc(rc, 2.62, 1.22, false, p(const Color(0xFF34A853))); // green
    canvas.drawArc(rc, 3.84, 2.09, false, p(const Color(0xFF4285F4))); // blue

    // Horizontal bar centre → right edge (blue)
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r + sw * 0.4, cy),
      p(const Color(0xFF4285F4))..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Step progress row (verify email page) ─────────────────────────────────────

class AuthStepRow extends StatelessWidget {
  const AuthStepRow({super.key, required this.steps});
  final List<({IconData icon, String label, bool done})> steps;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: steps[i].done
                        ? LinearColors.success.withValues(alpha: 0.15)
                        : ext.overlay,
                    borderRadius: BorderRadius.circular(LinearRadii.lg),
                    border: Border.all(
                      color: steps[i].done
                          ? LinearColors.success.withValues(alpha: 0.35)
                          : ext.borderSubtle,
                    ),
                  ),
                  child: Icon(
                    steps[i].done ? Icons.check_rounded : steps[i].icon,
                    size: 14,
                    color: steps[i].done
                        ? LinearColors.success
                        : ext.textMuted,
                  ),
                ),
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  steps[i].label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: steps[i].done
                            ? ext.textSecondary
                            : ext.textMuted,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Container(
              height: 1,
              width: 24,
              color: ext.borderSubtle,
            ),
        ],
      ],
    );
  }
}
