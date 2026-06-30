# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Multi-tenant ERP — Nizar's solo project. Single Flutter codebase targeting **web (primary) → Windows → mobile**, Supabase backend. Design-first, modular, inspired by Linear's UI language.

**Current state (2026-06-18):** design system tokens + shell done, CRM Contacts list done with in-memory data, Sales/Invoicing/Projects are stubs. No backend, auth, or RLS yet.

**Immediate next:** Phase 3 three-pane record-detail view, then Phase 1 Supabase schema + RLS.

---

## Repository layout

This workspace is a **planning + template repository**, not the Flutter project root. The runnable app lives elsewhere; code here is the canonical source of truth for templates and task tracking.

| Path | Contents |
|------|----------|
| `Templates/` | Dart source files — copy into the Flutter project's `lib/` |
| `Tasks (MD)/phase-NN-*.md` | Per-phase checklists |
| `ROADMAP.md` | Full 0→10 phase plan with "done looks like" criteria |
| `TASKS.md` | Active / waiting / done task board |
| `memory/` | Persistent context for Claude (do not edit manually) |

### Flutter project file conventions

Template files map to these paths inside `lib/`:

```
Templates/app_shell.dart         →  lib/shell/app_shell.dart
Templates/modules.dart           →  lib/core/module/modules.dart
Templates/stub_modules.dart      →  lib/modules/stubs/stub_modules.dart
Templates/contacts_page.dart     →  lib/modules/crm/contacts_page.dart
Templates/linear_sidebar_item.dart → lib/shell/widgets/linear_sidebar_item.dart
Templates/linear_view_header.dart  → lib/shell/widgets/linear_view_header.dart
```

---

## Flutter commands

```bash
flutter run -d chrome          # web (primary target)
flutter run -d windows         # Windows desktop
flutter analyze                # static analysis (zero warnings policy)
flutter test                   # unit + widget tests
flutter test test/path/foo_test.dart   # single test file
flutter build web --release    # production web build
```

---

## Architecture

### Module system

Every feature is an `AppModule`. Adding a module = one new file + one line in `kAppModules`:

```dart
// lib/core/module/modules.dart
const List<AppModule> kAppModules = [
  CrmModule(),
  SalesModule(),   // add new modules here
];
```

`AppModule` contract (implement all fields):

| Field | Purpose |
|-------|---------|
| `id` | Unique string key |
| `title` / `icon` | Sidebar display |
| `basePath` | Root route, redirects to first nav item |
| `navItems` | Sub-pages shown nested in sidebar when active |
| `routes` | `go_router` `RouteBase` list — registered automatically |
| `requiredPermission` | RBAC gate (null = always visible) |

Stub modules live in `stub_modules.dart` — replace `ComingSoon` pages with real ones as each phase lands.

### Shell & routing

- `AppShell` wraps every routed page (sidebar + content). Sidebar collapses to a `Drawer` below `kExpandedBreakpoint = 820` dp.
- Router: `go_router`. Each module provides its own `routes`; the shell aggregates them via `ModuleRegistry`.
- Active module detection: `registry.moduleForLocation(path)` — used to expand the correct nav group.

### Design system (Linear tokens)

All sizing, color, and spacing comes from `lib/theme/linear_tokens.dart`. **Never hardcode color/size/spacing.**

Key constants:

| Token class | Examples |
|-------------|---------|
| `LinearColors` | `pageBg`, `surfaceBase`, `accent`, `textPrimary/Secondary/Muted`, `borderSubtle`, `overlay/overlayActive`, `success/warning` |
| `LinearSpacing` | `xxs/xs/sm/base/md/lg/xl` |
| `LinearRadii` | `xs/sm/md/pill` |
| `LinearTokens` (via `context.linearTokens`) | `sidebarWidth`, `headerHeight`, `rowHeightDefault`, `iconSizeMd` |

Access the `LinearTokens` instance: `final lt = context.linearTokens;`

### State management

Riverpod. Every provider exposes explicit loading/error states (no bare `.value` assumptions). Module registry: `moduleRegistryProvider`.

### Reusable shell widgets

- `LinearSidebarItem` — sidebar row with optional indent, icon, trailing widget, selected state.
- `LinearViewHeader` — thin top toolbar (icon + title + actions). Every module page starts with this.
- `LinearGhostButton` — muted action button used in view headers (Filter, Display, etc.).
- `ComingSoon` — placeholder page for unbuilt module views.

### Tenancy & data

- Every Supabase table carries `org_id`; RLS policies are keyed to the JWT `org_id` claim.
- Money: `numeric` or integer cents — **never floats**.
- Domain tables: `organizations`, `memberships`, `contacts`, `companies`, `deals`, `quotes`, `quote_lines`, `invoices`, `payments`, `projects`, `project_templates`, `tasks`.

---

## Principles

- **Design-first** — reuse existing components before creating new ones. Check `LinearViewHeader`, `LinearSidebarItem`, `LinearGhostButton` before reaching for custom widgets.
- **Facile** — wizards and templates over blank forms; guided empty states; command palette (Cmd/Ctrl-K, Phase 0).
- **Tenant safety** — RLS from the first table; never trust the client alone; cross-org read attempts must fail in tests.
- **i18n-ready** — use `EdgeInsetsDirectional` (not left/right) so Arabic RTL works when Phase 6 lands.
