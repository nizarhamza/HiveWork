import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/linear_tokens.dart';
import 'auth_controllers.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_layout.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(forgotPasswordProvider.notifier)
        .sendReset(_emailCtrl.text.trim());
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(forgotPasswordProvider);
    final loading = state.isLoading;
    final error   = ref.watch(forgotPasswordProvider.notifier).errorMessage;

    return AuthLayout(
      onBack: () => context.go('/auth/login'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xl,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _sent
                ? _SuccessView(
                    email: _emailCtrl.text.trim(),
                    onBack: () => context.go('/auth/login'),
                  )
                : _ResetForm(
                    formKey:    _formKey,
                    emailCtrl:  _emailCtrl,
                    loading:    loading,
                    error:      error,
                    onSubmit:   _sendReset,
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Reset form ─────────────────────────────────────────────────────────────────

class _ResetForm extends StatelessWidget {
  const _ResetForm({
    required this.formKey,
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: LinearColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(LinearRadii.lg),
            border: Border.all(color: LinearColors.borderBase),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: LinearColors.accentHover,
            size: 22,
          ),
        ),
        const SizedBox(height: LinearSpacing.lg),

        Text('Reset password', style: text.headlineLarge),
        const SizedBox(height: LinearSpacing.xs),
        Text(
          "Enter your email and we'll send a reset link.",
          style: text.bodyMedium,
        ),

        const SizedBox(height: 28),

        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthFieldLabel('Email'),
              const SizedBox(height: LinearSpacing.xs),
              Semantics(
                label: 'Email address',
                textField: true,
                child: TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  onFieldSubmitted: (_) => onSubmit(),
                  decoration:
                      const InputDecoration(hintText: 'you@company.com'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: LinearSpacing.base),
          AuthErrorBanner(message: error!),
        ],

        const SizedBox(height: LinearSpacing.lg),

        Semantics(
          button: true,
          label: 'Send reset link',
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
            child: loading
                ? const AuthButtonSpinner()
                : const Text('Send reset link'),
          ),
        ),
      ],
    );
  }
}

// ── Success state ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email, required this.onBack});
  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: LinearColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(LinearRadii.lg),
            border: Border.all(
              color: LinearColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: LinearColors.success,
            size: 22,
          ),
        ),
        const SizedBox(height: LinearSpacing.lg),

        Text('Check your email', style: text.headlineLarge),
        const SizedBox(height: LinearSpacing.sm),
        Text(
          'We sent a reset link to ',
          style: text.bodyMedium,
        ),
        Text(
          email,
          style: text.bodyMedium?.copyWith(
            color: LinearColors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 28),

        FilledButton(
          onPressed: onBack,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 40),
          ),
          child: const Text('Back to sign in'),
        ),

        const SizedBox(height: LinearSpacing.base),

        Container(
          padding: const EdgeInsets.all(LinearSpacing.base),
          decoration: BoxDecoration(
            color: LinearColors.overlay,
            borderRadius: BorderRadius.circular(LinearRadii.md),
            border: Border.all(color: LinearColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 14,
                color: LinearColors.textMuted,
              ),
              const SizedBox(width: LinearSpacing.sm),
              Expanded(
                child: Text(
                  "Check your spam folder if it doesn't arrive within a few minutes.",
                  style: text.labelSmall?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
