# Phase 4b — Product Bundles

> Pre-defined groups of **product slots** (category + qty) — not locked to a specific product — that expand into quote lines requiring the user to resolve each slot to a brand + model at quote time. Analogous to "kits" in classic ERP but brand-agnostic so the same bundle works regardless of supplier or brand chosen for a job.

**Status:** In progress — data layer + BundlesPage + picker dialog built; quote insertion/resolution flow and QA still TODO.

---

## What "done" looks like

- User creates a **Bundle** (e.g. "Boite à câble") and adds **category slots** — each slot is a category + optional label + qty. No brand or model is chosen here; the bundle is brand-agnostic.
- From a Quote line, **Insert bundle** opens a bundle picker → expands into N unresolved lines, one per slot, showing `[category] — choose brand / model` with a warning badge.
- Per unresolved line the user opens a **2-step picker**: first filter by category (pre-selected from slot), then choose brand → model from the matching products.
- Once all lines are resolved, the warning badge clears and PDF export is unblocked.
- Bundles are managed in **Inventory → Bundles** (not in Settings).
- Full Supabase CRUD with RLS, org-scoped.

---

## Placement decision

| Option | Verdict |
|--------|---------|
| New tab in Quote/Invoice Settings | ✗ Settings is for config (tax rates, numbering), not catalog data |
| New top-level module | ✗ Overkill — bundles are a sub-feature of Inventory |
| **Inventory → Bundles sub-page** | ✓ Correct home — lives next to Products in the Inventory sidebar |
| Inventory → Products → "Bundles" tab | Acceptable fallback if Inventory stays single-page |

**Chosen:** Inventory module gets two sidebar nav items: **Products** and **Bundles**.

---

## Database schema

```sql
-- Bundle header
create table product_bundles (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id),
  name        text not null,         -- e.g. "Boite à câble"
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Bundle lines — category slots only, no product FK
-- Brand/model are chosen at quote time, not here.
create table product_bundle_lines (
  id         uuid primary key default gen_random_uuid(),
  bundle_id  uuid not null references product_bundles(id) on delete cascade,
  category   text not null,          -- must match a value in products.category
  label      text,                   -- optional hint shown on the unresolved quote line
  quantity   numeric(10,3) not null default 1,
  sort_order integer not null default 0
);

-- RLS (mirror the products table pattern)
alter table product_bundles      enable row level security;
alter table product_bundle_lines enable row level security;

create policy "org members read bundles"
  on product_bundles for select
  using (org_id = (select org_id from memberships where user_id = auth.uid() limit 1));

create policy "org members write bundles"
  on product_bundles for all
  using (org_id = (select org_id from memberships where user_id = auth.uid() limit 1));

create policy "bundle lines follow bundle"
  on product_bundle_lines for all
  using (bundle_id in (
    select id from product_bundles
    where org_id = (select org_id from memberships where user_id = auth.uid() limit 1)
  ));
```

> **Key design:** Bundle lines store a `category`, not a `product_id`. The bundle is brand-agnostic by design. Product resolution (brand → model) happens in the quote, not the bundle definition. No price stored on bundle lines — price is pulled from the resolved product at quote time.

---

## Riverpod providers

```
bundlesProvider              → AsyncValue<List<ProductBundle>>        (org-scoped list)
bundleDetailProvider(id)     → AsyncValue<ProductBundleWithLines>     (lines = category slots)
bundleMutationProvider       → CRUD notifier (create / update / delete bundle + lines)
productsByCategoryProvider(category) → AsyncValue<List<Product>>     (for the brand/model picker in quotes)
```

`BundleLine` carries `category`, `label`, `quantity` — no product reference. Resolution to a specific product happens on the `QuoteLine` after the user picks brand/model.

---

## UI — Inventory > Bundles page

Layout mirrors the Products page (LinearViewHeader + list table).

### Bundle list columns
| Column | Notes |
|--------|-------|
| Name | clickable → opens detail pane |
| # Products | count of bundle lines |
| Active | toggle |
| Created | date |

### Bundle detail / create form (right pane or modal)

```
[ Bundle Name _________________ ]   [ Active ✓ ]
[ Description (optional) _______ ]

SLOTS                                             [ + Add slot ]
─────────────────────────────────────────────────────────────────
  Category (dropdown)          Label (hint)       Qty
  Electrical Breakers          Disjoncteur        1
  Cable                        Câble 2.5mm²       3
  Junction Box                 —                  1
─────────────────────────────────────────────────────────────────
```

- **Category dropdown** is populated from distinct `products.category` values in the org's catalog (autocomplete, not a fixed enum).
- **Label** is optional — used as the hint shown on the unresolved quote line (e.g. "Disjoncteur" helps the user know what to pick).
- Drag-to-reorder lines (sets `sort_order`).
- Soft-delete (`is_active = false`) — never hard-delete once a bundle has been used in a quote.

---

## UI — Quote line item picker

Single **[ Link… ]** button → modal with two tabs:

```
┌──────────────────────────────────────┐
│  🔍  Search…                         │
│  ─────────────────────────────────── │
│  Products │ Bundles                  │
│  ─────────────────────────────────── │
│  > Boite à câble    (3 slots)   ──▸  │
│  > Tableau électrique (5 slots) ──▸  │
└──────────────────────────────────────┘
```

Selecting a bundle → qty prompt → expands into N unresolved lines in the quote.

