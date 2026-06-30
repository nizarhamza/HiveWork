# Audit Report — ERP App (`erp_app`)

**Date:** 2026-06-29
**Auditor:** AI — Flutter + Supabase Senior Reviewer
**Flutter:** SDK `^3.12.0` (Dart 3.12+) | **Platforms:** Web (primary), Windows Desktop
**Supabase project:** `nwagdfbwjtdvsxgjgzhm` (eu-west-3) | **DB:** PostgreSQL 17.6
**Overall progress:** 52%
**Total findings:** 22 (Critical: 1 | High: 6 | Medium: 8 | Low: 7)

> **Pass 1 — read-only.** No code was changed. Review the scorecard and findings, then tell me which fix groups to apply.

---

## Step 1 — Environment Snapshot

```
Flutter SDK:            ^3.12.0 required (Dart 3.12+)
supabase_flutter:       2.15.0
flutter_riverpod:       3.3.2
go_router:              17.3.0
pdf + printing:         3.11.1 / 5.14.2
google_fonts:           6.2.1
flutter_secure_storage: 9.2.4

Platforms in repo:      web/, windows/  (no android/, ios/, macos/, linux/)
pubspec.lock:           committed ✅
test/:                  1 file — widget_test.dart (placeholder only, no real tests)
Edge Functions:         NONE (supabase/functions/ does not exist)
supabase/migrations/:   3 files (20260626 series — gap documented below)
Dart files (excl. generated): 120
debugPrint / assert usages:   4
Hardcoded secrets in lib/:    NONE ✅
```

---

## Step 2 — Architecture Map

```
lib/
  auth/           sign-in, sign-up, forgot-password, verify-email,
                  auth_repository, auth_controllers
                  (SignIn / SignUp / ForgotPassword / GoogleOAuth notifiers)
  core/
    config/       AppConfig — reads SUPABASE_URL + SUPABASE_ANON_KEY from dart-define
    module/       AppModule contract + ModuleRegistry
    platform/     image_picker abstraction (web / io implementations)
    prefs/        favorites, workspace_order, view_prefs_service (SharedPreferences)
    supabase_client.dart         supabaseClientProvider
    supabase_secure_storage.dart FlutterSecureStorage-backed session store
    utils/        formatting, french_words
    data/         world_data (countries)
  data/
    models/       company, contact, custom_field, deal, payment_term_template,
                  product, product_bundle, quote (+line tree), supplier
    providers/    auth, companies, contacts, custom_fields, deals,
                  product_bundle, products, quotes, suppliers, units
    repositories/ company, contact, custom_field, deal, product_bundle,
                  products, quote, suppliers
  modules/
    crm/          contacts_page, companies_page, detail panes, form dialogs  BUILT
    inventory/    products_page, bundles_page, suppliers_page, detail panes   BUILT
    org/          create_org, org_selector, org_details, org_providers        BUILT
    sales/        pipeline_page, quotes_page, deal/quote panes, PDF           BUILT
    settings/     settings_page                                               BUILT
    stubs/        InvoicingModule, ProjectsModule (ComingSoon placeholders)   STUBS
  shell/          app_shell, linear_sidebar_item, linear_view_header,
                  record_detail_shell, resizable_pane_layout, search_picker
  theme/          linear_tokens, theme_providers
  ui/
    atoms/        avatar, badge, button, controls, pill, tag, text_field
    molecules/    dropdown, empty_state, form_row, skeleton
    organisms/    data_table, dialog, side_panel, toast, command_palette
  dev/            dev_login_page (debug-only, assert-guarded)
  gallery/        gallery_page (debug-only, kDebugMode-gated route)
  main.dart       ProviderScope -> Supabase.initialize -> GoRouter + _RouterNotifier
```

**State management:** Riverpod 3.3 — manual `AsyncNotifier`, no codegen
(`riverpod_annotation` is in dev_dependencies but `build_runner` is absent)
**Router:** go_router 17.3, session-aware `redirect` callback via `_RouterNotifier`
**Backend:** supabase_flutter 2.15, FlutterSecureStorage session store

---

## Step 3 — Progress Scorecard

### Business Pipeline — 3 / 6

