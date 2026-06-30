# Phase: Audit Remediation — 2026-06-29

Findings from the full codebase + database audit (`AUDIT_REPORT.md` in `erp_app/`).
Work through groups in order — each group is self-contained and safe to apply independently.

**Overall audit score: 52% → target 80% after this phase.**
**Total findings: 22 (Critical: 1 | High: 6 | Medium: 8 | Low: 7)**

---

## G0 — Critical DB Fix ← DO THIS FIRST

> Risk: Low. SQL only — no Dart changes.

- [ ] **Fix `product_bundles` + `product_bundle_lines` RLS** (Finding B-1 — Critical)
  - Open Supabase Dashboard → SQL Editor
  - Run the fix SQL from `erp_app/AUDIT_REPORT.md` (section "Fix SQL — Critical Finding B-1")
  - Drops the two `LIMIT 1` policies and replaces them with `is_org_member(org_id)`
  - Verify in Dashboard → Authentication → Policies that both tables now show 5 policies each

---

## G1 — Secrets Hygiene

> Risk: Low. Changes `main.dart`, `.gitignore`, adds `.env.json`.

- [ ] Create `erp_app/.env.json` with the two keys and add it to `.gitignore` (Findings A-1, A-3)
  ```json
  {
    "SUPABASE_URL": "https://nwagdfbwjtdvsxgjgzhm.supabase.co",
    "SUPABASE_ANON_KEY": "sb_publishable_WTEbnhtLqpCjFRK2PBvNHw_Rv8zXzW4"
  }
  ```
- [ ] Update `.vscode/launch.json` to use `--dart-define-from-file=.env.json` instead of inline values
- [ ] Add `.env.json` and `.vscode/launch.json` as explicit `.gitignore` entries
- [ ] Add startup assertion in `main()` before `Supabase.initialize` (Finding A-2):
  ```dart
  assert(AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty,
    'Supabase env vars missing — pass --dart-define-from-file=.env.json');
  ```
- [ ] Document required keys in `erp_app/README.md`

---

## G2 — Crash Reporting

> Risk: Low. New package + 5-line `main.dart` change.

- [ ] Add `sentry_flutter: ^8.x` to `pubspec.yaml` (Finding F-1)
- [ ] Add `SENTRY_DSN` to `.env.json`
- [ ] Wrap `runApp` in `main.dart`:
  ```dart
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = 0.2;
    },
    appRunner: () => runApp(const ProviderScope(child: ErpApp())),
  );
  ```
- [ ] Create a Sentry project at sentry.io and paste the DSN into `.env.json`

---

## G3 — Web SPA Fallback

> Risk: Very low. One new file.

- [ ] Create `erp_app/web/_redirects` (Finding C-1):
  ```
  /* /index.html 200
  ```
  *(for Netlify — adjust for Vercel/Firebase if different host)*
- [ ] Verify: deploy to host, navigate to `/crm/contacts`, hit browser refresh — should load app, not 404

---

## G5 — Auth / PKCE (group before G4 — smaller change)

> Risk: Low. One line in `main.dart`.

- [ ] Add `authFlowType: AuthFlowType.pkce` to `FlutterAuthClientOptions` in `main.dart` (Findings A-4, C-3):
  ```dart
  authOptions: FlutterAuthClientOptions(
    localStorage: SupabaseSecureStorage(),
    authFlowType: AuthFlowType.pkce,
  ),
  ```
- [ ] Manually verify in Supabase Dashboard → Auth → URL Configuration:
  - Site URL is set to your deployed app URL
  - Redirect URLs include `http://localhost` (dev) and your production URL
  - Google OAuth provider has the correct callback URL registered

---

## G4 — Soft Deletes

> Risk: Medium. Schema change + query updates across 5 repositories.

- [ ] Generate and apply migration adding `deleted_at` to core tables (Finding B-2):
  ```sql
  ALTER TABLE contacts  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
  ALTER TABLE companies ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
  ALTER TABLE deals     ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
  ALTER TABLE quotes    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
  ALTER TABLE products  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
  ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

  -- Partial indexes for fast active-record lookups
  CREATE INDEX IF NOT EXISTS idx_contacts_active  ON contacts (org_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_companies_active ON companies(org_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_deals_active     ON deals    (org_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_quotes_active    ON quotes   (org_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_products_active  ON products (org_id) WHERE deleted_at IS NULL;
  CREATE INDEX IF NOT EXISTS idx_suppliers_active ON suppliers(org_id) WHERE deleted_at IS NULL;
  ```
- [ ] Save as `erp_app/supabase/migrations/20260629000001_soft_deletes.sql`
- [ ] Update `contact_repository.dart` — change `delete()` to set `deleted_at`; add `.is_('deleted_at', null)` to `fetchAll()`
- [ ] Same for `company_repository.dart`, `deal_repository.dart`, `quote_repository.dart`, `products_repository.dart`, `suppliers_repository.dart`
- [ ] Update RLS SELECT policies on each table to exclude soft-deleted rows:
  ```sql
  -- example for contacts (repeat for each table)
  DROP POLICY IF EXISTS "contacts_select" ON contacts;
  CREATE POLICY "contacts_select" ON contacts FOR SELECT
    USING (has_module_access(org_id, 'crm') AND deleted_at IS NULL);
  ```

