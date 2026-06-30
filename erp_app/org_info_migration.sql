-- ─────────────────────────────────────────────────────────────────────────────
-- Org Info migration
-- Adds optional columns to the `organizations` table used by Settings → Org Info.
-- Run once in the Supabase SQL editor (or via the CLI).
-- All columns are nullable — existing rows are unaffected.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS timezone TEXT,
  ADD COLUMN IF NOT EXISTS country  TEXT,
  ADD COLUMN IF NOT EXISTS phone    TEXT,
  ADD COLUMN IF NOT EXISTS email    TEXT,
  ADD COLUMN IF NOT EXISTS website  TEXT,
  ADD COLUMN IF NOT EXISTS tax_id   TEXT;

-- ── Comments ──────────────────────────────────────────────────────────────────
COMMENT ON COLUMN organizations.timezone IS 'IANA timezone identifier, e.g. Europe/Paris';
COMMENT ON COLUMN organizations.country  IS 'Country name or ISO 3166-1 alpha-2 code';
COMMENT ON COLUMN organizations.phone    IS 'Primary contact phone, E.164 format preferred';
COMMENT ON COLUMN organizations.email    IS 'Reply-to email printed on invoices';
COMMENT ON COLUMN organizations.website  IS 'Public website URL';
COMMENT ON COLUMN organizations.tax_id   IS 'VAT / Tax ID printed on legal invoice section';
