-- ─────────────────────────────────────────────────────────────────────────────
-- Fix: custom_field_definitions RLS policies referenced the wrong table.
-- The app queries `org_members`; old policies used `memberships` which does
-- not exist, so all three policies silently blocked or allowed incorrectly.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "org members can select field defs"  ON custom_field_definitions;
DROP POLICY IF EXISTS "org members can insert field defs"  ON custom_field_definitions;
DROP POLICY IF EXISTS "org members can delete field defs"  ON custom_field_definitions;

CREATE POLICY "org members can select field defs"
  ON custom_field_definitions FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "org members can insert field defs"
  ON custom_field_definitions FOR INSERT
  WITH CHECK (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "org members can delete field defs"
  ON custom_field_definitions FOR DELETE
  USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );
