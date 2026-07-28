-- V24: Collaborators and Amplified Events
-- Run in Supabase SQL Editor

-- 1. Add is_amplified to events
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_amplified boolean DEFAULT false;

-- 2. Add is_live to events to support manual live stream toggling for Live Prayers
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_live boolean DEFAULT false;

-- 3. Create event_collaborators table
CREATE TABLE IF NOT EXISTS public.event_collaborators (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  role text CHECK (role IN ('admin', 'usher')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(event_id, user_id)
);

ALTER TABLE public.event_collaborators ENABLE ROW LEVEL SECURITY;

CREATE POLICY "collaborators_select" ON public.event_collaborators 
  FOR SELECT USING (true);

CREATE POLICY "collaborators_insert" ON public.event_collaborators 
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id AND organizer_id = auth.uid()
    )
  );

CREATE POLICY "collaborators_delete" ON public.event_collaborators 
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id AND organizer_id = auth.uid()
    ) OR user_id = auth.uid()
  );

-- Update RLS on events so admins can update
CREATE POLICY "admin updates events" ON public.events
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_collaborators
      WHERE event_id = events.id
      AND user_id = auth.uid()
      AND role = 'admin'
    )
  );

-- Update RLS on event_tickets so ushers/admins can scan
CREATE POLICY "collaborators read tickets" ON public.event_tickets
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_collaborators
      WHERE event_id = event_tickets.event_id
      AND user_id = auth.uid()
      AND role IN ('admin', 'usher')
    )
  );

CREATE POLICY "collaborators update tickets" ON public.event_tickets
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_collaborators
      WHERE event_id = event_tickets.event_id
      AND user_id = auth.uid()
      AND role IN ('admin', 'usher')
    )
  );
