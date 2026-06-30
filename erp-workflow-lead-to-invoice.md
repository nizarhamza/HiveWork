# ERP Workflow: Lead → Invoice → Payment
### Complete Document Flow — Nizar's ERP (Flutter / Supabase)

---

> **🔴 Priority Phase:** This is **Phase 4** in the roadmap — the current implementation focus.
> Immediate prerequisite: complete **Phase 4a (Inventory / Products)** and **Phase 4b (Product Bundles)** so quote/invoice line items can pick a real product with autofill price + tax. The pipeline stages from Quote onward are sequenced after that.

---

## Implementation Status

| Stage | Name | Flutter Module | Supabase Table(s) | Status |
|---|---|---|---|---|
| 1 | Lead | CRM | `contacts`, `companies` | ✅ Done (no separate Lead entity — contacts are the lead carrier) |
| 2 | Opportunity / Deal | Sales › Pipeline | `deals` | ✅ Done (kanban + list, deal detail pane, CRUD) |
| 3 | Devis / Quote | Sales › Quotes | `quotes`, `quote_lines` | ✅ Done (Tunisian format: FODEC/TVA/timbre/RS, PDF, line hierarchy) |
| 4 | Bon de Commande | *(not yet built)* | — | 📋 Planned |
| 5 | Bon de Préparation | Inventory | `products`, `stock_movements` | 📋 Planned (after 4a) |
| 6 | Bon de Livraison | *(not yet built)* | — | 📋 Planned |
| 7 | PV de Réception | Projects | — | 📋 Planned (Phase 5 scope) |
| 8 | Facture | Finance › Invoices | `invoices`, `invoice_lines` | 📋 Planned — schema + RLS done; module is a stub |
| 9 | Paiement | Finance › Payments | `payments` | 📋 Planned — table done; module is a stub |
| 10 | Projet | Projects | `projects`, `tasks` | 📋 Planned (Phase 5) — table done; stub module |

### ⚠️ Known Issue to Resolve Before Stage 8
`quotes.client_id` and `invoices.client_id` have a DB FK to the unused `clients` table, but the UI picks from CRM `contacts`/`companies` and writes their id. Inserting a quote violates the FK — currently masked because no live quotes exist yet. **Decision needed before Invoicing builds:** either repoint the FK to `companies`/`contacts`, or populate the `clients` table from CRM picks. The `client_snapshot` JSONB column carries display data fine, but the underlying FK must be fixed.

---

## Overview

This document describes the end-to-end commercial workflow in this ERP, from the first contact with a prospect through to payment collection and project kick-off. Each stage produces one or more **business documents** that are traceable, reference each other, and feed downstream processes.

```
Lead → Opportunity → Devis (Quote) → Bon de Commande → Bon de Livraison
     → Facture (Invoice) → Paiement → Projet
```

**Document chain:** every document references its parent. No Facture without a signed BL or PV. Three-way match (Quote ↔ BL ↔ Invoice) enforced server-side via edge functions / DB triggers — not the client.

---

## Stage 1 — Lead (Prospect)

**Module:** CRM  
**Tables:** `contacts`, `companies`  
**Status:** ✅ Done — no separate Lead entity. A Contact or Company record is the lead carrier. The Deal (Stage 2) records the converted opportunity and links back to the contact/company.

### Data Captured
- Contact name, company, phone, email
- Source (referral, website, cold call, tender notice)
- Initial need / service interest
- Estimated value (optional)
- Assigned sales rep

### Actions
- Qualify or disqualify the lead
- Convert to Opportunity (Deal) if qualified

### Document Produced
| Document | Purpose |
|---|---|
| **Contact / Company Record** | Internal CRM record; not shared externally |

### Status Transitions
`New → In Contact → Qualified → Converted` / `Lost`

---

## Stage 2 — Opportunity / Deal

