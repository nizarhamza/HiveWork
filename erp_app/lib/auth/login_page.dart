import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/linear_tokens.dart';
import 'auth_controllers.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(signInProvider.notifier).signInWithEmail(
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    // Router navigates automatically via _RouterNotifier → /org → OrgSelectorPage
    // auto-redirects to /crm/contacts when an org exists.
  }

  @override
  Widget build(BuildContext context) {
    final state         = ref.watch(signInProvider);
    final loading       = state.isLoading;
    final error         = ref.watch(signInProvider.notifier).errorMessage;
    final googleState   = ref.watch(googleSignInProvider);
    final googleLoading = googleState.isLoading;
    final googleError   = ref.watch(googleSignInProvider.notifier).errorMessage;
    final text          = Theme.of(context).textTheme;
    final isWide        = MediaQuery.sizeOf(context).width >= 900;

    return AuthLayout(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xl,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isWide) ...[
                  const SizedBox(height: LinearSpacing.md),
                  _CompactLogo(),
                  const SizedBox(height: 28),
                ],

                Text('Welcome back', style: text.headlineLarge),
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  'Sign in to your account to continue.',
                  style: text.bodyMedium,
                ),

                const SizedBox(height: 28),

                GoogleSignInButton(
                  loading: googleLoading,
                  onPressed: () =>
                      ref.read(googleSignInProvider.notifier).signIn(),
                ),

                if (googleError != null) ...[
                  const SizedBox(height: LinearSpacing.sm),
                  AuthErrorBanner(message: googleError),
                ],

                const SizedBox(height: LinearSpacing.base),
                const AuthOrDivider(),
                const SizedBox(height: LinearSpacing.base),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthFieldLabel('Email'),
                      const SizedBox(height: LinearSpacing.xs),
                      Semantics(
                        label: 'Email address',
                        textField: true,
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'you@company.com',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: LinearSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AuthFieldLabel('Password'),
                          TextButton(
                            onPressed: () =>
                                context.push('/auth/forgot-password'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: LinearSpacing.xs),
                              minimumSize: const Size(0, 28),
                              foregroundColor: LinearColors.accent,
                            ),
                            child: Text(
                              'Forgot password?',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: LinearColors.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: LinearSpacing.xs),
                      Semantics(
                        label: 'Password',
                        textField: true,
                        child: TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signIn(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 16,
                                color: context.linearExt.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ),

                if (error != null) ...[
                  const SizedBox(height: LinearSpacing.base),
                  AuthErrorBanner(message: error),
                ],

                const SizedBox(height: LinearSpacing.lg),

                Semantics(
                  button: true,
                  label: 'Sign in',
                  child: FilledButton(
                    onPressed: loading ? null : _signIn,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: loading
                        ? const AuthButtonSpinner()
                        : const Text('Sign in'),
                  ),
                ),

                const SizedBox(height: LinearSpacing.xl),
                AuthFooterLink(
                  prompt: "Don't have an account? ",
                  action: 'Sign up',
                  onTap: () => context.go('/auth/signup'),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(width: LinearSpacing.sm),
        Text(
          'ERP',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}