---

## G6 — Riverpod Cleanup

> Risk: Medium. Provider signature changes + notifier logic.

- [ ] Add `autoDispose` to all four auth/form notifiers in `auth_controllers.dart` (Finding E-1):
  - `signInProvider` → `NotifierProvider.autoDispose`
  - `signUpProvider` → `NotifierProvider.autoDispose`
  - `forgotPasswordProvider` → `NotifierProvider.autoDispose`
  - `googleSignInProvider` → `NotifierProvider.autoDispose`
- [ ] Add `autoDispose` to `customFieldDefsProvider.family` in `custom_fields_provider.dart` (Finding E-2)
- [ ] In `_CurrentOrgNotifier.select()` in `org_providers.dart`, invalidate all data caches before setting state (Finding E-3):
  ```dart
  Future<void> select(String orgId) async {
    await ref.read(orgRepositoryProvider).setDefaultOrg(orgId);
    ref.invalidate(contactsProvider);
    ref.invalidate(companiesProvider);
    ref.invalidate(dealsProvider);
    ref.invalidate(quotesProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(suppliersProvider);
    state = AsyncData(orgId);
  }
  ```

---

## G7 — DB Delete Guards

> Risk: Low. Adding one `.eq()` call per repository.

- [ ] `deal_repository.dart` `delete()` — add `.eq('org_id', orgId)`, update method signature to accept `orgId` (Finding D-1)
- [ ] `contact_repository.dart` `delete()` — same
- [ ] `products_repository.dart` `delete()` — same
- [ ] Update calling notifiers (`DealsNotifier`, `ContactsNotifier`, `ProductsNotifier`) to pass `orgId` through

---

## G8 — SELECT * Cleanup

> Risk: Low. Query string changes only.

- [ ] `org_repository.dart` `fetchOrgDetails()` — replace `.select()` with explicit column list (Finding D-2)
- [ ] `custom_field_repository.dart` — replace 3 bare `.select()` calls with column lists
- [ ] `payment_term_repository.dart` — replace 3 bare `.select()` calls with column lists
- [ ] `quote_repository.dart` `fetchById()` lines 33 + 41 — explicit column lists for the `quote_lines` fetch

---

## G9 — Observability Polish

> Risk: Very low.

- [ ] Audit 4 `debugPrint` usages — wrap each with `if (kDebugMode)` (Finding F-2):
  ```bash
  grep -rn "debugPrint" lib/ --include="*.dart"
  ```
- [ ] Tighten `web/index.html` CSP — remove `unsafe-eval` from `script-src`, keep only `wasm-unsafe-eval` (Finding A-5)
- [ ] Create a GitHub/Linear issue to track CSP hardening so it doesn't get lost again

---

## G10 — Duplicate DB Policies Cleanup

> Risk: Very low. SQL only.

- [ ] Run the cleanup SQL from `erp_app/AUDIT_REPORT.md` (section "Fix SQL — Finding B-6")
  - Removes 4 stale `custom_field_defs_*` policies, leaving the correct 3 "org members can …" ones
- [ ] Verify in Dashboard → Authentication → Policies → `custom_field_definitions` shows 3 policies

---

## Manual Actions (no code — do these yourself)

- [ ] **Verify Storage bucket RLS** in Supabase Dashboard → Storage → Policies — confirm no public buckets if storage is used
- [ ] **Confirm dev/prod separation** — if this is the only Supabase project, create a separate dev project before any production traffic
- [ ] **Move loose SQL files into `supabase/migrations/`**:
  - `erp_app/custom_fields_migration.sql` → `erp_app/supabase/migrations/20260529000001_custom_fields.sql`
  - `erp_app/payment_terms_migration.sql` → `erp_app/supabase/migrations/20260529000002_payment_terms.sql`
  - `erp_app/org_info_migration.sql` → `erp_app/supabase/migrations/20260529000003_org_info.sql`
- [ ] **Register Google OAuth redirect URIs** in Supabase Dashboard → Auth → URL Configuration

---

## Future Phase Items (from audit — schedule separately)

These are real issues but belong in their natural phase rather than a hotfix sprint:

- **B-3 — Monetary double → fixed precision** — schedule in Phase 4 (Invoicing), before any live invoice is generated. Change Dart models to use integer millimes or `Decimal` for amounts; migrate unbounded `NUMERIC` columns to `NUMERIC(14,3)`.
- **B-4 — Quote/deal status machine at DB level** — Postgres trigger enforcing allowed transitions. Schedule in Phase 4 alongside the invoice/payment state machine.
- **D-3 — Wire `watchAll()` Realtime streams** or remove dead code. Schedule in Phase 4/5 when deciding on real-time collaboration requirements.
- **D-4 — Cursor-based pagination** — replace hard `.limit()` caps with `range(from, to)` + pagination UI. Schedule in Phase 8 (quality pass).
- **Testing** — only a placeholder test exists. Full suite needed. Schedule in Phase 8.
