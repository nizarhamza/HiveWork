import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthResponse;

import 'auth_repository.dart';

String _friendly(Object e) {
  if (e is AuthException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid') || msg.contains('credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('already registered') || msg.contains('already in use')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password should be')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please try again later.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    return e.message;
  }
  return e.toString();
}

// ── Sign-in ────────────────────────────────────────────────────────────────────

class SignInNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  String? get errorMessage =>
      state.whenOrNull(error: (e, _) => _friendly(e));

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithPassword(
            email: email,
            password: password,
          ),
    );
    return state is! AsyncError;
  }

  void clearError() => state = const AsyncData(null);
}

final signInProvider =
    NotifierProvider.autoDispose<SignInNotifier, AsyncValue<void>>(SignInNotifier.new);

// ── Sign-up ────────────────────────────────────────────────────────────────────

class SignUpNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  String? get errorMessage =>
      state.whenOrNull(error: (e, _) => _friendly(e));

  /// Returns the [AuthResponse] on success, null on error.
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    AuthResponse? result;
    state = await AsyncValue.guard(() async {
      result = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            displayName: displayName,
          );
    });
    return state is! AsyncError ? result : null;
  }

  void clearError() => state = const AsyncData(null);
}

final signUpProvider =
    NotifierProvider.autoDispose<SignUpNotifier, AsyncValue<void>>(SignUpNotifier.new);

// ── Forgot password ────────────────────────────────────────────────────────────

class ForgotPasswordNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  String? get errorMessage =>
      state.whenOrNull(error: (e, _) => _friendly(e));

  Future<bool> sendReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).resetPasswordForEmail(email),
    );
    return state is! AsyncError;
  }

  void clearError() => state = const AsyncData(null);
}

final forgotPasswordProvider =
    NotifierProvider.autoDispose<ForgotPasswordNotifier, AsyncValue<void>>(
  ForgotPasswordNotifier.new,
);

// ── Google OAuth ───────────────────────────────────────────────────────────────

class GoogleSignInNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  String? get errorMessage =>
      state.whenOrNull(error: (e, _) => _friendly(e));

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }
}

final googleSignInProvider =
    NotifierProvider.autoDispose<GoogleSignInNotifier, AsyncValue<void>>(
  GoogleSignInNotifier.new,
);
