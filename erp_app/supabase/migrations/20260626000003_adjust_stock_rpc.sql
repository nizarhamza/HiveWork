-- ─────────────────────────────────────────────────────────────────────────────
-- Delta-based stock adjustment RPC (D-2).
--
-- Uses stock_quantity + p_delta so concurrent adjustments compose correctly,
-- unlike the previous last-write-wins SET stock_quantity = newAbsoluteValue.
-- Clamps to [0, 999999] and validates org ownership in the same statement.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION adjust_product_stock(
  p_product_id UUID,
  p_org_id     UUID,
  p_delta      INT
)
RETURNS SETOF products
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE products
  SET stock_quantity = GREATEST(0, LEAST(stock_quantity + p_delta, 999999))
  WHERE id = p_product_id
    AND org_id = p_org_id
  RETURNING *;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found or access denied (id=%, org=%)',
      p_product_id, p_org_id;
  END IF;
END;
$$;
