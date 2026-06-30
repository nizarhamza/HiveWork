# ERP — Completion Roadmap

From the approved Linear design to a shippable, multi-tenant ERP.
Single Flutter codebase: **web → Windows → mobile**. Backend: **Supabase**.

## Principles to hold throughout

- **Design-first** — every screen is built from the tokenized design system and the shared shell. Nothing hardcodes color/size/spacing. New surfaces reuse existing components before new ones are made.
- **Facile (no expert needed)** — wizards and templates over blank forms, sensible defaults, progressive disclosure, a command palette, plain language, guided empty states.
- **Modular** — every feature is an `AppModule`. Adding one is one file + one line, and it inherits the design automatically.
- **Tenant safety is non-negotiable** — `org_id` on every table and Row-Level Security from the first table onward; never trust the client alone.

## Where we are now

Done: Linear design system (tokens, theme), the single-sidebar shell with workspace switcher and nested module nav, the reusable view header, the CRM Contacts list, and Sales/Invoicing/Projects as working stub modules. Data is in-memory; there is no backend, auth, or access control yet.

---

## Phase 0 — Design-system completeness

Goal: a component library deep enough that all later screens are assembly, not invention.

### Core components
- Buttons (filled / ghost / outline — themed), icon buttons, dropdown/select, combobox, checkbox/radio/switch, segmented control.
- Text fields, search field, inline-editable fields, form layout primitives.
- Status & priority pills, labels/tags, avatars (single + stacked), badges.

### Overlays & feedback
- Modal dialog, right-hand side panel (the properties surface), context menu, popover, tooltip.
- Toasts/snackbars, confirmation patterns, skeleton loaders, guided empty states.

### Interaction systems
- **Command palette (Cmd/Ctrl-K)** — global navigation and actions. High-leverage for the "facile" goal.
- Keyboard-shortcut registry and focus management.

### Foundations
- Responsive breakpoints confirmed (desktop three-pane ↔ mobile drawer).
- Accessibility baseline: `Semantics`, focus order, contrast, text scaling, 44dp touch targets.
- Token structure kept theme-swappable so a light theme is possible later.

**Done looks like:** a component gallery page rendering every widget in all states.

---

## Phase 1 — Data & backend foundation

Goal: a multi-tenant Supabase backend and a clean Flutter data layer.

### Supabase setup
- Project, environments, `supabase_flutter` init, env/secret config (no keys in client code).

### Schema
- **Tenancy & access:** `organizations`, `memberships (user_id, org_id, role)`, `roles`, `permissions`, `role_permissions`.
- **Domain entities:** `contacts`, `companies`, `deals`, `quotes`, `quote_lines`, `invoices`, `payments`, `projects`, `project_templates`, `tasks`.
- **Conventions:** `org_id` on every table; audit fields (`created_by`, `created_at`, `updated_at`); an `audit_log` table; money as `numeric`/integer cents (never floats).

### Row-Level Security
- RLS policies keyed to the JWT `org_id` claim on every table.
- Custom JWT claims (`org_id`, `role`) via an auth hook / edge function.
- **Tenant-isolation tests** that attempt cross-org reads and must fail.

### Flutter data layer
- Repositories wrapping Supabase; Riverpod providers exposing streams/futures with explicit loading/error states.
- Realtime subscriptions for live updates and notifications.
- Decide the offline/caching posture (read-cache now; fuller offline later).

**Done looks like:** CRM Contacts reads/writes real rows, scoped to the signed-in org, with RLS verified.

---

## Phase 2 — Auth, access control & onboarding

Goal: people can sign in, belong to an org, and only see what their role allows — entering through a guided setup.

### Authentication
- Sign-up, sign-in, magic link / OAuth, password reset.
- Cross-platform session handling and secure token storage (web, Windows, mobile).

### Multi-tenant membership
- Create-organization flow; invite teammates; accept-invite/join.

### RBAC enforcement
- Server side via RLS (source of truth).
- Client side: `requiredPermission` already on the module contract — hide/disable modules, nav items, and actions; a `permissions` provider drives the UI.

### Onboarding wizard (the "facile" entry)
- Create workspace → invite team → choose enabled modules → seed sample data, all in a few guided steps with no jargon.

**Done looks like:** a new user goes from sign-up to a populated workspace without help, seeing only permitted modules.

---

## Phase 3 — Record-detail pattern & CRM build-out

Goal: the reusable detail experience plus the first fully real module.