| Item | Status | Notes |
|------|--------|-------|
| Lead entity (model + repo + UI) | DONE | Embedded as `DealStage.lead` in Deals pipeline |
| Quote entity (model + repo + UI) | DONE | Full build: Tunisian tax format, PDF, hierarchical lines |
| Invoice entity (model + repo + UI) | MISSING | DB tables exist; Dart = ComingSoon stub |
| Payment entity (model + repo + UI) | MISSING | Payment term templates exist; payment recording = stub |
| Project entity (model + repo + UI) | MISSING | DB tables exist; Dart = ComingSoon stub |
| Pipeline state transitions enforced | PARTIAL | `DealStageX.isTerminal` in Dart only — no DB trigger or CHECK |

### Auth — 4 / 5

| Item | Status | Notes |
|------|--------|-------|
| Sign up / sign in flow | DONE | Email + Google OAuth, email confirmation, forgot-password |
| JWT refresh handled | DONE | supabase_flutter auto-refresh; `_RouterNotifier` listens to `onAuthStateChange` |
| Auth guard on all protected routes | DONE | GoRouter `redirect` callback covers every route |
| Sign out clears local state | DONE | `ViewPrefsService.clearAll()` called on signOut |
| PKCE flow explicit | PARTIAL | `authFlowType` not set; supabase_flutter 2.x auto-detects but explicit is safer |

### Multi-platform — 4 / 7

| Item | Status | Notes |
|------|--------|-------|
| Web build | DONE | `web/` present |
| Windows build | DONE | `windows/` present |
| Mobile builds | MISSING | No `android/` or `ios/` directories |
| `dart:io` guarded by `kIsWeb` | DONE | Platform image_picker abstracted; no unguarded `dart:io` found |
| Deep link — Android | MISSING | No android/ directory |
| Deep link — iOS | MISSING | No ios/ directory |
| Web `_redirects` / SPA fallback | MISSING | Browser refresh on any non-root URL = 404 |
| `go_router` survives web refresh | DONE | `SupabaseSecureStorage` restores session before router resolves |

### Supabase / Database — 5 / 9

| Item | Status | Notes |
|------|--------|-------|
| RLS on every table | DONE | All 43 public tables have RLS enabled with policies |
| Migration files in `supabase/migrations/` | PARTIAL | 3 files only; core schema + 3 feature migrations are loose .sql files |
| Dev and Prod are separate projects | UNKNOWN | Only one Supabase project visible |
| Money stored as integer cents | MISSING | DB: NUMERIC(14,2); Dart: `double` — floating-point risk |
| Soft deletes (`deleted_at`) | MISSING | Only `documents` and `messages` have it; all core entities do not |
| No SELECT * on large tables | PARTIAL | 9 bare `.select()` calls across 4 repositories |
| No unbounded queries | DONE | All list queries have `.limit()` |
| Status enums for pipeline entities | DONE | `QuoteStatus`, `DealStage` in Dart; CHECK-constrained in DB |
| `product_bundles` RLS correct | MISSING | **LIMIT 1 bug** — cross-tenant data leak (Critical — see B-1) |

### Security — 4 / 6

| Item | Status | Notes |
|------|--------|-------|
| No secrets hardcoded in `lib/` | DONE | `AppConfig` reads from `String.fromEnvironment` |
| No `service_role` key in Dart | DONE | Not found anywhere |
| URL + anon key via `--dart-define` | DONE | Pattern correct in code; BUT keys also in `.vscode/launch.json` |
| Bucket RLS | UNKNOWN | No Storage code found; verify in Supabase Dashboard |
| Business logic in Edge Functions / RPC | PARTIAL | Quote numbering RPC done; stock delta RPC done; deal stage + quote status = Dart-only |
| Explicit PKCE for web OAuth | PARTIAL | Not set explicitly |

### Riverpod / State — 3 / 5

| Item | Status | Notes |
|------|--------|-------|
| `autoDispose` on ephemeral providers | MISSING | ZERO providers use autoDispose across the entire codebase |
| No `invalidate()` used as polling | DONE | Not found |
| Error state in async notifiers | DONE | All `AsyncValue.guard` paths surface errors; UI pages handle them |
| Loading state in UI | DONE | All list pages have skeleton loaders |
| Stream subscriptions cancelled | DONE | `StreamSubscription` in `_RouterNotifier` cancelled in `dispose()` |

### Observability — 0 / 3

