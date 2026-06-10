-- =============================================================
-- IJWI MIGRATIONS V5 — Run in Supabase SQL Editor after V4
-- Adds: is_answerer, is_dm_listed roles + direct_messages table
-- =============================================================

-- ── Profile role columns ──────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_answerer  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_dm_listed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS dm_title     text,
  ADD COLUMN IF NOT EXISTS dm_bio       text;

-- ── Direct messages ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS direct_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message     text NOT NULL
              CHECK (char_length(message) > 0 AND char_length(message) <= 2000),
  created_at  timestamptz NOT NULL DEFAULT now(),
  read_at     timestamptz
);

CREATE INDEX IF NOT EXISTS idx_dm_sender   ON direct_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_dm_receiver ON direct_messages(receiver_id);

ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dm_select_participants" ON direct_messages;
DROP POLICY IF EXISTS "dm_insert_authenticated" ON direct_messages;
DROP POLICY IF EXISTS "dm_mark_read"            ON direct_messages;

CREATE POLICY "dm_select_participants"
  ON direct_messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "dm_insert_authenticated"
  ON direct_messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "dm_mark_read"
  ON direct_messages FOR UPDATE
  USING (auth.uid() = receiver_id);

-- Enable realtime for DMs (safe to re-run)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'direct_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE direct_messages;
  END IF;
END $$;
