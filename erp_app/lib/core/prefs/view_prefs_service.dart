import 'package:shared_preferences/shared_preferences.dart';

/// Typed wrapper around SharedPreferences for persisting view state.
///
/// Each view uses its own key namespace, e.g. 'contacts.', 'companies.'.
/// Only this class imports shared_preferences directly.
class ViewPrefsService {
  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<int?> getInt(String key) async =>
      (await _p).getInt(key);

  static Future<void> setInt(String key, int v) async =>
      (await _p).setInt(key, v);

  static Future<double> getDouble(String key, double fallback) async =>
      (await _p).getDouble(key) ?? fallback;

  static Future<void> setDouble(String key, double v) async =>
      (await _p).setDouble(key, v);

  static Future<List<String>?> getStringList(String key) async =>
      (await _p).getStringList(key);

  static Future<void> setStringList(String key, List<String> v) async =>
      (await _p).setStringList(key, v);

  /// Returns null when the key has never been set (i.e. no filter applied).
  static Future<bool?> getBoolOrNull(String key) async {
    final p = await _p;
    return p.containsKey(key) ? p.getBool(key) : null;
  }

  /// Removes the key when [v] is null, otherwise writes it.
  static Future<void> setBoolOrNull(String key, bool? v) async {
    final p = await _p;
    if (v == null) { await p.remove(key); } else { await p.setBool(key, v); }
  }

  static Future<String?> getString(String key) async =>
      (await _p).getString(key);

  static Future<void> setString(String key, String v) async =>
      (await _p).setString(key, v);

  static Future<void> removeKey(String key) async =>
      (await _p).remove(key);

  /// Clears all persisted prefs — call on sign-out so the next user
  /// starts with a clean slate (M-2).
  static Future<void> clearAll() async =>
      (await _p).clear();
}
