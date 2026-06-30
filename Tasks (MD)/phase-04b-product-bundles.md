# Phase 4b — Product Bundles

> Pre-defined groups of **product slots** (category + qty) — not locked to a specific product — that expand into quote lines requiring the user to resolve each slot to a brand + model at quote time. Analogous to "kits" in classic ERP but brand-agnostic so the same bundle works regardless of supplier or brand chosen for a job.

**Status:** Planned — sequenced after Phase 4a (Inventory) because bundles reference the `products` table.

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

## Checklist

### Schema & backend
- [ ] Write migration: `product_bundles` + `product_bundle_lines` (category-slot schema above) + RLS
- [ ] Apply migration to Supabase
- [ ] Add `brand` and `model` columns to `quote_lines` (needed to store resolution snapshot)
- [ ] Add `is_resolved` boolean (default false) to `quote_lines` for unresolved-line guard

### Riverpod layer
- [ ] `ProductBundle`, `BundleWithLines`, `BundleLine` (category + label + qty) Dart models
- [ ] `bundlesProvider` (list, org-scoped)
- [ ] `bundleDetailProvider(id)`
- [ ] `bundleMutationProvider` (create / update / delete)
- [ ] `productsByCategoryProvider(category)` — distinct brand list + model list per brand, used by the resolution picker in quotes

### Bundles page (Inventory module)
- [ ] Add `bundles` nav item to `InventoryModule`
- [ ] `BundlesPage` — list with LinearViewHeader, search, active filter
- [ ] `BundleDetailPane` (right pane) — name, description, slot editor
- [ ] Slot editor: **+ Add slot** → category autocomplete (distinct values from products), optional label, qty, drag-reorder, delete row
- [ ] Save / cancel / soft-delete

### Quote integration
- [ ] Add Bundles tab to `LinkCatalogModal` (alongside Products)
- [ ] Qty prompt on bundle select → `insertBundle()` writes N unresolved `QuoteLine`s with `isResolved = false`
- [ ] Unresolved lines show warning badge + `"[category] — choose brand / model"` placeholder text
- [ ] Tapping unresolved line opens 2-step picker: Brand dropdown → Model dropdown (both filtered to line's category)
- [ ] On model confirm: fill `productId`, `brand`, `model`, `unitPrice`, `taxRate`, `unit`; set `isResolved = true`
- [ ] PDF export guard: block if any line has `isResolved = false`; show banner with count + jump-to link
- [ ] Wire same flow to `InvoiceDetailPage`

### QA
- [ ] Create bundle with 3 slots (different categories), insert into quote — verify 3 unresolved lines appear
- [ ] Resolve each line via brand/model picker — verify warning clears, prices fill correctly
- [ ] Attempt PDF export with unresolved line — verify it is blocked
- [ ] Edit bundle after insertion — verify existing quote lines unchanged (snapshot)
- [ ] Soft-delete bundle — verify it disappears from picker but old quotes unaffected
- [ ] RLS: confirm cross-org bundle read returns 0 rows

---

## Open questions

1. **Qty multiplier:** User enters one qty at insert time ("Insert bundle × N"). All child quantities are multiplied by N at insertion.
2. **Nested bundles:** Not planned for v1 — bundle lines are category slots only, no child-bundle references. Simplifies the schema and avoids cycle-detection complexity.
3. **Price override on resolved lines:** Not in v1 — unit price comes from the resolved product. Manually editable after resolution (same as any quote line).
4. **Category autocomplete source:** Distinct `products.category` values in the org's catalog. If the catalog is empty, the bundle builder shows an empty dropdown — not a blocker, just note it in onboarding.