### The three-pane record detail (reusable template)
- List | record | right **properties panel** (status, owner, dates, tags).
- Inline editing, activity feed / comments, attachments. Every module's detail screens copy this.

### Reusable data table
- One table component with sorting, grouping, filtering, saved views, and column/display options — reused by every list in the app.

### CRM (full CRUD)
- Contacts + Companies create/read/update/delete, relationships, search, filters, saved views.
- Wire CRM actions into the command palette.

**Done looks like:** open a contact, edit it inline, see history, switch saved views — all reusable elsewhere.

---

## Phase 4 — Business pipeline: Lead → Quote → Invoice → Payment → Project

Goal: the revenue workflow, with transitions enforced server-side.

### Deals
- Opportunities with stages, as both kanban board and list.

### Quotes
- Quote builder with line items and totals; **PDF generation via edge function**; send by email.

### Quote → Invoice → Payment
- Accept quote → create invoice (server-side transition); invoice statuses; record payments.

### Payment → Project
- On payment, **clone a project from a template** (`project_templates` → tasks/phases).

### Mechanics
- Model the flow as a state machine; put conversions in edge functions / DB triggers so they're consistent and can't be bypassed from the client.

**Done looks like:** a deal flows end-to-end to a created project, each step recorded and auditable.

---

## Phase 5 — Projects & tasks

Goal: close the loop opened by the pipeline.

- Projects list/board; tasks, phases, assignments, statuses.
- Template management (create/edit the templates used at project creation).
- Backlinks: project ↔ originating deal/invoice.

---

## Phase 6 — Internationalization & RTL (EN / FR / AR)

Goal: trilingual, right-to-left-correct.

- `intl` + ARB files; runtime locale switching.
- Audit layouts for `EdgeInsetsDirectional` (no hardcoded left/right) so Arabic RTL renders correctly.
- Locale-aware date, number, and currency formatting; translate all module/nav/UI strings.

**Done looks like:** the whole app flips cleanly to Arabic RTL and to French with correct formatting.

---

## Phase 7 — Cross-platform polish

Goal: each target feels native, in your priority order.

### Web (primary)
- Path-based URLs (done) + deep links, per-page titles, bundle-size pass, optional PWA.

### Windows
- MSIX packaging, window sizing/state, native menus and keyboard shortcuts, file dialogs for attachments/exports.

### Mobile (iOS + Android)
- Adapt navigation (bottom nav / drawer) and gestures; push notifications; permissions; store builds. Optimize for read/approve flows rather than full data entry.

---

## Phase 8 — Quality, testing & observability

- **Testing:** unit (logic/repos), widget (components), integration (key flows), golden tests for the design system, plus the RLS/security tests from Phase 1.
- **CI:** analyze + test + per-platform builds on every change.
- **Observability:** error tracking (e.g. Sentry), structured logging, privacy-aware analytics.
- **Performance:** profiling, `const` correctness, list virtualization, image/asset caching.

---

## Phase 9 — Security & compliance hardening

- Secrets management; confirm no keys ship in the client.
- Full RLS review; input validation; rate-limiting on edge functions.
- Audit-log review; backups/restore; data-handling and deletion (GDPR-style) practices.

---

## Phase 10 — Launch & operations

- Dev / staging / prod environments and a migrations workflow.
- Release process, rollback triggers, runbooks, and user-facing onboarding docs.
- (If SaaS) billing/subscriptions — e.g. Stripe — as a later, separable add-on.

---

## Suggested sequencing & relative effort

Order: **0 → 1 → 2 → 3 → 4 → 5**, then **6 / 7 / 8** in parallel as features stabilize, then **9 → 10** before launch. Effort is relative size (not time); it depends on how deep each module goes.

| Phase | Focus | Effort |
|------|-------|:----:|
| 0 | Design-system completeness | M |
| 1 | Supabase + multi-tenant data | L |
| 2 | Auth, RBAC, onboarding | L |
| 3 | Record detail + CRM | L |
| 4 | Business pipeline | XL |
| 5 | Projects & tasks | M |
| 6 | i18n + RTL | M |
| 7 | Platform polish (web/Windows/mobile) | L |
| 8 | Testing & observability | M |
| 9 | Security hardening | S–M |
| 10 | Launch & ops | S–M |

## Immediate next two steps

1. **Phase 3 head start — the record-detail three-pane view** (the screen from your reference). It's the template every module reuses, so building it early pays off everywhere.
2. **Phase 1 — Supabase schema + RLS**, to replace the in-memory data with real, tenant-isolated storage.
