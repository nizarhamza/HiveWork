# Phase 1 — Data & Backend Foundation

> Goal: a multi-tenant Supabase backend and a clean Flutter data layer.

## Supabase setup
- [ ] Create Supabase project + dev / staging / prod environments
- [ ] Initialize `supabase_flutter`; configure env/secrets (no keys in client)
- [ ] Set up the migrations workflow (Supabase CLI)

## Schema — tenancy & access
- [ ] `organizations`
- [ ] `memberships` (user_id, org_id, role)
- [ ] `roles`, `permissions`, `role_permissions`

## Schema — domain entities
- [ ] `contacts`, `companies`
- [ ] `deals`, `quotes`, `quote_lines`
- [ ] `invoices`, `payments`
- [ ] `projects`, `project_templates`, `tasks`

## Conventions
- [ ] `org_id` on every table
- [ ] Audit fields (`created_by`, `created_at`, `updated_at`) everywhere
- [ ] `audit_log` table
- [ ] Money stored as `numeric` / integer cents (never floats)

## Row-Level Security
- [ ] Enable RLS on every table
- [ ] Policies keyed to the JWT `org_id` claim (select / insert / update / delete)
- [ ] Auth hook / edge function injecting `org_id` + `role` into the JWT
- [ ] Cross-org isolation tests (reading another org must fail)

## Flutter data layer
- [ ] Repository classes wrapping Supabase
- [ ] Riverpod providers with explicit loading / error / data states
- [ ] Realtime subscriptions for live updates
- [ ] Decide caching / offline posture
- [ ] Replace Contacts in-memory data with live, org-scoped rows

**Definition of done:** Contacts CRUD hits the real DB, scoped to the signed-in org, with RLS verified.