---

## Bundle insertion + resolution flow (quote side)

### Step 1 — Insert (expands to unresolved lines)

```dart
Future<void> insertBundle(ProductBundleWithLines bundle, int atIndex, {double bundleQty = 1}) async {
  for (final slot in bundle.lines) {
    state.addLineAt(atIndex++, QuoteLine(
      category:    slot.category,          // stored — drives the picker filter
      label:       slot.label ?? slot.category,
      qty:         slot.quantity * bundleQty,
      productId:   null,                   // unresolved
      brand:       null,
      model:       null,
      unitPrice:   null,
      isResolved:  false,
    ));
  }
}
```

Unresolved lines are shown with a warning badge (LinearColors.warning) and placeholder text: `"[category] — choose brand / model"`.

### Step 2 — Resolution (brand → model picker per line)

Tapping an unresolved line opens a **2-step inline picker**:

```
┌─────────────────────────────────────────┐
│  Category: Electrical Breakers  (fixed) │
│  ──────────────────────────────────     │
│  Brand    [  Schneider ▾  ]             │
│  Model    [  iC60N-16A  ▾  ]            │
│                            [ Confirm ]  │
└─────────────────────────────────────────┘
```

- **Brand dropdown** = `SELECT DISTINCT brand FROM products WHERE category = slot.category ORDER BY brand`
- **Model dropdown** = `SELECT * FROM products WHERE category = slot.category AND brand = chosen_brand ORDER BY model` — selecting a model fills `unit_price`, `tax_rate`, `unit`, `product_id` on the line and sets `isResolved = true`.
- The warning badge disappears when `isResolved = true`.

### PDF / finalize guard

PDF export and status transitions (draft → sent) are blocked while any line has `isResolved = false`. Show a banner: `"N lines need a product selection before export."` with a button to jump to the first unresolved line.

> **Snapshot behaviour:** Once resolved, the line stores `product_id`, `unit_price`, `brand`, `model` as plain values — independent of the product record. Editing the product later does NOT affect existing quotes.

---

## Inventory module nav update

```dart
// lib/modules/inventory/inventory_module.dart
navItems: [
  NavItem(id: 'products', title: 'Products', icon: Icons.inventory_2_outlined, path: '/inventory/products'),
  NavItem(id: 'bundles',  title: 'Bundles',  icon: Icons.category_outlined,    path: '/inventory/bundles'),
  // future: Suppliers, Stock movements
],
```

---

## Implementation note — approach changed

The original plan used category-only slots (brand-agnostic) with a 2-step resolution picker at quote time. The actual implementation is simpler and better: bundles store **specific product_id** (or child bundle) lines, and `flattenBundle()` recursively expands to leaf products at insertion time. Lines land in the quote already fully resolved (label, qty, unit_price, tax_rate, unit, product_id all filled). No unresolved-line concept needed.

## Checklist

### Schema & backend
- [x] Migration: `product_bundles` + `product_bundle_lines` + RLS applied
- [x] `product_bundles`: name, description, category, price_override, sku, is_active, org_id
- [x] `product_bundle_lines`: product_id (FK) OR child_bundle_id (FK), quantity, sort_order
- [x] Cycle detection: DB function `bundle_would_create_cycle` + Flutter guard in repository

### Riverpod layer
- [x] `ProductBundle`, `ProductBundleLine`, `ProductBundleWithLines`, `FlatBundleLine` models
- [x] `bundlesProvider` (list, org-scoped, with live CRUD mutations)
- [x] `ProductBundleRepository.fetchWithLines(id)` — detail with resolved joins
- [x] `ProductBundleRepository.flattenBundle(id, parentQty)` — recursive expansion (max depth 3)
- [x] `ProductBundleRepository.replaceLines(bundleId, lines)` — replace-all strategy
- [x] Soft-delete (`softDelete`)

### Bundles page (Inventory module)
- [x] `bundles` nav item in `InventoryModule`
- [x] `BundlesPage` — list with LinearViewHeader, search, active-only filter
- [x] `_BundleFormDialog` — create/edit dialog: name, description, category, price override, active toggle
- [x] Slot editor: Add product (via `showProductPicker`), Add by category (all products in category), Add child bundle
- [x] Drag-to-reorder lines (`ReorderableListView`)
- [x] Save / cancel / soft-delete (with `AppDialog.confirm`)

### Quote integration
- [x] `showBundlePicker` dialog — search, select, qty prompt, "Insert" button
- [x] `_insertBundle()` in `quote_form_dialog.dart` — calls `flattenBundle`, writes level-0 header + level-1 product lines (fully resolved: label, qty, unitPrice, taxRate, unit, productId)
- [x] "Insert bundle" button in quote table footer
- [ ] Wire same `_insertBundle` pattern to `InvoiceDetailPage` when Invoicing module is built (Phase 4 main)

### QA
- [ ] Create bundle with products from multiple categories → insert into quote — verify N level-1 lines appear, prices filled
- [ ] Nested bundle (bundle containing a bundle) → insert → verify recursive expansion works
- [ ] Qty multiplier: insert bundle × 3 → verify leaf quantities multiplied
- [ ] Edit bundle after insertion → verify existing quote lines unchanged (snapshot behaviour)
- [ ] Soft-delete bundle → verify it disappears from picker but old quotes unaffected
- [ ] RLS: confirm cross-org bundle read returns 0 rows
