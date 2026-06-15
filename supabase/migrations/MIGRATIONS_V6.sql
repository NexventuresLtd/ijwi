-- =============================================================
-- IJWI MIGRATIONS V6 — Run in Supabase SQL Editor after V5
-- Adds: audio_url for Spoken Word voice posts
-- =============================================================

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS audio_url text;

-- Also ensure the 'voices' storage bucket exists with the right policies.
-- Go to Supabase → Storage → New bucket → name "voices" → Public → Save
-- Then add policies:
--   INSERT: authenticated role, check: (bucket_id = 'voices')
--   SELECT: public role, check: true
