-- V23: Livestream tables
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.livestreams (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  host_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  description text,
  stream_type text DEFAULT 'audio' CHECK (stream_type IN ('audio','video')),
  status text DEFAULT 'scheduled' CHECK (status IN ('scheduled','live','ended','cancelled')),
  viewer_count integer DEFAULT 0,
  peak_viewers integer DEFAULT 0,
  recording_url text,
  thumbnail_url text,
  scheduled_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.livestreams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "streams_select" ON public.livestreams FOR SELECT USING (true);
CREATE POLICY "streams_insert" ON public.livestreams FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "streams_update" ON public.livestreams FOR UPDATE USING (auth.uid() = host_id);

CREATE TABLE IF NOT EXISTS public.livestream_participants (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  stream_id uuid REFERENCES public.livestreams(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role text DEFAULT 'viewer' CHECK (role IN ('host','co_host','guest','viewer')),
  is_muted boolean DEFAULT false,
  joined_at timestamptz DEFAULT now(),
  left_at timestamptz
);

ALTER TABLE public.livestream_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "participants_select" ON public.livestream_participants FOR SELECT USING (true);
CREATE POLICY "participants_insert" ON public.livestream_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "participants_update" ON public.livestream_participants FOR UPDATE USING (
  auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.livestreams WHERE id = stream_id AND host_id = auth.uid())
);

CREATE TABLE IF NOT EXISTS public.livestream_reactions (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  stream_id uuid REFERENCES public.livestreams(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  reaction_type text NOT NULL CHECK (reaction_type IN ('fire','amen','heart','clap','pray')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.livestream_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stream_reactions_select" ON public.livestream_reactions FOR SELECT USING (true);
CREATE POLICY "stream_reactions_insert" ON public.livestream_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_livestreams_host ON public.livestreams(host_id);
CREATE INDEX IF NOT EXISTS idx_livestreams_status ON public.livestreams(status);
CREATE INDEX IF NOT EXISTS idx_stream_participants ON public.livestream_participants(stream_id);