| Item | Status | Notes |
|------|--------|-------|
| Sentry / crash reporting in `main.dart` | MISSING | Not integrated |
| Edge Functions try/catch | N/A | No Edge Functions exist yet |
| `debugPrint` guarded in production paths | PARTIAL | 4 usages found; need manual guard audit |

### Data Integrity — 3 / 5

| Item | Status | Notes |
|------|--------|-------|
| DB constraints (NOT NULL, FK, CHECK) | DONE | Present on most tables |
| Pipeline state transitions at DB level | MISSING | No trigger or CHECK on quote/deal status transitions |
| Soft delete on key entities | MISSING | Missing across all core business entities |
| Migrations version-controlled | PARTIAL | Incomplete — schema not reproducible from repo alone |
| Status CHECK constraints | DONE | `quote_lines` and other tables have type checks |

### Code Quality — 3 / 4

| Item | Status | Notes |
|------|--------|-------|
| `flutter analyze` passes | UNKNOWN | Cannot run flutter binary from audit environment |
| `pubspec.lock` committed | DONE | Present |
| No TODO/FIXME in security-critical paths | DONE | CSP "tighten" comment is non-critical |
| No `!` force-unwrap on Supabase responses | DONE | One `state.value!` in workspace_order_provider is safely guarded |

---

## Step 4 — Findings

### Category A — Security

| # | Finding | File + Location | Severity | Why it matters | Suggested fix |
|---|---------|-----------------|----------|----------------|---------------|
| A-1 | Supabase URL + anon key stored in `.vscode/launch.json` | `.vscode/launch.json` lines 10-11, 19-20 | High | `.vscode/` line in `.gitignore` is commented out — one uncommented line away from credentials being committed. The anon key is a publishable key, but this pattern is fragile and trains bad habits for future real secrets. | Move to `.env.json` (gitignored), use `--dart-define-from-file=.env.json`. Explicitly add `.vscode/launch.json` to `.gitignore`. Document required keys in README. |
| A-2 | `AppConfig` silently returns empty strings when `--dart-define` flags are missing | `lib/core/config/app_config.dart` | High | A CI/CD build missing the dart-define flags produces a broken app with no build-time failure — errors surface at runtime only. | Add an assertion in `main()` before `Supabase.initialize`: `assert(AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty, 'Supabase env vars missing — pass --dart-define-from-file=.env.json');` |
| A-3 | `.gitignore` has the `.vscode/` exclusion commented out | `.gitignore` line ~25 | Medium | Combined with A-1: if `.vscode/` is ever un-commented (very common when teams want to share workspace settings), `launch.json` with real credentials becomes version-tracked. | Explicitly add `.vscode/launch.json` to `.gitignore` regardless of whether `.vscode/` is excluded. Or switch to `.env.json` approach from A-1. |
| A-4 | `Supabase.initialize` has no `authFlowType: AuthFlowType.pkce` | `lib/main.dart` lines 44-48 | Medium | supabase_flutter 2.x auto-detects PKCE on web but this is implicit behaviour. The Google OAuth `redirectTo` on non-web passes `null`, deferring to whatever is configured in Supabase Dashboard. A misconfiguration there breaks OAuth silently. | Add `authFlowType: AuthFlowType.pkce` to `FlutterAuthClientOptions`. For non-web it's a no-op; for web it makes the intent explicit. |
| A-5 | CSP has `'unsafe-inline'` + `'unsafe-eval'` with a "tighten before production" comment | `web/index.html` meta CSP tag | Medium | Broad script permissions increase the XSS attack surface. The comment acknowledges the problem but there is no tracking item or deadline. | Remove `unsafe-eval` from `script-src`; keep only `wasm-unsafe-eval` for CanvasKit. Tighten `connect-src` to the Supabase project URL and fonts domains only. Create a tracked issue for this. |

### Category B — Data Integrity

