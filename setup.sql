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
AS $$
DECLARE
  result json;
BEGIN
  IF is_bot THEN
    UPDATE visits SET count = count + 1, bots = bots + 1 WHERE id = 1;
  ELSE
    UPDATE visits SET count = count + 1 WHERE id = 1;
  END IF;

  SELECT json_build_object('count', v.count, 'bots', v.bots)
  INTO result
  FROM visits v WHERE v.id = 1;

  RETURN result;
END;
$$;

-- 4. Lock down direct table access, allow only RPC
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

-- Deny all direct access (anon role)
CREATE POLICY "No direct access" ON visits
  FOR ALL TO anon
  USING (false);

-- 5. Grant execute on the function to anon
GRANT EXECUTE ON FUNCTION increment_visits(boolean) TO anon;
