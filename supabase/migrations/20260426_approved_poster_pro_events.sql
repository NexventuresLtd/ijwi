-- Add is_approved_poster to profiles (default false — all existing users are readers)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_approved_poster boolean DEFAULT false;

-- Add is_verified and is_dm_listed if not already present (they may exist already)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_dm_listed boolean DEFAULT false;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_answerer boolean DEFAULT false;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS subscription_status text DEFAULT 'inactive';

-- Add early_access to events table
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS early_access boolean DEFAULT false;

-- RLS: Only approved posters can INSERT posts
-- (Drop first in case it was created before with a different definition)
DROP POLICY IF EXISTS "only approved posters can create posts" ON public.posts;
CREATE POLICY "only approved posters can create posts"
  ON public.posts FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND is_approved_poster = true
    )
  );