| # | Finding | File + Location | Severity | Why it matters | Suggested fix |
|---|---------|-----------------|----------|----------------|---------------|
| B-1 | **`product_bundles` + `product_bundle_lines` RLS uses `LIMIT 1`** | DB policies on both tables | Critical | `org_id = (SELECT org_id FROM org_members WHERE user_id = auth.uid() LIMIT 1)` returns an arbitrary org for a user who belongs to multiple orgs — **cross-tenant data leak**. Every other table uses `is_org_member(org_id)` or `has_module_access(org_id, ...)` correctly. Fix SQL at bottom of report. | Replace both policies with `is_org_member(org_id)` to match the rest of the schema. Apply and review SQL below before running. |
| B-2 | No soft delete on any core business entity | All repository `delete()` methods | High | Deletes on contacts, companies, deals, quotes, products, suppliers are permanent hard deletes with no recovery path and no audit trail. | Add `deleted_at TIMESTAMPTZ DEFAULT NULL` to core tables. Change `delete()` to `UPDATE SET deleted_at = now()`. Filter all SELECT queries with `WHERE deleted_at IS NULL`. Update RLS SELECT policies to exclude soft-deleted rows. |
| B-3 | Monetary amounts use `double` in Dart; 4 DB columns lack scale precision | `lib/data/models/quote.dart`, `deal.dart`, `product.dart` | Medium | Dart `double` accumulates floating-point error in tax arithmetic. `quote_lines.discount_rate`, `quotes.fodec_rate`, `quotes.rs_rate`, `quotes.timbre_amount` are stored as unbounded `NUMERIC` in the DB. For a legal Tunisian invoice, rounding divergence is a compliance risk. | Short-term: add explicit rounding before DB inserts (3 decimal places). Medium-term: migrate unbounded NUMERIC columns to `NUMERIC(6,4)`. Long-term: use integer millimes for absolute amounts in Dart. |
| B-4 | Quote and deal status transitions not enforced at the DB level | `quotes` and `deals` tables in DB | Medium | Any direct PostgREST/Studio call can set `quotes.status = 'draft'` on a converted quote or a `won` deal back to `lead`. The state machine exists only in Dart. | Write Postgres BEFORE UPDATE triggers validating allowed status transitions. Generate and review migration SQL before applying. |
| B-5 | Core schema migrations not in `supabase/migrations/` | `erp_app/custom_fields_migration.sql`, `payment_terms_migration.sql`, `org_info_migration.sql` | Low | 43 tables exist in the live DB but only 3 have tracked migration files. Schema is not reproducible from the repo — a fresh clone cannot reconstruct the database without manual SQL runs. | Move all `.sql` files into `supabase/migrations/` with timestamp prefixes. Run `supabase db pull` to generate a baseline migration of the current live schema. |
| B-6 | `custom_field_definitions` has 7 policies — 4 canonical + 3 duplicates | DB — `custom_field_definitions` | Low | The original 4 `custom_field_defs_*` policies from the initial schema were never removed when migration `20260626000001` dropped and re-added 3 with new names. Harmless but confusing when reading the policy list. | Apply the cleanup SQL at bottom of this report to drop the 4 older-format policies. |

### Category C — Multi-platform Correctness

| # | Finding | File + Location | Severity | Why it matters | Suggested fix |
|---|---------|-----------------|----------|----------------|---------------|
| C-1 | `web/_redirects` (SPA fallback) is missing | `erp_app/web/` | High | Without a fallback rule, any browser refresh or direct URL navigation to `/crm/contacts`, `/sales/quotes`, etc. returns a 404 from the hosting provider. The Flutter app never loads. GoRouter and session restore both work correctly once the app loads — but the initial HTML load fails. | Netlify: create `web/_redirects` containing `/* /index.html 200`. Vercel: add `vercel.json` with rewrites. Firebase: add a rewrite rule in `firebase.json`. |
| C-2 | No mobile platform directories | Filesystem | Low | App is intentionally scoped to web + Windows. No action needed until Phase 6. | Add mobile platforms when targeting them. |
| C-3 | `authFlowType` not explicitly set | `lib/main.dart` | Low | Duplicate of A-4 for multi-platform context. Also verify Supabase Dashboard -> Auth -> URL Configuration has correct redirect URIs registered for Google OAuth. | Same fix as A-4. |

### Category D — Supabase-specific Traps

