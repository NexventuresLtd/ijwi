-- V22: Event ticket tiers, payments, and collaborators
-- Run in Supabase SQL Editor

-- Ticket tiers
CREATE TABLE IF NOT EXISTS public.ticket_tiers (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  description text,
  price numeric(10,2) NOT NULL DEFAULT 0,
  currency text DEFAULT 'RWF',
  capacity integer NOT NULL DEFAULT 100,
  sold_count integer DEFAULT 0,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.ticket_tiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tiers_select" ON public.ticket_tiers FOR SELECT USING (true);
CREATE POLICY "tiers_insert" ON public.ticket_tiers FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);
CREATE POLICY "tiers_update" ON public.ticket_tiers FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);
CREATE POLICY "tiers_delete" ON public.ticket_tiers FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);

-- Event payments / bookings
CREATE TABLE IF NOT EXISTS public.event_bookings (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  tier_id uuid REFERENCES public.ticket_tiers(id) ON DELETE SET NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount numeric(10,2) NOT NULL DEFAULT 0,
  currency text DEFAULT 'RWF',
  payment_status text DEFAULT 'pending' CHECK (payment_status IN ('pending','completed','failed','refunded')),
  payment_ref text,
  ticket_code text UNIQUE,
  checked_in boolean DEFAULT false,
  checked_in_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.event_bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bookings_select" ON public.event_bookings FOR SELECT USING (
  auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);
CREATE POLICY "bookings_insert" ON public.event_bookings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "bookings_update" ON public.event_bookings FOR UPDATE USING (
  auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);

-- Event collaborators
CREATE TABLE IF NOT EXISTS public.event_collaborators (
  event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  role text DEFAULT 'collaborator' CHECK (role IN ('collaborator','co_host')),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);

ALTER TABLE public.event_collaborators ENABLE ROW LEVEL SECURITY;
CREATE POLICY "collabs_select" ON public.event_collaborators FOR SELECT USING (true);
CREATE POLICY "collabs_insert" ON public.event_collaborators FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);
CREATE POLICY "collabs_delete" ON public.event_collaborators FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.events WHERE id = event_id AND organizer_id = auth.uid())
);

-- Add promotion columns to events
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_promoted boolean DEFAULT false;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS promotion_expires_at timestamptz;
