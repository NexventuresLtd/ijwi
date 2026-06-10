-- =============================================================
-- IJWI MIGRATIONS V3 — Run in Supabase SQL Editor after V2
-- =============================================================

-- ── Live Streams ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS live_streams (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title       text NOT NULL,
  stream_url  text,
  status      text NOT NULL DEFAULT 'live'
              CHECK (status IN ('live', 'ended')),
  viewer_count int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  ended_at    timestamptz
);

CREATE INDEX IF NOT EXISTS idx_live_streams_host   ON live_streams(host_id);
CREATE INDEX IF NOT EXISTS idx_live_streams_status ON live_streams(status);

ALTER TABLE live_streams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "live_streams_select_public"       ON live_streams;
DROP POLICY IF EXISTS "live_streams_insert_authenticated" ON live_streams;
DROP POLICY IF EXISTS "live_streams_update_own"           ON live_streams;

CREATE POLICY "live_streams_select_public"
  ON live_streams FOR SELECT USING (true);

CREATE POLICY "live_streams_insert_authenticated"
  ON live_streams FOR INSERT
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "live_streams_update_own"
  ON live_streams FOR UPDATE
  USING (auth.uid() = host_id);

-- Enable realtime for live streams (safe to re-run)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'live_streams'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE live_streams;
  END IF;
END $$;
