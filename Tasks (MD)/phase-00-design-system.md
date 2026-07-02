# Phase 0 — Design-System Completeness

> Goal: a component library deep enough that every later screen is assembly, not invention.

## Core components
- [x] Button variants: filled, ghost, outline, danger (+ icon button, loading state)
- [x] Dropdown / select and combobox (typeahead)
- [x] Checkbox, radio, switch
- [ ] Segmented control
- [x] Text field, search field, multiline field
- [x] Inline-editable field (click-to-edit)
- [x] Form primitives (field row, label, helper/error text)

## Display elements
- [x] Status & priority pills
- [x] Labels / tags (with color)
- [x] Avatars: single + stacked group
- [x] Badges / counts

## Overlays & feedback
- [x] Modal dialog
- [x] Right-hand side panel (the properties surface)
- [ ] Context menu, popover, tooltip
- [x] Toast / snackbar system
- [ ] Confirmation pattern for destructive actions
- [x] Skeleton loaders
- [x] Guided empty states

## Interaction systems
- [x] Command palette (Cmd/Ctrl-K) with an action registry
- [ ] Keyboard-shortcut registry
- [ ] Focus management / traversal order

## Foundations
- [x] Confirm responsive breakpoints (desktop three-pane ↔ mobile drawer)
- [ ] Accessibility: Semantics labels, focus order, contrast, text scaling, 44dp targets
- [x] Verify tokens stay theme-swappable (light theme feasible later)
- [x] Build a component gallery page rendering every widget in all states

**Definition of done:** a gallery page shows every component in default / hover / active / disabled states.
