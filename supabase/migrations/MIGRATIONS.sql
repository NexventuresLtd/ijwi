-- ============================================================
-- Ijwi Database Migrations
-- Run these in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. Admin & ban flags on profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_banned boolean DEFAULT false;

-- Make yourself admin (replace with your actual user ID from Supabase Auth):
-- UPDATE profiles SET is_admin = true WHERE id = 'YOUR_USER_ID_HERE';

-- 2. Reports table
CREATE TABLE IF NOT EXISTS reports (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reason text NOT NULL DEFAULT 'inappropriate',
  notes text,
  reviewed boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- 3. Push notification subscriptions
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint text NOT NULL,
  p256dh text NOT NULL,
  auth text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, endpoint)
);

-- 4. Story views (for "who viewed my story")
CREATE TABLE IF NOT EXISTS story_views (
  story_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at timestamptz DEFAULT now(),
  PRIMARY KEY (story_id, viewer_id)
);

-- 5. Media columns on posts (if not already added)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS video_url text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS youtube_url text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url text;

-- 6. Full-text search index
ALTER TABLE posts ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || body)
  ) STORED;

CREATE INDEX IF NOT EXISTS posts_search_idx ON posts USING gin(search_vector);

-- Also index voice_name for user search
CREATE INDEX IF NOT EXISTS profiles_voice_name_idx ON profiles USING gin(to_tsvector('english', voice_name));

-- 7. Pro subscription columns on profiles (if not already there)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_pro boolean DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pro_expires_at timestamptz;

-- 8. Payments table (Mobile Money / MoMo)
CREATE TABLE IF NOT EXISTS payments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  phone text NOT NULL,
  amount integer NOT NULL DEFAULT 2000,
  currency text DEFAULT 'RWF',
  ref text UNIQUE,
  status text DEFAULT 'pending',  -- pending | successful | failed
  created_at timestamptz DEFAULT now()
);

-- 9. RLS policies for new tables
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can insert reports"
  ON reports FOR INSERT TO authenticated WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Admins can read reports"
  ON reports FOR SELECT TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = true);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own push subscriptions"
  ON push_subscriptions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can insert own payments"
  ON payments FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can read own payments"
  ON payments FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Admins can read all payments"
  ON payments FOR SELECT TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = true);
CREATE POLICY "Admins can update payments"
  ON payments FOR UPDATE TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = true);

ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can upsert story views"
  ON story_views FOR INSERT TO authenticated WITH CHECK (auth.uid() = viewer_id);
CREATE POLICY "Post authors can read their story views"
  ON story_views FOR SELECT TO authenticated
  USING (auth.uid() = viewer_id OR
         (SELECT author_id FROM posts WHERE id = story_id) = auth.uid());
