# Phase 1 — Data & Backend Foundation

> Goal: a multi-tenant Supabase backend and a clean Flutter data layer.

## Supabase setup
- [x] Create Supabase project + dev / staging / prod environments
- [x] Initialize `supabase_flutter`; configure env/secrets (no keys in client)
- [x] Set up the migrations workflow (Supabase CLI)

## Schema — tenancy & access
- [x] `organizations`
- [x] `memberships` (user_id, org_id, role)
- [x] `roles`, `permissions`, `role_permissions`

## Schema — domain entities
- [x] `contacts`, `companies`
- [x] `deals`, `quotes`, `quote_lines`
- [x] `invoices`, `payments`
- [x] `projects`, `project_templates`, `tasks`

## Conventions
- [x] `org_id` on every table
- [x] Audit fields (`created_by`, `created_at`, `updated_at`) everywhere
- [x] `audit_log` table
- [x] Money stored as `numeric` / integer cents (never floats)

## Row-Level Security
- [x] Enable RLS on every table
- [x] Policies keyed to the JWT `org_id` claim (select / insert / update / delete)
- [x] Auth hook / edge function injecting `org_id` + `role` into the JWT
- [ ] Cross-org isolation tests (reading another org must fail)

## Flutter data layer
- [x] Repository classes wrapping Supabase
- [x] Riverpod providers with explicit loading / error / data states
- [x] Realtime subscriptions for live updates
- [ ] Decide caching / offline posture
- [x] Replace Contacts in-memory data with live, org-scoped rows

**Definition of done:** Contacts CRUD hits the real DB, scoped to the signed-in org, with RLS verified. ✅
