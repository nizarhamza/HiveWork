# Tasks

## Active

- [ ] **Audit Remediation** — 22 findings from 2026-06-29 codebase + DB audit. Full checklist in `Tasks (MD)/phase-audit-remediation.md`. Start with G0 (critical RLS fix), then G1 (secrets), G3 (SPA fallback). Score: 52% → target 80%.

- [ ] **QA — Bundle insertion** — Bundle flow in quotes is implemented but untested. Run QA checklist: nested bundles, qty multiplier, snapshot behaviour, soft-delete picker, cross-org RLS. See `Tasks (MD)/phase-04b-product-bundles.md`.

- [ ] **Product form — Unit dropdown** — In-memory provider done (`units_provider.dart`). Still needed: persist custom units to a `units` DB table so they survive across sessions and are shared across all products/quotes in the org. Apply the same dropdown in the quote line picker.

- [x] **⚠️ Fix client_id FK bug** — Replaced `client_id→clients` with `company_id→companies` + `contact_id→contacts` on both `quotes` and `invoices`. Migration applied 2026-07-01. Flutter model, repository join, and form state all updated.

- [x] **Invoicing module** — Invoices + Payments pages wired to real Supabase data (Phase 4). Full CRUD, quote→invoice conversion, record-payment dialog, auto-mark-paid, Tunisian tax format (FODEC/TVA/timbre/RS), split-pane detail, payments history.

- [ ] **Projects module** — All projects + Templates pages wired to real Supabase data (Phase 5).

- [ ] **RBAC enforcement + onboarding wizard (Phase 2 remainder)** — Invite teammates by email, accept-invite flow, `permissions` provider filtering modules by role, onboarding wizard steps. See `Tasks (MD)/phase-02-auth-rbac.md`.

## Waiting On

## Someday
- [ ] **Bon de Commande / Bon de Livraison** — Sales order + delivery note flow with three-way match (BC ↔ BL ↔ Invoice). See `Tasks (MD)/phase-04-business-pipeline.md`.
- [ ] **Payment → Project** — On invoice `paid`, clone a project template into `projects` + `tasks`.
- [ ] **Command palette** — Register Inventory actions ("New product", "New supplier", "Go to Inventory") now that the palette is built.
- [ ] **Cross-org isolation tests** — Automated tests that attempt cross-org reads and must fail (Phase 1 remaining item).
- [ ] **Saved views + row selection** — Data table grouping, saved views, bulk actions (Phase 3 remaining items).
- [ ] **Activity feed / comments / attachments** — Record detail extensions (Phase 3).
- [ ] **i18n + RTL (EN / FR / AR)** — Phase 6; ARB files, EdgeInsetsDirectional audit, locale-aware formatting.
- [ ] **Cross-platform polish** — Phase 7; web deep links, Windows MSIX, mobile nav adaptation.

## Done

- [x] **Design system tokens + shell** — LinearTokens, LinearColors, LinearSpacing, LinearRadii, AppShell, sidebar.
- [x] **Component library** — AppButton (filled/ghost/outline/danger), AppDropdown (combobox), AppCheckbox/Radio/Switch, AppTextField, AppPill, AppTag, AppAvatar, AppBadge, AppDialog, AppSidePanel, AppToast, AppSkeleton, AppEmptyState, AppFormRow, AppDataTable.
- [x] **Command palette** — `command_palette.dart` + `app_commands.dart` global registry; CRM and Sales actions registered (`crm_commands.dart`, `sales_commands.dart`).
- [x] **Component gallery** — `gallery_page.dart` rendering every atom/molecule/organism.
- [x] **Supabase schema + RLS** — 35+ migrations, all domain tables (organizations, contacts, companies, deals, quotes, invoices, payments, projects, tasks, products, suppliers, bundles), RLS policies, realtime, triggers, custom fields.
- [x] **Auth** — login, signup, magic link, forgot password, verify email, org selection, multi-tenant session.
- [x] **CRM Contacts** — full list + detail, inline editing, custom fields, filter, sort, column picker, Supabase CRUD.
- [x] **CRM Companies** — full list + detail, inline editing, custom fields, filter, Supabase CRUD.
- [x] **Three-pane record-detail shell** — `RecordDetailShell` + `ResizablePaneLayout` reusable templates.
- [x] **Sales > Pipeline** — kanban board + list view, deal detail pane, create/edit deal form, Supabase CRUD.
- [x] **Sales > Quotes** — list + split-pane detail, Tunisian format (FODEC/TVA/timbre/RS), line hierarchy (level 0/1/2), PDF export via `printing`.
- [x] **Payment terms** — `payment_term_templates` CRUD with builder dialog; wired into Quotes.
- [x] **Inventory module (Phase 4a)** — Products + Suppliers full CRUD (Supabase-backed, RLS-scoped), category/brand/model columns + autocomplete, stock qty + low-stock badge, adjust-stock dialog, product picker wired into quote lines (autofills price/tax), `bundles` nav item in Inventory sidebar.
- [x] **Products table — category/brand/model columns** — migration applied, Flutter model/form/list/sort all updated.
- [x] **Product Bundles (Phase 4b)** — Bundle builder (specific product lines + nested bundles, drag-to-reorder, cycle detection), `flattenBundle` recursive expansion, `showBundlePicker` + "Insert bundle" fully wired into quotes (level-0 header + level-1 resolved product lines). QA pending.
