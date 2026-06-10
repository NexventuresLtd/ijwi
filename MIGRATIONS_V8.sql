-- =============================================================
-- IJWI MIGRATIONS V8 — Run in Supabase SQL Editor
-- Adds: is_pinned flag on posts so owners can pin one post to top
-- =============================================================

ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_posts_pinned ON public.posts(author_id, is_pinned) WHERE is_pinned = true;
