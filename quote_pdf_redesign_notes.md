# Quote PDF — Redesign Notes
> File: `erp_app/lib/modules/sales/quote_pdf.dart`
> Based on: printed output of D-202606-0001

---

## Bugs to fix first (before visual polish)

### 1. `Ø` rendering in Unit and Remise columns
The Unit cell and Remise cell both show `Ø` (a Unicode null/empty glyph) instead of nothing. Somewhere a null or empty string is being formatted through a path that produces that character. Fix: if the value is null/empty/zero, render `—` or leave the cell blank.

### 2. "Remis e" — Remise column header wraps
The "Remise" header is wrapping mid-word to "Remis / e" because the column is too narrow. Either widen the Remise column slightly or reduce font size to `labelSmall` and allow it to auto-shrink.

### 3. `Ø` below "Conditions de paiement"
When no payment term is selected, the value renders as `Ø`. Guard with: if null/empty, either hide the whole payment-conditions block or show `—`.

### 4. Client block is bare
Below the logo/org header, only the raw client name "test" is printed in bold — no address, no MF (matricule fiscal), no phone. The client snapshot (`clientSnapshotAddress`, `clientSnapshotPhone`, `clientSnapshotTaxId`) is being collected but not rendered. Build a proper client address block.

### 5. Org details missing from header
The right-side header shows only the company name. The org's address, phone, email, MF (tax_id), RC, RNE and bank details should appear beneath the company name in the header — this is legally required on a Tunisian devis.

### 6. "Objet" line not printed
The `objet` field is stored on the quote but not visible anywhere in the PDF output. It should appear between the client block and the line-items table, styled as a short summary line.

---

## Layout & structure changes

### Header (top section)
**Current:** logo box (left) | company name in a gray band (right) — disconnected, no org details.

**Target layout:**
```
┌──────────────────────┬───────────────────────────────────┐
│  [LOGO or ORG NAME]  │  ORG NAME  (large, bold)          │
│  (left, ~35% width)  │  Address · City · Country         │
│                      │  Tél: xxx  |  Email: xxx           │
│                      │  MF: xxx   |  RC: xxx              │
└──────────────────────┴───────────────────────────────────┘
```
- Remove the heavy gray background band on the right; use clean text instead.
- If no logo: show the org name large in the left box instead of italic placeholder text.
- Add a thin full-width rule below the header.

### Client + document meta block
**Current:** client name floating left, "DEVIS" huge italic right, dates scattered.

**Target layout (two-column, beneath header rule):**
```
LEFT (client block):               RIGHT (document meta):
  DESTINATAIRE                       DEVIS
  Client Name (bold)                 N° D-202606-0001
  Address line 1                     Date : 23/06/2026
  City / Country                     Validité : 23/07/2026
  MF : xxxxxxx
  Tél : xxxxxxx
```
- "DEVIS" title: keep large but switch from huge italic to a clean **bold sans-serif**, slightly smaller (e.g. 28pt not 40pt).
- "DESTINATAIRE" section label: small caps, muted, same style as other section labels in the doc.
- Objet line: add a row below this block — `Objet : [objet text]` in italic, spanning full width before the table.

### Line-items table
- **Column widths**: widen Remise column enough so "Remise" fits on one line.
- **Column order** (current is fine): N° | Désignation | Unité | Qté | Prix U. HT | Remise | TVA | Total HT
- **Header row**: keep the navy/slate background, but use slightly lighter shade so it feels less heavy.
- **Row alternation**: add very subtle alternating row tint (e.g. `#F7F8FA` every other row) — makes it much easier to read.
- **N° column**: left-align, remove italic. Use regular weight.
- **Numeric columns** (Qté, Prix, Remise, TVA, Total): right-align consistently. Currently TVA column shows the rate as a bare number — add `%` suffix.
- **Empty cells**: if Remise is 0 or null, show `—` not a glyph.
- **Category/parent rows** (when using hierarchy): bold the designation, span it visually, hide numeric columns.

### TVA recap table
- Current placement and style is acceptable.
- Add an outer border to the recap table — without it, it floats loosely.
- The "19%" rate in blue is a nice accent; keep it.

### Totals block (bottom-right)
**Current:** left side has "Conditions de paiement" + broken value; right side has totals. The two sides feel unbalanced.

**Suggested layout:**
- Left column: conditions de paiement block (only if a value exists), plus bank details (bank name, RIB/IBAN) as an info box.
- Right column: totals stack (Total HT → FODEC → TVA recap → Timbre → **Total TTC** bold).
- Separate Total TTC from the subtotals with a thicker rule.
- Use a subtle highlight (light background) on the Total TTC row.

**Conditions de paiement**: wrap in a small labeled box (like the signature boxes). If null → hide the whole block, don't show a broken character.

### Montant en lettres
- The blue left-border accent is good — keep it.
- Change label `ARRÊTÉE LA PRÉSENTE À LA SOMME DE` to a lighter muted style (all-caps, 7pt) and the amount text to normal 9pt italic. Current is fine but the label is the same visual weight as the amount which makes it hard to scan.

### Signature boxes
- Currently both boxes are plain rectangles with labels. Fine functionally.
- Make the boxes taller (currently very short — about 40pt; target ~70pt).
- Add a subtle inner background tint (`#F9F9FB`) to distinguish from page background.
- Right box: "BON POUR ACCORD ✦ CACHET & SIGNATURE DU CLIENT" — the `✦` (or whatever separator is rendering wrong) should just be a space or `|`.

### Footer
- Current: company name left, doc number + page right. Clean — keep as-is.
- Consider adding the org's MF/RC to the footer as a second line for legal completeness.

---

## Typography

| Element | Current | Target |
|---|---|---|
| "DEVIS" title | Huge italic (≈40pt) | Bold, 28pt, no italic |
| Company name (header) | Regular bold | Bold, 14pt |
| Section labels (RÉCAPITULATIF…) | All-caps muted | ✓ Keep — matches the design |
| Table header | White bold on navy | ✓ Keep |
| Table data | Italic | Regular weight; italic only for category rows |
| Total TTC | Regular | Bold, slightly larger (11pt) |

---

## Color palette (keep consistent)

| Usage | Color |
|---|---|
| Table header background | `#3D4B6B` (current navy-slate) |
| Accent / TVA rate | `#3D4B6B` or `#5E6AD2` (Linear accent) |
| Alternating row tint | `#F7F8FA` |
| Total TTC highlight | `#EEF0F8` |
| Section label text | `#9CA3AF` (muted gray) |
| Border lines | `#E2E4E9` |
| Amount-in-words left border | Keep current blue accent |

---

## Priority order for implementation

1. **Fix `Ø` rendering** (bugs #1, #2, #3) — single-pass null-guard pass through all cell formatters
2. **Add org details to header** (bug #5) — legally required
3. **Add client address/MF block** (bug #4) — legally required
4. **Print the Objet field** (bug #6) — easy, just add one row
5. **Fix "Remise" column width** (layout)
6. **Widen signature boxes** and add inner tint
7. **Row alternation** in line-items table
8. **Total TTC highlight row**
9. **Conditions de paiement** — hide if null, add bank details alongside
10. **DEVIS title** — reduce size, remove italic