**Module:** Sales › Pipeline  
**Tables:** `deals`  
**Status:** ✅ Done — kanban board + list view, deal detail pane (three-pane `RecordDetailShell`), stage transitions, Supabase CRUD.

### Data Captured
- Client company (linked CRM Company record)
- Opportunity name and reference
- Estimated value and probability (%)
- Expected close date
- Related contacts and stakeholders
- Stage (e.g. Prospect → Qualification → Proposal → Negotiation → Won / Lost)

### Actions
- Needs analysis / technical scoping
- Prepare and issue Devis (Quote) — linked from deal detail

---

## Stage 3 — Devis / Offre Commerciale (Quote)

**Module:** Sales › Quotes  
**Tables:** `quotes`, `quote_lines`  
**Status:** ✅ Done — Tunisian devis format implemented, PDF export via `printing` package (`lib/modules/sales/quote_pdf.dart`), three-pane list+detail.

**Pending (blocked on Phase 4a):** product picker not yet wired — line items are still free-text. Once Inventory (4a) lands, each line will autofill unit price and tax from the selected product.

### Document Header
| Field | Description |
|---|---|
| `N° Devis` | Sequential reference: `DEV-YYYY-NNNN` |
| `Date d'émission` | Issue date |
| `Date de validité` | Quote expiry (typically 30–90 days) |
| `Objet` | Subject / scope of the offer |
| `N° Contrat` | Contract reference (optional) |
| Client name & address | From `client_snapshot` JSONB (name, address, phone, tax_id) |
| `Matricule Fiscal` | Client tax registration number (Tunisia: required) |

### Document Body
| Field | Description |
|---|---|
| Line items | Hierarchical (level 0/1/2): Description, Qty, Unit, Unit Price HT, Total HT |
| Remise / Discount | Per line (`discount_rate`) |
| Sous-total HT | Total before tax |
| FODEC (1%) | Toggle per document (`fodec_enabled`); only on eligible goods |
| TVA (19% / 13% / 7% / 0%) | Recap by rate (`tvaByRate`); set per line |
| Timbre Fiscal | Toggle per document (`timbre_enabled`); fixed: 1.000 TND |
| Retenue à la Source | Toggle per document (`rs_enabled`); rate configurable (`rs_rate`) |
| **Total TTC** | Grand total including all taxes |

### Line Hierarchy
Lines are a flat ordered list with `level` (0/1/2). Parent is the nearest preceding line at `level - 1`. Numbering is computed at render time in `lib/data/models/quote_line_tree.dart` — not stored. This same model is reused by the future `invoice_lines` table.

### PDF
`lib/modules/sales/quote_pdf.dart` — written as free functions so `invoice_pdf.dart` can reuse the section builders with a label swap.

### Statuses
`Draft → Sent → Under Review → Accepted / Rejected / Revised`

### Key Rules
- An accepted quote **must not be modified** — create a revision (`DEV-2025-0042-R1`) instead
- All subsequent documents reference the Devis number
- Accepted quote may become a legally binding contract if signed by both parties

---

## Stage 4 — Bon de Commande Client (Sales Order / Customer PO)

**Module:** *(not yet built — Sales or Order Management)*  
**Tables:** TBD  
**Status:** 📋 Planned

### Description
When the client accepts the Devis, they issue a **Bon de Commande (BC)**. In the ERP this triggers the creation of a Sales Order on your side. Both must be cross-referenced.

**As Seller:**
- Receive the client's BC → log its reference in the Sales Order
- Issue an **Order Acknowledgement (Accusé de Réception de Commande — ARC)** to confirm

### Document Fields
| Field | Description |
|---|---|
| `N° BC` | Client's PO number (e.g. `BC-CLIENT-2025-117`) |
| `N° Commande Interne` | Internal Sales Order reference |
| `Réf. Devis` | Linked quote reference |
| Client info | Billing & delivery addresses |
| Ordered items | Description, Qty, Unit Price, Total |
| Delivery date requested | Expected delivery / completion date |
| Payment terms | From accepted quote |

