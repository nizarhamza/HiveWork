# Phase 4 — Business Pipeline (Lead → Quote → Invoice → Payment → Project)

> **🔴 Priority Phase.** Prerequisite: Phase 4a (Inventory) and Phase 4b (Product Bundles) must ship first so line items can pick real products.
>
> Goal: the full revenue workflow, with transitions enforced server-side.

---

## Already Done (pre-Phase 4 work)

- [x] **Deals / Pipeline** — kanban board + list view, deal detail pane (`RecordDetailShell`), stage transitions, Supabase CRUD
- [x] **Quotes** — list + split-pane detail, Tunisian format (FODEC/TVA by rate/timbre/RS), line hierarchy (level 0/1/2), PDF export via `printing` (`quote_pdf.dart`)
- [x] **Schema** — `deals`, `quotes`, `quote_lines`, `invoices`, `invoice_lines`, `payments` tables + RLS + realtime

---

## Prerequisite: Fix client_id FK bug

- [ ] Decide: repoint `quotes.client_id` / `invoices.client_id` FK to `companies` (or `contacts`), or populate the legacy `clients` table from CRM picks
- [ ] Apply migration to fix the FK before any live invoice is created

---

## Phase 4a → 4b completion items (tracked in their own files)

- [ ] Phase 4a: Inventory — products + suppliers CRUD, stock counter, product picker wired into quote lines (see `phase-04a-inventory.md`)
- [ ] Phase 4b: Product Bundles — bundle builder, quote insertion with brand/model picker (see `phase-04b-product-bundles.md`)

---

## Bon de Commande (Sales Order)

- [ ] `sales_orders` table + RLS (columns: `org_id`, `deal_id`, `quote_id`, `client_bc_ref`, `status`, `delivery_date_requested`, `payment_terms`)
- [ ] Sales Order create flow — triggered from accepted quote
- [ ] ARC (Accusé de Réception de Commande) — log and optional PDF
- [ ] Sales Order list + detail view (reuse `RecordDetailShell`)
- [ ] Status machine: `received → acknowledged → in_progress → partially_delivered → fulfilled`

---

## Bon de Livraison (Delivery Note)

- [ ] `delivery_notes` table + RLS (columns: `org_id`, `sales_order_id`, `quote_id`, `bl_number`, `delivery_date`, `status`, `signed_at`)
- [ ] `delivery_note_lines` table (qty_ordered, qty_delivered, product_id)
- [ ] BL create flow — triggered from Sales Order (partial or full)
- [ ] BL list + detail view; client signature capture field
- [ ] BL PDF generation (reuse `quote_pdf.dart` section builders)
- [ ] Status machine: `prepared → dispatched → delivered_signed → disputed`

---

## Quote → Invoice transition

- [ ] Accept quote → server-side edge function creates `invoices` + `invoice_lines` from `quotes` + `quote_lines`
- [ ] Guard: quote must be in `accepted` status; idempotent (can't double-invoice)
- [ ] Invoice header populated: `quote_id`, `bl_id` / `pv_id`, tax fields copied from quote
- [ ] Invoice list + detail view (reuse `RecordDetailShell`, three-pane)
- [ ] Invoice PDF — reuse `quote_pdf.dart` section builders with "Facture" label
- [ ] Send invoice by email (edge function)
- [ ] Invoice types: Acompte / Intermédiaire / Solde / Avoir
- [ ] Status machine: `draft → validated → sent → acknowledged → partially_paid → paid → overdue → disputed`

---

## Three-way match (server-side)

- [ ] Edge function (or DB check constraint / trigger): Invoice qty/price must match BC and BL before `validated` status is allowed
- [ ] Surface mismatch errors clearly in the UI

---

## Payment recording

- [ ] Payment create form: amount, date, method (virement / chèque / traite / espèces), reference
- [ ] Link payment(s) to invoice(s) — support partial payments
- [ ] Auto-update invoice status to `partially_paid` / `paid`
- [ ] Quittance PDF on full payment
- [ ] Payments list view

---

## Payment → Project

- [ ] `project_templates` CRUD — create/edit templates with phases + tasks
- [ ] Edge function: on invoice `paid` → clone template into `projects` + `tasks`, link to deal/invoice
- [ ] Project created notification / redirect

---

## Pipeline state machine (mechanics)

- [ ] Model all transitions as a state machine (quote statuses, invoice statuses, delivery statuses)
- [ ] All status transitions via edge functions or DB triggers — never trust raw client UPDATE
- [ ] Audit log entry on every status change (user, timestamp, from_status, to_status, comment)
- [ ] Guard against client-side bypass (RLS + server-side validation)

---

**Definition of done:** a deal flows end-to-end — Quote accepted → BC logged → BL signed → Invoice issued and paid → Project created — with every step recorded, auditable, and tenant-isolated.
