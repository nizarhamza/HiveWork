# erp_app

Multi-tenant ERP — Flutter + Supabase, targeting web (primary) and Windows.

## Getting Started

### Environment setup

Create `.env.json` in the project root (never commit this file — it is `.gitignore`d):

```json
{
  "SUPABASE_URL": "https://<your-project>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-anon-key>",
  "SENTRY_DSN": "<your-sentry-dsn>"
}
```

Run with:

```bash
flutter run -d chrome   --dart-define-from-file=.env.json
flutter run -d windows  --dart-define-from-file=.env.json
flutter build web --release --dart-define-from-file=.env.json
```

VS Code: `.vscode/launch.json` already passes `--dart-define-from-file=.env.json` for both targets.

---

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
