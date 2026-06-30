-- ─────────────────────────────────────────────────────────────────────────────
-- Atomic, collision-free quote number generation (S-4, D-6).
--
-- Uses an INSERT … ON CONFLICT … DO UPDATE (atomic upsert) to increment a
-- per-org, per-month counter in a single statement — no race condition.
-- A UNIQUE constraint on (org_id, number) catches any remaining edge cases.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Counter table ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS document_counters (
  org_id     UUID  NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  month_key  TEXT  NOT NULL,   -- 'YYYYMM', resets naturally per month
  last_seq   INT   NOT NULL DEFAULT 0,
  PRIMARY KEY (org_id, month_key)
);

ALTER TABLE document_counters ENABLE ROW LEVEL SECURITY;

-- Members may read counters (for display purposes only); writes go through the
-- SECURITY DEFINER function below so no INSERT/UPDATE policy is needed.
DROP POLICY IF EXISTS "org members can read counters" ON document_counters;
CREATE POLICY "org members can read counters"
  ON document_counters FOR SELECT
  USING (
    org_id IN (SELECT org_id FROM org_members WHERE user_id = auth.uid())
  );

-- 2. Generator function ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_quote_number(p_org_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER   -- bypasses RLS to atomically update the counter row
SET search_path = public
AS $$
DECLARE
  v_month TEXT := to_char(now() AT TIME ZONE 'UTC', 'YYYYMM');
  v_seq   INT;
BEGIN
  INSERT INTO document_counters (org_id, month_key, last_seq)
  VALUES (p_org_id, v_month, 1)
  ON CONFLICT (org_id, month_key) DO UPDATE
    SET last_seq = document_counters.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'D-' || v_month || '-' || lpad(v_seq::TEXT, 4, '0');
END;
$$;

-- 3. DB-level uniqueness guard (idempotent via DO block) ──────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'quotes_org_number_unique'
      AND conrelid = 'quotes'::regclass
  ) THEN
    ALTER TABLE quotes ADD CONSTRAINT quotes_org_number_unique UNIQUE (org_id, number);
  END IF;
END;
$$;
