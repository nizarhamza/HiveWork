# Phase 2 — Auth, Access Control & Onboarding

> Goal: people can sign in, belong to an org, and see only what their role allows — entering through a guided setup.

## Authentication
- [x] Sign-up and sign-in
- [x] Magic link / OAuth provider
- [x] Password reset
- [x] Secure session/token storage across web, Windows, mobile
- [x] Auth-state routing (redirect guards in go_router)

## Multi-tenant membership
- [x] Create-organization flow
- [ ] Invite teammates by email
- [ ] Accept-invite / join org
- [x] Org switcher wired into the workspace switcher

## RBAC enforcement
- [ ] `permissions` provider (current user's permissions)
- [ ] Filter modules by `requiredPermission` in the registry
- [ ] Hide / disable nav items and actions by permission
- [ ] Verify client checks align with server-side RLS

## Onboarding wizard (the "facile" entry)
- [ ] Step: create workspace
- [ ] Step: invite team
- [ ] Step: choose enabled modules
- [ ] Step: seed sample data
- [ ] Plain-language copy; skippable and resumable

**Definition of done:** a new user goes from sign-up to a populated workspace unaided, seeing only permitted modules.
