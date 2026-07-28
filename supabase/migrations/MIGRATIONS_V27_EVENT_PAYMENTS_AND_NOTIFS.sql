-- =============================================================
-- IJWI MIGRATIONS V27 — Run in Supabase SQL Editor
-- =============================================================

-- Add payment receiving number to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS payment_receiving_number text;

-- Enable realtime for notifications and direct_messages
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'direct_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE direct_messages;
  END IF;
END $$;