### Statuses
`Received → Acknowledged → In Progress → Partially Delivered → Fulfilled`

---

## Stage 5 — Bon de Préparation / Inventory Movement

**Module:** Inventory (Phase 4a)  
**Tables:** `products`, `stock_movements` *(ledger deferred to v2)*  
**Status:** 📋 Planned (after Phase 4a ships)

### Description
Internal document triggering the physical preparation of goods or services. Not sent to the client. In v1, this is a stock decrement against the `products.stock_quantity` counter when a sales order is confirmed.

| Document | Use |
|---|---|
| **Bon de Préparation** | Picking list for warehouse staff |
| **Ordre de Fabrication (OF)** | If goods are manufactured / assembled |

> **Note:** A full `stock_movements` ledger with warehouse-level tracking is deferred to Inventory v2. Phase 4a delivers a single `stock_quantity` / `low_stock_threshold` counter per product.

---

## Stage 6 — Bon de Livraison (BL) / Delivery Note

**Module:** *(not yet built — Logistics or Sales)*  
**Tables:** TBD  
**Status:** 📋 Planned

### Description
The **Bon de Livraison (BL)** accompanies the physical delivery of goods or attestation of service completion. It is signed by the client upon receipt and is **proof of delivery** — it triggers the right to invoice.

### Document Fields
| Field | Description |
|---|---|
| `N° BL` | Unique reference: `BL-YYYY-NNNN` |
| `Date de livraison` | Actual delivery date |
| `Réf. BC Client` | Client's PO reference |
| `Réf. Commande Interne` | Internal Sales Order reference |
| Delivery address | Client site address |
| Items delivered | Description, Qty ordered, Qty delivered, Unit |
| Remaining to deliver | If partial delivery |
| Signature Client | Client representative name, signature, stamp, date |
| Signature Livreur | Delivery agent / technician signature |

### Notes
- A **partial BL** is issued when goods are delivered in multiple shipments
- A signed BL is **mandatory before issuing a final invoice**
- In EPC/engineering projects, replaced/supplemented by a **PV de Réception**

### Statuses
`Prepared → Dispatched → Delivered & Signed → Partially Accepted → Disputed`

---

## Stage 7 — Procès-Verbal de Réception (PV)

**Module:** Projects (Phase 5)  
**Tables:** TBD  
**Status:** 📋 Planned (Phase 5 scope)

> **Applicable for engineering, EPC, and service contracts**

### Description
A **PV de Réception** formally records the acceptance of delivered works, equipment, or services. In this ERP it will live under the Projects module, linked back to the originating deal and invoice.

### Types
| Type | Description |
|---|---|
| **PV de Réception Provisoire** | Provisional acceptance — punch list may remain |
| **PV de Réception Définitive** | Final acceptance after defect liability period |
| **PV de Levée de Réserves** | Punch list closed — all snags resolved |

### Document Fields
- Project name and reference
- Contract / BC reference
- Date of inspection
- List of items inspected (Accepted / Reserve / Rejected)
- Punch list with responsible party and deadline
- Signatures: Client, Contractor, Independent Engineer (if applicable)

---

## Stage 8 — Facture (Invoice)

**Module:** Finance › Invoices *(stub — schema done)*  
**Tables:** `invoices`, `invoice_lines`  
**Status:** 📋 Planned — schema + RLS in place; module is a stub. Reuses the Tunisian tax model and PDF section builders from `quote_pdf.dart`.

> **Prerequisite:** Resolve the `client_id` FK bug (see ⚠️ at top) before building this module.

### Document Header
| Field | Description |
|---|---|
| `N° Facture` | Sequential reference: `FAC-YYYY-NNNN` |
| `Date de facturation` | Invoice issue date |
| `Date d'échéance` | Payment due date |
| `Réf. Devis` | Quote reference |
| `Réf. BC Client` | Client PO reference |
| `Réf. BL / PV` | Delivery note or reception PV reference |
| Seller info | From `organizations` table (name, address, MF, RIB, IBAN) |
| Client info | From `client_snapshot` JSONB (name, address, MF) |

