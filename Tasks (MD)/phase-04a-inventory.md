# Phase 4a — Inventory (Products, Suppliers & Stock)

> Goal: a real product/article catalog with stock counts, slotted in **before** Invoicing is wired
> up, so Quotes and Invoices can pick a real product instead of typing a free-text label.
> Inserted ahead of Phase 4 because the backend for it already exists and unblocks better line items.

## Backend reality check (done already — verify, don't rebuild)

The Supabase project (`erp-app`, `nwagdfbwjtdvsxgjgzhm`) already has tables and RLS for this, unused
(0 rows). No migration is needed for v1 — confirm only:

- [x] `products` — `id, org_id, sku, name, description, unit_price, tax_rate, unit, stock_quantity,
      low_stock_threshold, supplier_id, created_at, updated_at`
      **+ `category`, `brand`, `model` added** (migration `add_category_brand_model_to_products`).
      Index `idx_products_org_category_brand_model` created for the canonical sort order.
- [x] `suppliers` — `id, org_id, name, tax_id, currency, contacts (jsonb), payment_terms,
      created_at, updated_at`
- [x] FKs already wired: `products.supplier_id → suppliers.id`, `quote_lines.product_id → products.id`,
      `invoice_lines.product_id → products.id`
- [x] RLS already in place on both tables, gated by `has_module_access(org_id, 'products'|'suppliers')`
      — which auto-passes for `org_role` owner/admin, so solo/owner use needs no extra setup. Team
      members below admin need a `module_members` row once Phase 2's onboarding wizard creates them;
      not a blocker now, just don't forget it when seats are added.

> Note for later cleanup (not part of this phase): the DB also has a second, unused
> `catalog_items` / `tax_codes` / `documents` / `document_lines` engine that nothing in the Flutter
> app reads from. Decided to ignore it for Inventory and build on `products`/`suppliers` since that's
> what Quotes/Invoices already reference. Worth a separate decision later on whether to delete it or
> migrate Quotes/Invoices onto it — flagging so it doesn't get "discovered" and cause confusion.

## Data layer (Flutter)

Mirror the existing `Company`/`Contact` model + repository + provider pattern
(`lib/data/models/company.dart`, `lib/data/providers/companies_provider.dart`).

- [x] `lib/data/models/product.dart` — `Product` (read model) + `ProductInput` (create/edit payload),
      money as `num`/`double` only at the edges, never floats in storage logic
- [x] `lib/data/models/supplier.dart` — `Supplier` + `SupplierInput`
- [x] `lib/data/repositories/products_repository.dart` — Supabase CRUD + a dedicated
      `adjustStock(productId, delta, reason)` method (see Stock handling below)
- [x] `lib/data/repositories/suppliers_repository.dart` — Supabase CRUD
- [x] `lib/data/providers/products_provider.dart` — Riverpod stream/future provider, explicit
      loading/error/data states, realtime subscription (matches Contacts pattern)
- [x] `lib/data/providers/suppliers_provider.dart` — same pattern

## Module & routing

- [x] `lib/modules/inventory/inventory_module.dart` implementing `AppModule`:
  - `id: 'inventory'`, `title: 'Inventory'`, icon e.g. `Icons.inventory_2_outlined`,
    `basePath: '/inventory'`, `requiredPermission: null` (matches CRM/Sales for now)
  - `navItems`: **Products** (`/inventory/products`), **Bundles** (`/inventory/bundles`), **Suppliers** (`/inventory/suppliers`)
  - `routes`: redirect `basePath` → `/inventory/products`, plus all list routes
- [x] Append `InventoryModule()` to `kAppModules` in `lib/core/module/modules.dart`
      (one-line change per the module contract — no other wiring needed)

## UI — Products

- [x] `lib/modules/inventory/products_page.dart` — list page using the existing reusable data table
      (sort/filter/search). **Default sort: `category ASC NULLS LAST → brand ASC NULLS LAST → model ASC NULLS LAST`**
      (matches DB index). Columns: category, brand, model, name, sku, unit price, stock qty,
      low-stock badge, supplier. Consider grouping rows by category (show category as a sticky
      section header when default sort is active).
- [x] `lib/modules/inventory/product_detail_pane.dart` — side panel (reuse `RecordDetailShell` /
      `ResizablePaneLayout`), shows category, brand, model, description, price, tax rate, unit,
      supplier link, stock qty, low-stock threshold, and an activity/audit feed if cheap to wire (else defer)
- [x] `lib/modules/inventory/product_form_dialog.dart` — create/edit dialog matching
      `company_form_dialog.dart` styling: **category** (autocomplete from existing distinct values),
      **brand** (autocomplete), **model**, name, sku, description, unit price, tax rate, unit,
      supplier picker, low-stock threshold
- [x] Low-stock visual indicator: badge/pill when `stock_quantity <= low_stock_threshold`
      (reuse `LinearColors.warning`)

## UI — Suppliers

- [x] `lib/modules/inventory/suppliers_page.dart` — simple list (name, tax id, currency,
      payment terms), no three-pane detail needed for v1 — a form dialog is enough
- [x] `lib/modules/inventory/supplier_form_dialog.dart` — create/edit dialog
- [x] `lib/modules/inventory/supplier_picker_dialog.dart` — reuse the `_ClientPicker` pattern from
      `quote_form_dialog.dart` for selecting a supplier on the product form

## Stock handling (v1 — counter only, no warehouses/movements)

Per the agreed v1 scope: a single `stock_quantity` + `low_stock_threshold` per product, no
multi-warehouse and no movement ledger yet.

- [x] "Adjust stock" action on the product detail pane — small dialog: +/- quantity, optional
      reason note, calls `adjustStock()`
- [x] `adjustStock` writes the new `stock_quantity` directly (no `stock_movements` table this phase)
- [ ] Out of scope for v1, revisit later: `warehouses` table, `stock_movements` ledger,
      multi-location stock, reorder automation

## Integration — Quotes & (future) Invoices

This is the actual payoff for sequencing Inventory before Invoicing.

- [x] In `quote_form_dialog.dart`'s `_LineRow`/`_LineState`: add an optional product picker per line
      (reuse the `_ClientPicker` search-dropdown pattern) that, on selection, autofills
      `label`, `unit_price`, `tax_rate` from the chosen `Product` and stores `product_id`
      on the line (column already exists on `quote_lines`)
- [x] Keep free-text lines working — product selection is optional, not required, so quotes for
      services/one-offs still work
- [ ] When building the Invoicing module (next), carry the same product-picker pattern into its
      line items immediately rather than copy-pasting the old free-text-only version
- [ ] Decide (defer to Invoicing phase if easier): does accepting a quote / confirming an invoice
      decrement `stock_quantity` automatically, or is that a manual "Adjust stock" action? Recommend
      manual for v1 — automatic decrement needs the move to a transactional edge function to avoid
      race conditions across concurrent invoices, which is more than this phase needs.

## Command palette & nav

- [ ] Register "New product", "New supplier", "Go to Inventory" in the command palette
      (command palette now built — no longer blocked)

**Definition of done:** Products and Suppliers are fully real (Supabase-backed CRUD, RLS-scoped to
org), visible in the sidebar as their own module, stock quantity is viewable/adjustable with a
low-stock indicator, and a quote line item can be built from a real product (autofilled price/tax)
instead of only free text.
