import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/linear_tokens.dart';
import 'auth_controllers.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/auth_layout.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref.read(signUpProvider.notifier).signUp(
          email:       _emailCtrl.text.trim(),
          password:    _passwordCtrl.text,
          displayName: _nameCtrl.text.trim(),
        );
    if (!mounted || result == null) return;

    // session == null means email confirmation is pending.
    if (result.session == null) {
      context.go('/auth/verify-email');
    } else {
      context.go('/org');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state         = ref.watch(signUpProvider);
    final loading       = state.isLoading;
    final error         = ref.watch(signUpProvider.notifier).errorMessage;
    final googleState   = ref.watch(googleSignInProvider);
    final googleLoading = googleState.isLoading;
    final googleError   = ref.watch(googleSignInProvider.notifier).errorMessage;
    final text          = Theme.of(context).textTheme;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create account', style: text.headlineLarge),
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  'Join your team or start a new workspace.',
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
                      const AuthFieldLabel('Full name'),
                      const SizedBox(height: LinearSpacing.xs),
                      Semantics(
                        label: 'Full name',
                        textField: true,
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration:
                              const InputDecoration(hintText: 'Jane Smith'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),

                      const SizedBox(height: LinearSpacing.base),
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

                      const SizedBox(height: LinearSpacing.base),
                      const AuthFieldLabel('Password'),
                      const SizedBox(height: LinearSpacing.xs),
                      Semantics(
                        label: 'Password',
                        textField: true,
                        child: TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            helperText: 'Minimum 6 characters',
                            helperStyle: text.labelSmall,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 16,
                                color: LinearColors.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: LinearSpacing.base),
                      const AuthFieldLabel('Confirm password'),
                      const SizedBox(height: LinearSpacing.xs),
                      Semantics(
                        label: 'Confirm password',
                        textField: true,
                        child: TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signUp(),
                          decoration:
                              const InputDecoration(hintText: '••••••••'),
                          validator: (v) => v != _passwordCtrl.text
                              ? 'Passwords do not match'
                              : null,
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
                  label: 'Create account',
                  child: FilledButton(
                    onPressed: loading ? null : _signUp,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: loading
                        ? const AuthButtonSpinner()
                        : const Text('Create account'),
                  ),
                ),

                const SizedBox(height: LinearSpacing.xl),
                AuthFooterLink(
                  prompt: 'Already have an account? ',
                  action: 'Sign in',
                  onTap: () => context.go('/auth/login'),
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
