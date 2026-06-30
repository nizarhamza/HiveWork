import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/providers/auth_providers.dart';
import '../theme/linear_tokens.dart';
import 'auth_repository.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_layout.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _isChecking = false;
  bool _resentOk   = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      // Refresh the session so Supabase re-reads emailConfirmedAt from the server.
      await Supabase.instance.client.auth.refreshSession();
      // The router's refreshListenable reacts to the auth stream and will
      // automatically redirect if the email is now confirmed.
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await ref.read(authRepositoryProvider).resendEmailConfirmation(email);
      if (mounted) setState(() => _resentOk = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;

    return AuthLayout(
      trailingActions: [
        TextButton(
          onPressed: () =>
              ref.read(authRepositoryProvider).signOut(),
          style: TextButton.styleFrom(
            foregroundColor: LinearColors.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
          ),
          child: const Text('Sign out'),
        ),
      ],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xl,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email icon badge
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: LinearColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: LinearColors.borderBase),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: LinearColors.accentHover,
                      size: 30,
                    ),
                  ),
                ),

                const SizedBox(height: LinearSpacing.xl),

                Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: text.headlineLarge,
                ),
                const SizedBox(height: LinearSpacing.sm),
                Text(
                  'We sent a confirmation link to',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: LinearSpacing.xxs),
                  Text(
                    user?.email ?? '',  // S-7: null-safe
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: LinearColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  'Click the link in your inbox, then come back here.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),

                const SizedBox(height: 28),

                AuthStepRow(
                  steps: const [
                    (
                      icon: Icons.check_circle_outline,
                      label: 'Account\ncreated',
                      done: true,
                    ),
                    (
                      icon: Icons.email_outlined,
                      label: 'Verify\nemail',
                      done: false,
                    ),
                    (
                      icon: Icons.business_outlined,
                      label: 'Set up\nworkspace',
                      done: false,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                if (_resentOk)
                  const Padding(
                    padding: EdgeInsets.only(bottom: LinearSpacing.base),
                    child: AuthInfoBanner(
                      message: 'Confirmation email resent — check your inbox.',
                    ),
                  ),

                Semantics(
                  button: true,
                  label: "I've confirmed my email",
                  child: FilledButton(
                    onPressed: _isChecking ? null : _checkVerification,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: _isChecking
                        ? const AuthButtonSpinner()
                        : const Text("I've confirmed my email"),
                  ),
                ),
                const SizedBox(height: LinearSpacing.sm),
                OutlinedButton(
                  onPressed: _resend,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text('Resend confirmation email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