### Document Body
| Field | Description |
|---|---|
| Line items | Same hierarchy as quotes (level 0/1/2), from `invoice_lines` |
| Remise | Discount if any |
| Sous-total HT | Subtotal before tax |
| FODEC (1%) | Toggle per document |
| TVA (19% / 13% / 7% / 0%) | Recap by rate |
| Timbre Fiscal | Fixed: 1.000 TND |
| Retenue à la Source | Deducted at source if client is a registered entity |
| **Total TTC** | Final amount payable |
| Acompte déjà versé | Advance already paid (if any) |
| **Solde à Payer** | Net amount due |

### Invoice Types
| Type | Description |
|---|---|
| **Facture Définitive** | Standard invoice for delivered goods or services |
| **Facture d'Acompte** | Advance / deposit invoice (before delivery) |
| **Facture Intermédiaire** | Progress billing invoice (milestone-based) |
| **Facture de Solde** | Final invoice closing the contract |
| **Avoir / Note de Crédit** | Credit note to correct or cancel a prior invoice |
| **Facture Proforma** | Non-binding pre-invoice; not a payment request |

### Three-Way Matching (before issuing or approving)
Enforced server-side (edge function or DB trigger):
1. **Invoice ↔ Devis/BC** — Prices and quantities match
2. **Invoice ↔ BL/PV** — Delivered quantities match invoiced quantities
3. **Invoice ↔ Budget/PO** — Within authorized spend

### Statuses
`Draft → Validated → Sent → Acknowledged → Partially Paid → Paid → Overdue → Disputed`

---

## Stage 9 — Recouvrement / Paiement (Payment & Collection)

**Module:** Finance › Payments *(stub — schema done)*  
**Tables:** `payments`  
**Status:** 📋 Planned — table + RLS in place; module is a stub.

### Documents
| Document | Description |
|---|---|
| **Relevé de Compte** | Account statement showing outstanding invoices |
| **Rappel / Relance** | Payment reminder (1st, 2nd, 3rd notice) |
| **Quittance / Reçu** | Receipt issued upon payment confirmation |
| **Avis de Virement** | Bank transfer confirmation (from client) |
| **Bordereau de Remise** | Bank deposit slip (for cheque payments) |

### Payment Methods Tracked
- Virement bancaire (bank transfer)
- Chèque
- Effet de commerce (lettre de change / traite)
- Espèces (cash — limited by regulation)

### Reconciliation
- Match incoming payment to open invoice(s)
- Record partial payments
- Update invoice status to `Partially Paid` or `Paid`
- Generate Quittance if required

---

## Stage 10 — Projet (Project Kick-Off)

**Module:** Projects (Phase 5)  
**Tables:** `projects`, `tasks`, `project_templates`  
**Status:** 📋 Planned (Phase 5) — tables + RLS done; stub module.

### Description
Once a contract is confirmed (signed BC + received acompte or full payment), the ERP triggers the creation of a **Project** cloned from a `project_template`. The transition is implemented server-side (edge function / DB trigger) so it can't be bypassed from the client.

### Project Record Links
- Parent Deal / Opportunity
- Signed Devis / Contract reference
- Client BC reference
- Received acompte Facture
- Assigned team members
- Milestone schedule (for EPC)
- Document log

---

## Full Document Reference Map

