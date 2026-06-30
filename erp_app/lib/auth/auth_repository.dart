import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/prefs/view_prefs_service.dart';
import '../core/supabase_client.dart';

class AuthRepository {
  const AuthRepository(this._client);
  final SupabaseClient _client;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      // Redirect back to this app's origin so Google auth never lands on another
      // project — uses the running app's URL dynamically rather than whatever
      // Site URL is configured in the Supabase Dashboard.
      redirectTo: kIsWeb ? Uri.base.origin : 'erp-app://auth-callback',
    );
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> resendEmailConfirmation(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<void> refreshSession() async {
    await _client.auth.refreshSession();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    // M-2: clear cached view-prefs so the next user starts with clean state.
    await ViewPrefsService.clearAll();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
