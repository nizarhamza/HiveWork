# Phase 8 — Quality, Testing & Observability

> Goal: confidence that changes are safe and the app behaves in production.

## Testing
- [ ] Unit tests (logic + repositories)
- [ ] Widget tests (components)
- [ ] Integration tests (key flows: onboarding, pipeline)
- [ ] Golden tests (design system)
- [ ] RLS / security tests (carried from Phase 1)

## CI
- [ ] `flutter analyze` on every PR
- [ ] Run tests on every PR
- [ ] Per-platform build jobs (web / Windows / mobile)

## Observability
- [ ] Error tracking (e.g. Sentry)
- [ ] Structured logging
- [ ] Privacy-aware analytics

## Performance
- [ ] Profile startup + heavy screens
- [ ] `const` correctness pass
- [ ] List virtualization where needed
- [ ] Image / asset caching

**Definition of done:** green CI, coverage on critical paths, and a met performance budget.
