-- ─────────────────────────────────────────────────────────────────────────────
-- Payment Terms migration
-- Adds payment_terms_options and default_quote_notes to the organizations table.
-- Run once in the Supabase SQL editor (or via the CLI).
-- All columns are nullable / have defaults — existing rows are unaffected.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS payment_terms_options TEXT[]  DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS default_quote_notes   TEXT;

COMMENT ON COLUMN organizations.payment_terms_options IS
  'Predefined payment-mode options shown in the quote/invoice dropdown (e.g. Virement bancaire, Chèque)';

COMMENT ON COLUMN organizations.default_quote_notes IS
  'Default note pre-filled on every new quote (e.g. ownership clause, warranty text)';
