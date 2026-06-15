-- =============================================================
-- IJWI MIGRATIONS V4 — Run in Supabase SQL Editor
-- CRITICAL: posts SELECT policy — without this the feed shows empty
-- =============================================================

-- ── 1. Posts RLS policies (CRITICAL — feed shows empty without these) ──
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "posts_select"                ON public.posts;
DROP POLICY IF EXISTS "posts_insert_authenticated"  ON public.posts;
DROP POLICY IF EXISTS "posts_update_own"            ON public.posts;
DROP POLICY IF EXISTS "posts_delete_own"            ON public.posts;

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

-- ── 2. Missing post columns ────────────────────────────────────
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS reaction_fire    INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS reaction_amen    INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS reaction_healed  INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS reaction_needed  INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS reaction_sharing INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS comment_count    INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS prayer_count     INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS tags             TEXT[]            DEFAULT '{}';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS video_url        TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS youtube_url      TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url        TEXT;

-- ── 3. Profiles RLS (ensure SELECT is public) ─────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);

-- ── 4. Notifications table ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id   uuid        REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       text        NOT NULL,
  post_id    uuid        REFERENCES public.posts(id) ON DELETE CASCADE,
  read       boolean     NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, read) WHERE read = false;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;

CREATE POLICY "notifications_select"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "notifications_update"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);
