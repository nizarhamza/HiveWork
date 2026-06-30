# Tasks

## Active

- [ ] **Audit Remediation** — 22 findings from 2026-06-29 codebase + DB audit. Full checklist in `Tasks (MD)/phase-audit-remediation.md`. Start with G0 (critical RLS fix), then G1 (secrets), G3 (SPA fallback). Score: 52% → target 80%.

- [x] **Sales > Quotes page** — list + split-pane detail, status filter, search, PDF export via `printing` package.
- [x] **Products table — category/brand/model columns** — migration `add_category_brand_model_to_products` applied; index `idx_products_org_category_brand_model` created for default sort (category → brand → model NULLS LAST). Flutter product model, form, list sort, and column headers still need updating (see phase-04a).
- [ ] **Inventory module (Phase 4a)** — Products + Suppliers, stock qty/low-stock, product picker wired into Quotes. Planned in `Tasks (MD)/phase-04a-inventory.md`. Sequenced before Invoicing.
- [ ] **Product Bundles (Phase 4b)** — Pre-defined groups of products (e.g. "Boite à câble" → Disjoncteur + Câble) insertable into quote/invoice lines. Bundles sub-page in Inventory module. Planned in `Tasks (MD)/phase-04b-product-bundles.md`. Sequenced after Phase 4a.
  - **Bundle builder:** select bundle lines by **category only** (not a specific product). Each line stores a category + qty — the bundle is a template, not locked to a brand/model.
  - **Quote insertion flow:** when a bundle is dropped into a quote, each line opens a **brand → model picker** filtered to that line's category, so the user chooses the exact variant at quote time. Until resolved, the line shows `[category] — choose brand/model` as a visual cue.
  - Unresolved lines must be flagged (warning badge) and block PDF export until all are picked.
- [ ] **Product form — Unit dropdown** — replace the Unit free-text field with a dropdown. Suggested options: `Pièce, Mètre, Mètre², Mètre³, Kg, Tonne, Litre, Boîte, Rouleau, Lot, Heure, Forfait`. User can type to filter. At the bottom of the dropdown, a **"+ Add unit"** button lets the user type and save a custom unit (persisted to an `units` lookup table, available across all products). Apply the same dropdown + add button in the quote line picker.
- [ ] **Invoicing module** — Invoices + Payments pages wired to real Supabase data (Phase 4). See `Tasks (MD)/phase-04-business-pipeline.md`.
- [ ] **Projects module** — All projects + Templates pages wired to real Supabase data (Phase 5).
- [ ] **⚠️ Fix client_id FK bug** — `quotes.client_id` / `invoices.client_id` FK points to unused `clients` table; UI picks from CRM contacts/companies. Must resolve before any live invoice is created. Decision: repoint FK to `companies`, or populate `clients` from CRM picks.
- [ ] **Component gallery** — page rendering every widget in all states (Phase 0).

## Waiting On

## Someday
- [ ] **Command palette (Cmd/Ctrl-K)** — global nav + actions; high-leverage for the "facile" goal.
- [ ] **i18n + RTL (EN / FR / AR)** — Phase 6; ARB files, EdgeInsetsDirectional audit, locale-aware formatting.
- [ ] **Cross-platform polish** — Phase 7; web deep links, Windows MSIX, mobile nav adaptation.

## Done

- [x] **Design system tokens + shell** — LinearTokens, LinearColors, LinearSpacing, LinearRadii, AppShell, sidebar.
- [x] **CRM Contacts** — full list + detail, inline editing, custom fields, filter, sort, column picker, Supabase CRUD.
- [x] **CRM Companies** — full list + detail, inline editing, custom fields, filter, Supabase CRUD.
- [x] **Three-pane record-detail shell** — `RecordDetailShell` + `ResizablePaneLayout` reusable templates.
- [x] **Supabase schema + RLS** — 35+ migrations, all domain tables (organizations, contacts, companies, deals, quotes, invoices, payments, projects, tasks), RLS policies, realtime, triggers, custom fields.
- [x] **Auth** — login, signup, magic link, forgot password, verify email, org selection, multi-tenant session.
- [x] **Sales > Pipeline** — kanban board + list view, deal detail pane, create/edit deal form, Supabase CRUD.
