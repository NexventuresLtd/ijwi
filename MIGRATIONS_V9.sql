-- Live room messages (in-app live chat for events without external stream URL)
CREATE TABLE IF NOT EXISTS public.live_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_live_messages_event ON public.live_messages(event_id, created_at);

-- RLS
ALTER TABLE public.live_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone can read live messages"
  ON public.live_messages FOR SELECT USING (true);

CREATE POLICY "authenticated users can send live messages"
  ON public.live_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Enable realtime for live messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.live_messages;
