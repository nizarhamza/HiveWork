# Phase 9 — Security & Compliance Hardening

> Goal: production-grade safety before exposing real customer data.

## Secrets & keys
- [ ] Confirm no secrets / keys ship in the client bundle
- [ ] Centralize secret management

## Backend
- [ ] Full RLS policy review
- [ ] Input validation on all writes
- [ ] Rate-limiting on edge functions

## Data
- [ ] Audit-log review + retention policy
- [ ] Backups + a restore drill
- [ ] GDPR-style data export / deletion

**Definition of done:** a security review passes, restore is tested, and no secrets live in the client.
