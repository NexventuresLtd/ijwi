-- V29: Add reactions column to direct_messages

ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS reactions jsonb DEFAULT '{}'::jsonb;
