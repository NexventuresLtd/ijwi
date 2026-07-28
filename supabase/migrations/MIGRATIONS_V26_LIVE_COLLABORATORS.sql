-- =============================================================
-- IJWI MIGRATIONS V26 — Run in Supabase SQL Editor
-- Adds: allow_requests to livestreams, livestream_requests table,
--       and action_type/action_payload to direct_messages
-- =============================================================

-- 1. Add allow_requests to livestreams
ALTER TABLE public.livestreams
  ADD COLUMN IF NOT EXISTS allow_requests boolean DEFAULT true;

-- 2. Create livestream_requests table
CREATE TABLE IF NOT EXISTS public.livestream_requests (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  stream_id uuid REFERENCES public.livestreams(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(stream_id, user_id)
);

ALTER TABLE public.livestream_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "requests_select" ON public.livestream_requests 
  FOR SELECT USING (true);

CREATE POLICY "requests_insert" ON public.livestream_requests 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "requests_update" ON public.livestream_requests 
  FOR UPDATE USING (
    -- Allow host to accept/reject
    EXISTS (SELECT 1 FROM public.livestreams WHERE id = stream_id AND host_id = auth.uid())
    -- Allow user to cancel request
    OR auth.uid() = user_id
  );

-- 3. Add action fields to direct_messages
ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS action_type text,
  ADD COLUMN IF NOT EXISTS action_payload jsonb;

-- 4. Enable Realtime for livestream_requests if not already
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'livestream_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE livestream_requests;
  END IF;
END $$;
