# Phase 0 — Design-System Completeness

> Goal: a component library deep enough that every later screen is assembly, not invention.

## Core components
- [ ] Button variants: filled, ghost, outline, danger (+ icon button, loading state)
- [ ] Dropdown / select and combobox (typeahead)
- [ ] Checkbox, radio, switch, segmented control
- [ ] Text field, search field, multiline field
- [ ] Inline-editable field (click-to-edit)
- [ ] Form primitives (field row, label, helper/error text)

## Display elements
- [ ] Status & priority pills
- [ ] Labels / tags (with color)
- [ ] Avatars: single + stacked group
- [ ] Badges / counts

## Overlays & feedback
- [ ] Modal dialog
- [ ] Right-hand side panel (the properties surface)
- [ ] Context menu, popover, tooltip
- [ ] Toast / snackbar system
- [ ] Confirmation pattern for destructive actions
- [ ] Skeleton loaders
- [ ] Guided empty states

## Interaction systems
- [ ] Command palette (Cmd/Ctrl-K) with an action registry
- [ ] Keyboard-shortcut registry
- [ ] Focus management / traversal order

## Foundations
- [ ] Confirm responsive breakpoints (desktop three-pane ↔ mobile drawer)
- [ ] Accessibility: Semantics labels, focus order, contrast, text scaling, 44dp targets
- [ ] Verify tokens stay theme-swappable (light theme feasible later)
- [ ] Build a component gallery page rendering every widget in all states

**Definition of done:** a gallery page shows every component in default / hover / active / disabled states.
