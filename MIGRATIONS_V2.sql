-- =============================================================
-- IJWI MIGRATIONS V2 — Run in Supabase SQL Editor
-- Safe to re-run. DROP POLICY IF EXISTS before CREATE POLICY
-- because PostgreSQL does not support CREATE POLICY IF NOT EXISTS.
-- =============================================================

-- ── 1. Missing columns on posts ──────────────────────────────
ALTER TABLE posts ADD COLUMN IF NOT EXISTS video_url    text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS youtube_url  text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url    text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS prayer_count int NOT NULL DEFAULT 0;

-- ── 2. Prayer chains ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS prayer_chains (
  post_id    uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_prayer_chains_user ON prayer_chains(user_id);

ALTER TABLE prayer_chains ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "prayer_chains_select_public"       ON prayer_chains;
DROP POLICY IF EXISTS "prayer_chains_insert_authenticated" ON prayer_chains;
DROP POLICY IF EXISTS "prayer_chains_delete_own"           ON prayer_chains;

CREATE POLICY "prayer_chains_select_public"
  ON prayer_chains FOR SELECT USING (true);

CREATE POLICY "prayer_chains_insert_authenticated"
  ON prayer_chains FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "prayer_chains_delete_own"
  ON prayer_chains FOR DELETE
  USING (auth.uid() = user_id);

-- ── 3. Blessings (Bless this Voice micro-donations) ──────────
CREATE TABLE IF NOT EXISTS blessings (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id        uuid REFERENCES profiles(id) ON DELETE SET NULL,
  to_user_id          uuid REFERENCES profiles(id) ON DELETE SET NULL,
  post_id             uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  amount_rwf          int  NOT NULL,
  creator_amount_rwf  int  NOT NULL,
  platform_amount_rwf int  NOT NULL,
  phone               text NOT NULL,
  ref                 text UNIQUE,
  paypack_ref         text,
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'completed', 'failed')),
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_blessings_to_user   ON blessings(to_user_id);
CREATE INDEX IF NOT EXISTS idx_blessings_from_user ON blessings(from_user_id);
CREATE INDEX IF NOT EXISTS idx_blessings_status    ON blessings(status);

ALTER TABLE blessings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blessings_select_own" ON blessings;

CREATE POLICY "blessings_select_own"
  ON blessings FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

-- ── 4. Referrals ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referrals (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_code    text NOT NULL,
  referred_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  pro_granted      boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (referred_user_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_code ON referrals(referrer_code);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referrals_select_own"           ON referrals;
DROP POLICY IF EXISTS "referrals_insert_authenticated" ON referrals;

CREATE POLICY "referrals_select_own"
  ON referrals FOR SELECT
  USING (
    auth.uid() = referred_user_id
    OR auth.uid()::text LIKE referrer_code || '%'
  );

CREATE POLICY "referrals_insert_authenticated"
  ON referrals FOR INSERT
  WITH CHECK (auth.uid() = referred_user_id);

-- ── 5. Profile: ensure streak column exists ───────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS streak int NOT NULL DEFAULT 0;

-- ── 6. Supabase Realtime ─────────────────────────────────────
-- If the line below errors with "already member", that's fine — ignore it.
ALTER PUBLICATION supabase_realtime ADD TABLE posts;
