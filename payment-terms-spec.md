# Payment Terms — Feature Spec

## Problem

The current free-text input for payment terms is error-prone and inconsistent. Users type things like "30% avance, 70% à la livraison" differently every time, making it impossible to report on or enforce standard terms.

---

## Proposed Design

### Core concept

A payment term is a **named template** made up of **N installments**, each with:
- A **percentage** (must sum to 100%)
- A **milestone label** (chosen from a predefined list or typed freely)

---

## Settings Page — Term Builder

Replace the free-text input with a structured builder.

### Layout

```
Payment Terms
Define the standard payment schedules available when creating a quote.

[ + New Payment Term ]

┌─────────────────────────────────────────────────────────┐
│  100% Avance                                     [Edit] [Delete]
│  ● 100% — Avance
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  30/70 — Avance / Livraison                      [Edit] [Delete]
│  ● 30% — Avance
│  ● 70% — Livraison
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  40/40/20 — Avance / Livraison / Réception       [Edit] [Delete]
│  ● 40% — Avance
│  ● 40% — Livraison
│  ● 20% — Réception
└─────────────────────────────────────────────────────────┘
```

### Builder modal (New / Edit)

```
┌──────────────────────────────────────────────────────┐
│  New Payment Term                                    │
│                                                      │
│  Name  [30/70 — Avance / Livraison         ]        │
│        (auto-generated, editable)                    │
│                                                      │
│  Installments                                        │
│  ┌─────────────────────────────────┐                │
│  │ #1  [ 30 ]%  [ Avance       ▼] │ [×]            │
│  │ #2  [ 70 ]%  [ Livraison    ▼] │ [×]            │
│  └─────────────────────────────────┘                │
│  [ + Add installment ]                               │
│                                                      │
│  Total: 100% ✓                    [Cancel] [Save]   │
└──────────────────────────────────────────────────────┘
```

**Behavior:**
- Percentages must sum to exactly 100% before saving (live validation with a running total shown)
- Minimum 1 installment, maximum 5
- Name is auto-generated from the parts (e.g., "30% / 70%") but can be overridden
- Milestone dropdown options: Avance, Livraison, Réception, Fin de chantier, Fin de garantie — plus a "Autre…" option that opens a free text field

---

## Quote Creation — Payment Term Selector

Replace the dropdown/text field with a **visual selector**.

### Compact view (default)

```
Payment Terms
┌──────────────────────────────────────────────────────┐
│  30/70 — Avance / Livraison                    [▼]  │
│  ● 30% Avance  ● 70% Livraison                      │
└──────────────────────────────────────────────────────┘
```

### Dropdown open

```
┌──────────────────────────────────────────────────────┐
│  100% Avance                                         │
│  ● 100% Avance                                       │
│  ─────────────────────────────────────────           │
│  30/70 — Avance / Livraison              ← selected  │
│  ● 30% Avance  ● 70% Livraison                       │
│  ─────────────────────────────────────────           │
│  40/40/20 — Avance / Livraison / Réception           │
│  ● 40% Avance  ● 40% Livraison  ● 20% Réception      │
│  ─────────────────────────────────────────           │
│  + Manage payment terms (→ Settings)                 │
└──────────────────────────────────────────────────────┘
```

Each option shows the breakdown inline so the user can confirm without opening anything.

---

## Data Model

### `payment_term_templates` table

| column | type | notes |
|---|---|---|
| `id` | uuid PK | |
| `name` | text | e.g. "30/70 — Avance / Livraison" |
| `installments` | jsonb | ordered array (see below) |
| `created_at` | timestamptz | |

**`installments` shape:**
```json
[
  { "order": 1, "percent": 30, "label": "Avance" },
  { "order": 2, "percent": 70, "label": "Livraison" }
]
```

### On the quote

Store the **snapshot** of the chosen term (not just the FK) so that editing a template later doesn't silently change existing quotes:

```sql
-- quotes table additions
payment_term_template_id  uuid  REFERENCES payment_term_templates(id)  -- optional, for traceability
payment_term_snapshot     jsonb  -- always written at quote save time
```

---

## Validation Rules

| rule | where enforced |
|---|---|
| Percentages must sum to 100% | Builder UI (live) + DB check constraint |
| At least 1 installment | Builder UI |
| Max 5 installments | Builder UI |
| Percent per installment: 1–99% (except single 100%) | Builder UI |
| Template name unique per org | DB unique constraint |

---

## Open Questions

1. Should users be able to **override** the term on a per-quote basis (ad-hoc, not saved as a template)?
2. Are milestone labels fixed per language, or should they be customizable per org?
3. Should the installments appear as **line items** on the PDF quote, or only in a summary block?
