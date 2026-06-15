-- =============================================================
-- IJWI MIGRATIONS V7 — Run in Supabase SQL Editor
-- CRITICAL: Ensures status column exists, all posts are visible,
-- and body NOT NULL is relaxed for media posts.
-- Safe to re-run multiple times.
-- =============================================================

-- ── 1. Add status column (safe if already exists) ────────────
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS status text DEFAULT 'published';

-- ── 2. Backfill: every post without a status becomes published ─
UPDATE public.posts SET status = 'published' WHERE status IS NULL OR status = '';

-- ── 3. Relax body NOT NULL so image/video posts can have no text
ALTER TABLE public.posts ALTER COLUMN body SET DEFAULT '';
-- (NOT NULL constraint on body stays — empty string is valid)

-- ── 4. Ensure all media columns exist ────────────────────────
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS video_url       text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS youtube_url     text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url       text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS audio_url       text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS video_thumbnail text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS stream_url      text;

-- ── 5. Re-assert RLS policies (posts) ────────────────────────
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "posts_select"               ON public.posts;
DROP POLICY IF EXISTS "posts_insert_authenticated" ON public.posts;
DROP POLICY IF EXISTS "posts_update_own"           ON public.posts;
DROP POLICY IF EXISTS "posts_delete_own"           ON public.posts;

CREATE POLICY "posts_select"
  ON public.posts FOR SELECT USING (true);

CREATE POLICY "posts_insert_authenticated"
  ON public.posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "posts_update_own"
  ON public.posts FOR UPDATE
  USING (auth.uid() = author_id);

CREATE POLICY "posts_delete_own"
  ON public.posts FOR DELETE
  USING (auth.uid() = author_id);

-- ── 6. Re-assert profiles RLS ─────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select"            ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"        ON public.profiles;

CREATE POLICY "profiles_select"
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- ── 7. Verification: show post count by status ───────────────
-- After running, you should see rows with status='published'.
-- If count is 0, your posts were never saved.
SELECT status, COUNT(*) FROM public.posts GROUP BY status;
