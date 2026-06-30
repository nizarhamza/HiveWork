import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/linear_tokens.dart';

/// Minimal email/password gate for testing before Phase 2 auth UI lands.
/// Only shown in debug mode when there is no active session.
///
/// F-5: Throws in release mode to prevent accidental production use.
class DevLoginPage extends StatefulWidget {
  const DevLoginPage({super.key}) : assert(kDebugMode, 'DevLoginPage must not be used in release builds');

  @override
  State<DevLoginPage> createState() => _DevLoginPageState();
}

class _DevLoginPageState extends State<DevLoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading  = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      final client = Supabase.instance.client;

      if (_isSignUp) {
        final res = await client.auth.signUp(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

        if (res.session == null) {
          // Email confirmation required — inform the user.
          setState(() {
            _info = 'Check your inbox and click the confirmation link, '
                'then sign in here.';
          });
          return;
        }

        // Confirmed immediately → create a default org and wire the profile.
        await _bootstrapOrg(client);
      } else {
        await client.auth.signInWithPassword(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        // Check whether the signed-in user already has a default org.
        final profile = await client
            .from('profiles')
            .select('default_org_id')
            .eq('id', client.auth.currentUser!.id)
            .single();
        if (profile['default_org_id'] == null) {
          await _bootstrapOrg(client);
        }
      }
      // Success — ErpApp watches authStateProvider and will switch to the
      // main router automatically; no manual navigation needed.
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _bootstrapOrg(SupabaseClient client) async {
    final org = await client.rpc('create_organization', params: {
      'p_name':     'My Org',
      'p_currency': 'EUR',
      'p_address':  '',
      'p_logo_url': null,
    }) as Map<String, dynamic>;
    await client
        .from('profiles')
        .update({'default_org_id': org['id']})
        .eq('id', client.auth.currentUser!.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: LinearColors.pageBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(LinearSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / title
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF6872D6), LinearColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                  ),
                  alignment: Alignment.center,
                  child: const Text('E',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                ),
                const SizedBox(height: LinearSpacing.lg),
                Text(_isSignUp ? 'Create account' : 'Sign in',
                    style: text.headlineSmall),
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  _isSignUp
                      ? 'Tip: disable email confirmation in Supabase → Auth → Settings for instant access.'
                      : 'Dev login — Phase 2 will add proper auth flows.',
                  style: text.bodySmall,
                ),

                const SizedBox(height: LinearSpacing.xl),

                // Email
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: LinearSpacing.base),

                // Password
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: LinearSpacing.lg),

                // Info / error banners
                if (_info != null) ...[
                  _Banner(message: _info!, isError: false),
                  const SizedBox(height: LinearSpacing.base),
                ],
                if (_error != null) ...[
                  _Banner(message: _error!, isError: true),
                  const SizedBox(height: LinearSpacing.base),
                ],

                // Submit
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isSignUp ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: LinearSpacing.base),

                // Toggle
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                    _info  = null;
                  }),
                  child: Text(_isSignUp
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? LinearColors.danger : LinearColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.base, vertical: LinearSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(message,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color)),
    );
  }
}
