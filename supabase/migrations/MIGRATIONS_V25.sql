-- =============================================================
-- IJWI MIGRATIONS V25 — Run in Supabase SQL Editor
-- Adds reply_to_id to direct_messages
-- =============================================================

ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS reply_to_id uuid REFERENCES public.direct_messages(id) ON DELETE SET NULL;
