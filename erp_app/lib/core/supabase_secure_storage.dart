import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dep-1: Supabase LocalStorage backed by FlutterSecureStorage.
///
/// On Windows / Android / iOS / macOS this uses the platform's secure key
/// store (DPAPI / Keystore / Keychain).  On web it falls back to the
/// implementation built into flutter_secure_storage (localStorage), which is
/// the same surface as the Supabase default — no regression, and web users
/// get the same path as native once a proper web secure-store ships.
class SupabaseSecureStorage extends LocalStorage {
  static const _key = 'supabase.session';

  // AndroidOptions: use EncryptedSharedPreferences for added security.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Cached in-memory value populated during [initialize] so that the
  // synchronous [hasAccessToken] getter can work without blocking.
  String? _cached;

  @override
  Future<void> initialize() async {
    _cached = await _storage.read(key: _key);
  }

  @override
  Future<bool> hasAccessToken() async => _cached != null;

  @override
  Future<String?> accessToken() async => _cached;

  @override
  Future<void> persistSession(String persistedSession) async {
    _cached = persistedSession;
    await _storage.write(key: _key, value: persistedSession);
  }

  @override
  Future<void> removePersistedSession() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}