```
[Contact / Company]  ← CRM (done)
  └─► [Deal / Opportunity]  ← Sales › Pipeline (done)
        └─► [Devis / Quote]  ← Sales › Quotes (done; product picker pending 4a)
              │
              ├─► [BC Client (reçu)]  ← planned
              │
              ├─► [ARC — Accusé de Réception de Commande]  ← planned
              │
              ├─► [Bon de Préparation]  ← Inventory (4a)
              │    └─► stock decrement on products
              │
              ├─► [Bon de Livraison (BL)]  ← planned
              │    ou [PV de Réception]  ← Projects (Phase 5)
              │
              ├─► [Facture d'Acompte]  ← Finance › Invoices (planned)
              │
              ├─► [Factures Intermédiaires]  ← Finance › Invoices (planned)
              │
              └─► [Facture de Solde / Définitive]  ← Finance › Invoices (planned)
                    │
                    ├─► [Relevé de Compte / Relances si impayé]
                    │
                    ├─► [Paiement + Quittance]  ← Finance › Payments (planned)
                    │
                    └─► [Projet]  ← Projects (Phase 5; cloned from template on payment)
```

---

## Document Numbering Convention

| Document | Prefix | Example |
|---|---|---|
| Devis / Quote | `DEV-` | `DEV-2026-042` |
| Devis Révision | `DEV-…-R1` | `DEV-2026-042-R1` |
| Bon de Commande Client | `BC-` | `BC-2026-019` |
| Accusé de Réception de Commande | `ARC-` | `ARC-2026-019` |
| Bon de Préparation | `BPR-` | `BPR-2026-088` |
| Bon de Livraison | `BL-` | `BL-2026-089` |
| PV de Réception | `PVR-` | `PVR-2026-007` |
| Facture | `FAC-` | `FAC-2026-156` |
| Avoir / Note de Crédit | `AVO-` | `AVO-2026-012` |
| Facture Proforma | `PRO-` | `PRO-2026-003` |
| Reçu / Quittance | `REC-` | `REC-2026-156` |

---

## Key Business Rules

| Rule | Description |
|---|---|
| **Traceability** | Every document must reference its parent (Devis → BC → BL → Facture) |
| **No invoice without delivery** | Facture finale must reference a signed BL or PV |
| **Three-way match** | Invoice qty/price must match BC and BL — enforced server-side |
| **Quote immutability** | Accepted quotes are frozen; changes require a revision (R1, R2…) |
| **Partial deliveries** | Multiple BLs can map to one BC; invoicing tracks delivered qty only |
| **Credit notes** | Any correction to a posted invoice requires an Avoir, not an edit |
| **Tax compliance** | FODEC, TVA by rate, Timbre Fiscal, Retenue à la Source per Tunisian rules |
| **Audit trail** | Every status change logged with user, timestamp, and comment (`audit_log` table) |
| **Server-side transitions** | Quote → Invoice, Payment → Project: edge functions / DB triggers only — not client |
| **Tenant isolation** | Every table carries `org_id`; RLS policies keyed to JWT `org_id` claim |
| **Money** | `numeric` or integer cents — never floats |

---

## Roles & Responsibilities

| Stage | Document | Responsible |
|---|---|---|
| Lead → Opportunity | Contact / Deal record | Sales / CRM |
| Opportunity → Quote | Devis | Sales + Technical |
| Quote → Order | BC / ARC | Sales / Admin |
| Order → Delivery | BL / Bon de Préparation | Logistics / Operations |
| Delivery → Acceptance | PV de Réception | PM / IE / Client |
| Acceptance → Billing | Facture | Finance / Billing |
| Billing → Collection | Paiement / Quittance | Finance / Treasury |
| Contract → Execution | Projet (cloned from template) | Project Manager |

---

## Phase Sequencing (Current)

```
Phase 4a — Inventory (products + suppliers + stock counter)
  └─► Phase 4b — Product Bundles (bundle builder + quote insertion)
        └─► Phase 4 — Business Pipeline (BC, BL, Invoice, Payment, Project)
              └─► Phase 5 — Projects & Tasks (PV, full project management)
```

---

*Document version: 2.0 — Updated 2026-06-29 for this Flutter/Supabase ERP*
