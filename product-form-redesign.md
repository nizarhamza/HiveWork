# Product Form Redesign — Specification Field

## Proposed Changes

| Before | After |
|--------|-------|
| ~~Model~~ | *(removed)* |
| ~~Product name~~ | *(removed)* |
| SKU | SKU |
| **—** | **Specification** *(new)* |

### Auto-generated product label
The display name is assembled automatically — no free-text name needed:

```
{Category}  {Brand}  {Specification}  –  {SKU}
```

**Example:** `Onduleur · Sungrow · 3KW – SG3K-S`

---

## Specification by Category

The Specification field captures the **key technical differentiator** for each category. Examples:

| Category | Specification examples | Unit hint |
|---|---|---|
| Onduleur / Inverter | 3KW, 5KW, 10KW, 20KW | KW |
| Panneau solaire | 400W, 550W, 700W | W |
| Batterie | 100Ah / 48V, 200Ah / 24V | Ah + V |
| Câble | 1.5mm², 2.5mm², 6mm², 10mm² | mm² |
| Disjoncteur | 16A 1P, 32A 3P, 63A 3P | A + poles |
| Transformateur | 10KVA, 25KVA, 100KVA | KVA |
| Compteur / Meter | 10A, 40A, 80A | A |
| Luminaire | 24W 4000K, 60W 3000K | W + K |
| Armoire électrique | 24 modules, 36 modules | modules |
| Conduit / Gaine | Ø20, Ø25, Ø32 | mm |

---

## Field Order (updated form)

1. Category  ·  Brand  *(row)*
2. **Specification**  ← replaces Product name + Model
3. SKU  ·  Unit  *(row)*
4. Description
5. Unit price  ·  Tax rate  *(row)*
6. Supplier
7. Low-stock threshold

---

---

## Bundle Creation

When creating a bundle, the user **only picks a Category** — not individual SKUs. The bundle then groups all products under that category.

### Bundle form fields

1. Bundle name
2. Category *(single select — drives which products are included)*
3. Description *(optional)*
4. Unit price override *(optional — leave blank to sum product prices)*

### Behaviour

- Selecting a category auto-lists all products in that category as bundle components.
- User can adjust quantities per component but cannot mix categories in one bundle.
- Bundle SKU is auto-generated: `BDL-{Category slug}-{sequence}` — e.g., `BDL-ONDULEUR-001`.

---

## Quote — Product Picker

When adding a line item to a quote, the product picker shows **SKU + Specification** columns so the user can identify the exact variant quickly.

### Picker columns

| Column | Purpose |
|--------|---------|
| Category | Group / filter |
| Brand | Narrow down maker |
| **Specification** | Key differentiator (3KW, 6mm², etc.) |
| **SKU** | Unique identifier — confirms the right item |
| Unit price | Pre-fills the line |

### UX flow

1. User types in the product search box (searches across Brand + Specification + SKU).
2. Dropdown shows rows: `[Category]  [Brand]  [Specification]  –  [SKU]  · [Unit price]`.
3. Selecting a row pre-fills: SKU, Specification, Unit price, Unit, Tax rate on the quote line.
4. User only needs to enter **Qty** and optionally override the price.

### Quote line columns (table view)

| # | SKU | Specification | Description | Qty | Unit | Unit price | Tax | Total |
|---|-----|--------------|-------------|-----|------|-----------|-----|-------|

---

---

## Tasks

- [ ] Remove **Model** field from the product form entirely — SKU is the sole identifier.
- [ ] Remove **Product name** field — replace with **Specification** (category-aware placeholder, e.g. "e.g. 3KW" for Onduleur).
- [ ] Replace **Unit** free-text with a searchable dropdown. Default options: `Pièce, Mètre, Mètre², Mètre³, Kg, Tonne, Litre, Boîte, Rouleau, Lot, Heure, Forfait`. User types to filter. Bottom of dropdown has a **"+ Add unit"** button to save a custom value to a `units` lookup table (reusable across all products and quote lines).
- [ ] **Bundle creation** — form only asks for Category (+ name, description, optional price override). Category drives included products; bundle SKU auto-generated as `BDL-{category-slug}-{sequence}`.
- [ ] **Quote product picker** — add SKU and Specification columns to the line-item picker. Selecting a row pre-fills SKU, Specification, Unit price, Unit, and Tax rate; user only enters Qty.

---

## Logic notes

- **Specification placeholder:** show a category-aware hint (e.g., "e.g. 3KW" when category = Onduleur).
- **Display name (read-only):** `Brand + Category + Specification` shown as a preview chip once all three are filled — never stored as a separate column.
- **Search / filter:** index on `(category, brand, specification)` — covers the most common lookup patterns.
