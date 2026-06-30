abstract final class AppConfig {
  // Provided at build time via --dart-define (see .vscode/launch.json).
  static const supabaseUrl     = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
