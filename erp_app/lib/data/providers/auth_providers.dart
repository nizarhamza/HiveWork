import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Streams every auth state change (sign-in, sign-out, token refresh, etc.).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The currently signed-in user, or null when unauthenticated.
///
/// Reads from the auth stream when available, but falls back to the
/// synchronous [SupabaseClient.auth.currentUser] so the value is non-null
/// immediately after a session is restored (before the first stream event).
final currentUserProvider = Provider<User?>((ref) {
  final streamUser = ref.watch(authStateProvider).value?.session?.user;
  return streamUser ?? ref.watch(supabaseClientProvider).auth.currentUser;
});

/// Display name from user_metadata, falling back to email.
/// Checks display_name (email signup), full_name, and name (Google OAuth).
final userDisplayNameProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final meta = user.userMetadata;
  return meta?['display_name'] as String?
      ?? meta?['full_name'] as String?
      ?? meta?['name'] as String?
      ?? user.email;
});
