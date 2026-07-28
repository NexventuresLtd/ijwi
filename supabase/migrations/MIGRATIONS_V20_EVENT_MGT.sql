-- MIGRATIONS_V20_EVENT_MGT.sql
-- Adds attended tracking and moments gallery to events

-- Add moments to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS moments_urls text[] DEFAULT '{}';

-- Add attended to event_tickets
ALTER TABLE event_tickets ADD COLUMN IF NOT EXISTS attended boolean NOT NULL DEFAULT false;

-- Add updated_at if not exists
ALTER TABLE event_tickets ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_event_tickets_modtime()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_event_tickets_modtime ON event_tickets;
CREATE TRIGGER update_event_tickets_modtime
    BEFORE UPDATE ON event_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_event_tickets_modtime();

-- RLS: Organizers can update tickets for their events
CREATE POLICY "organizer updates event tickets" ON event_tickets
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_tickets.event_id
      AND events.organizer_id = auth.uid()
    )
  );

-- Also allow organizers to read all tickets for their events
CREATE POLICY "organizer reads event tickets" ON event_tickets
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_tickets.event_id
      AND events.organizer_id = auth.uid()
    )
  );
