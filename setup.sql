-- setup.sql
-- Run this in Supabase SQL Editor to provision the visit counter

-- 1. Create table
CREATE TABLE IF NOT EXISTS visits (
  id integer PRIMARY KEY DEFAULT 1,
  count integer NOT NULL DEFAULT 0,
  bots integer NOT NULL DEFAULT 0,
  CONSTRAINT single_row CHECK (id = 1)
);

-- 2. Insert initial row
INSERT INTO visits (id, count, bots) VALUES (1, 0, 0)
ON CONFLICT (id) DO NOTHING;

-- 3. Create atomic increment function
CREATE OR REPLACE FUNCTION increment_visits(is_bot boolean DEFAULT false)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result record;
BEGIN
  IF is_bot THEN
    UPDATE visits SET count = count + 1, bots = bots + 1 WHERE id = 1
    RETURNING count, bots INTO result;
  ELSE
    UPDATE visits SET count = count + 1 WHERE id = 1
    RETURNING count, bots INTO result;
  END IF;

  RETURN json_build_object('count', result.count, 'bots', result.bots);
END;
$$;

-- 4. Create correction function for behavioral bot detection
CREATE OR REPLACE FUNCTION increment_bots_only()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE visits SET bots = bots + 1 WHERE id = 1;
END;
$$;

-- 5. Lock down direct table access, allow only RPC
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

-- Deny all direct access (anon role)
CREATE POLICY "No direct access" ON visits
  FOR ALL TO anon
  USING (false);

-- 6. Grant execute on the functions to anon
GRANT EXECUTE ON FUNCTION increment_visits(boolean) TO anon;
GRANT EXECUTE ON FUNCTION increment_bots_only() TO anon;