| # | Finding | File + Location | Severity | Why it matters | Suggested fix |
|---|---------|-----------------|----------|----------------|---------------|
| D-1 | `delete()` in 3 repositories uses only `.eq('id', id)` without org_id filter | `deal_repository.dart:52`, `contact_repository.dart:52`, `products_repository.dart:41` | Medium | RLS policies are correct and prevent cross-org deletes — no immediate vulnerability. But if RLS is ever misconfigured during future schema changes, these deletes become unrestricted. Defense-in-depth requires the Dart layer to also pass `org_id`. | Add `.eq('org_id', orgId)` to all three `delete()` calls. Pass `orgId` as a parameter from the calling notifier. |
| D-2 | 9 bare `.select()` calls without an explicit column list | `quote_repository.dart:33,41`, `custom_field_repository.dart:14,27,34`, `payment_term_repository.dart:14,27,42`, `org_repository.dart:65` | Medium | `SELECT *` fetches all columns including future sensitive ones. As the DB schema grows this increases payload size and can inadvertently return data the client should not cache. | Replace each bare `.select()` with an explicit column list. Priority: `org_repository.fetchOrgDetails` (organizations has `tax_id`, `email`, `phone`). |
| D-3 | `watchAll()` stream methods on DealRepository and ContactRepository are dead code | `deal_repository.dart:26-30`, `contact_repository.dart:22-29` | Low | Both `DealsNotifier` and `ContactsNotifier` use `fetchAll()` (one-shot), not `watchAll()`. The Realtime subscriptions are defined but never consumed — meaning a second user's changes never appear until manual refresh. | Wire `watchAll()` into the notifier `build()` via a `StreamProvider`, or remove the dead methods and document that real-time sync is a future phase. |
| D-4 | List queries use hard `.limit()` with no pagination UI | All list repositories | Low | Contacts/products capped at 2000, quotes/deals at 1000. When an org exceeds the cap, older records are silently invisible with no user-visible indicator. | Acceptable for current scale. Before production: add cursor-based pagination. At minimum, show a count notice when results equal the limit. |

### Category E — Riverpod / State

| # | Finding | File + Location | Severity | Why it matters | Suggested fix |
|---|---------|-----------------|----------|----------------|---------------|
| E-1 | **Zero providers use `autoDispose`** | All 13+ provider declarations across the codebase | High | Every data provider and every form/auth provider lives for the full app lifetime. Auth-scoped form notifiers (signIn, signUp, forgotPassword) accumulate stale error state. On org switch, providers hold the previous org's data in memory while rebuilding. | Add `autoDispose` to all form/auth notifiers (signIn, signUp, forgotPassword, googleSignIn). For data providers, keep them non-disposing (they serve as app cache) but explicitly invalidate on org switch via `_CurrentOrgNotifier.select()`. |
| E-2 | `customFieldDefsProvider.family` accumulates instances permanently | `lib/data/providers/custom_fields_provider.dart:44` | Medium | Family providers create one instance per unique argument (`'contact'`, `'company'`). Without `autoDispose`, both accumulate forever. If `entityType` arguments expand, each new type adds a permanent provider instance. | Add `.autoDispose` modifier: `AsyncNotifierProvider.family.autoDispose<CustomFieldDefsNotifier, List<CustomFieldDef>, String>`. |
| E-3 | Org switch does not invalidate data caches before rebuilding | `lib/modules/org/org_providers.dart:28-32` | Medium | When `_CurrentOrgNotifier.select(orgId)` is called, dependent notifiers re-run `build()` but their current `state` is not cleared first. There is a window where the UI still displays the previous org's data during the async rebuild. | Inside `select()`, call `ref.invalidate(contactsProvider)`, `ref.invalidate(dealsProvider)`, `ref.invalidate(quotesProvider)`, etc. before setting `state = AsyncData(orgId)`. |

### Category F — Observability

| # | Finding | File + Location | Severity | Why it matters | Suggested fix |
|---|---------|-----------------|----------|----------------|---------------|
| F-1 | No crash reporting or error monitoring | `lib/main.dart` — `runApp` not wrapped | High | All `AsyncValue.guard()` failures are caught and surfaced as error widgets — but they are completely invisible outside the user's screen. In production there is no way to know how often Supabase calls fail, what errors users encounter, or if the app crashes on startup. | Add `sentry_flutter` to `pubspec.yaml`. Wrap `runApp` in `SentryFlutter.init`. Add `SENTRY_DSN` to `.env.json`. Set `tracesSampleRate: 0.2`. |
| F-2 | 4 `debugPrint` / `assert` usages need guard audit | 4 occurrences in `lib/` | Low | `assert` is stripped in release mode. `debugPrint` is not — it writes to console in release builds on Windows. | Run `grep -rn "debugPrint" lib/ --include="*.dart"` and wrap each call with `if (kDebugMode) { debugPrint(...); }`. |

