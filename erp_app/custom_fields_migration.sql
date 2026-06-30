-- ─────────────────────────────────────────────────────────────────────────────
-- Custom fields migration
-- Run this in your Supabase SQL editor (or via the CLI).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Field-definition catalogue ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS custom_field_definitions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  entity_type TEXT        NOT NULL CHECK (entity_type IN ('contact', 'company')),
  label       TEXT        NOT NULL,
  field_key   TEXT        NOT NULL,  -- snake_case, e.g. "annual_revenue"
  field_type  TEXT        NOT NULL CHECK (field_type IN ('text', 'number', 'select', 'boolean')),
  options     TEXT[]      NOT NULL DEFAULT '{}',  -- only used for field_type = 'select'
  is_unique   BOOLEAN     NOT NULL DEFAULT false,
  sort_order  INT         NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Two definitions in the same org/entity cannot share the same field_key.
  UNIQUE (org_id, entity_type, field_key)
);

CREATE INDEX IF NOT EXISTS idx_custom_field_defs_org
  ON custom_field_definitions (org_id, entity_type, sort_order);

-- 2. Add custom_fields JSONB column to contacts and companies ──────────────────
ALTER TABLE contacts  ADD COLUMN IF NOT EXISTS custom_fields JSONB NOT NULL DEFAULT '{}';
ALTER TABLE companies ADD COLUMN IF NOT EXISTS custom_fields JSONB NOT NULL DEFAULT '{}';

-- 3. Row-Level Security ────────────────────────────────────────────────────────
ALTER TABLE custom_field_definitions ENABLE ROW LEVEL SECURITY;

-- Members of the org can read and manage their own field definitions.
DROP POLICY IF EXISTS "org members can select field defs" ON custom_field_definitions;
CREATE POLICY "org members can select field defs"
  ON custom_field_definitions FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "org members can insert field defs" ON custom_field_definitions;
CREATE POLICY "org members can insert field defs"
  ON custom_field_definitions FOR INSERT
  WITH CHECK (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "org members can delete field defs" ON custom_field_definitions;
CREATE POLICY "org members can delete field defs"
  ON custom_field_definitions FOR DELETE
  USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

-- 4. (Optional) Uniqueness function ───────────────────────────────────────────
-- This DB-level function mirrors the Flutter-side uniqueness check so you can
-- enforce it server-side in a trigger if desired (not wired up by default).
--
-- CREATE OR REPLACE FUNCTION check_custom_field_unique()
-- RETURNS TRIGGER LANGUAGE plpgsql AS $$
-- DECLARE
--   def RECORD;
--   field_val TEXT;
--   existing_count INT;
-- BEGIN
--   FOR def IN
--     SELECT field_key FROM custom_field_definitions
--     WHERE org_id = NEW.org_id
--       AND entity_type = TG_ARGV[0]
--       AND is_unique = true
--   LOOP
--     field_val := NEW.custom_fields ->> def.field_key;
--     IF field_val IS NOT NULL THEN
--       SELECT COUNT(*) INTO existing_count
--       FROM contacts -- (swap table per trigger)
--       WHERE org_id = NEW.org_id
--         AND id != NEW.id
--         AND custom_fields ->> def.field_key = field_val;
--       IF existing_count > 0 THEN
--         RAISE EXCEPTION 'Custom field "%" must be unique.', def.field_key;
--       END IF;
--     END IF;
--   END LOOP;
--   RETURN NEW;
-- END;
-- $$;