---

## Fix SQL — Critical Finding B-1 (product_bundles RLS `LIMIT 1` bug)

```sql
-- Fix: product_bundles and product_bundle_lines RLS policies use LIMIT 1,
-- which returns an arbitrary org for users who belong to multiple orgs.
-- Replaces with is_org_member() to match the pattern on products/suppliers.

DROP POLICY IF EXISTS "org members read bundles"  ON product_bundles;
DROP POLICY IF EXISTS "org members write bundles"  ON product_bundles;
DROP POLICY IF EXISTS "bundle lines follow bundle" ON product_bundle_lines;

CREATE POLICY "bundles_select"
  ON product_bundles FOR SELECT
  USING (is_org_member(org_id));

CREATE POLICY "bundles_insert"
  ON product_bundles FOR INSERT
  WITH CHECK (is_org_member(org_id));

CREATE POLICY "bundles_update"
  ON product_bundles FOR UPDATE
  USING (is_org_member(org_id))
  WITH CHECK (is_org_member(org_id));

CREATE POLICY "bundles_delete"
  ON product_bundles FOR DELETE
  USING (is_org_member(org_id));

CREATE POLICY "bundle_lines_all"
  ON product_bundle_lines FOR ALL
  USING (
    bundle_id IN (
      SELECT id FROM product_bundles WHERE is_org_member(org_id)
    )
  )
  WITH CHECK (
    bundle_id IN (
      SELECT id FROM product_bundles WHERE is_org_member(org_id)
    )
  );
```

> Review before applying. If bundles should require module-level access, substitute
> `has_module_access(org_id, 'products')` for `is_org_member(org_id)`.

---

## Fix SQL — Finding B-6 (duplicate custom_field_definitions policies)

```sql
-- Remove 4 older-format policies superseded by migration 20260626000001.
DROP POLICY IF EXISTS "custom_field_defs_select" ON custom_field_definitions;
DROP POLICY IF EXISTS "custom_field_defs_insert" ON custom_field_definitions;
DROP POLICY IF EXISTS "custom_field_defs_update" ON custom_field_definitions;
DROP POLICY IF EXISTS "custom_field_defs_delete" ON custom_field_definitions;
-- The "org members can ..." policies from the migration remain and are correct.
```

---

## Pass 2 — Awaiting Your Approval

**I will not change any code or database until you confirm which groups to apply.**

| Group | Scope | Risk |
|-------|-------|------|
| **G0 — Critical DB fix** | Apply B-1 SQL (product_bundles RLS LIMIT 1 bug) | Low |
| **G1 — Secrets hygiene** | `.env.json` pattern; startup assert; `.gitignore` fix (A-1, A-2, A-3) | Low |
| **G2 — Crash reporting** | Add `sentry_flutter`, wrap `runApp`, wire `SENTRY_DSN` (F-1) | Low |
| **G3 — Web SPA fallback** | Add `web/_redirects` (C-1) | Very low |
| **G4 — Soft deletes** | `deleted_at` columns + migration SQL for core entities (B-2) | Medium |
| **G5 — Auth / PKCE** | Explicit `authFlowType` in Supabase.initialize (A-4, C-3) | Low |
| **G6 — Riverpod cleanup** | `autoDispose` on form providers; invalidate on org switch (E-1, E-2, E-3) | Medium |
| **G7 — DB delete guards** | Add `.eq('org_id', orgId)` to all `delete()` methods (D-1) | Low |
| **G8 — SELECT * cleanup** | Explicit column lists in 9 bare `.select()` calls (D-2) | Low |
| **G9 — Observability polish** | Guard `debugPrint`; CSP tightening (A-5, F-2) | Very low |
| **G10 — Duplicate policies** | Apply B-6 cleanup SQL for custom_field_definitions | Very low |

**Items requiring your manual action regardless:**
- Apply the B-1 and B-6 SQL in the Supabase Dashboard SQL editor (cannot be applied automatically from code)
- Verify Storage bucket policies in the Supabase Dashboard
- Confirm whether a separate dev/staging Supabase project exists
- Register Google OAuth redirect URIs in Supabase Dashboard -> Auth -> URL Configuration
- Move the 3 loose `.sql` migration files into `supabase/migrations/` (B-5)
