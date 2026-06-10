# Pending Database Migrations

Run these in Supabase SQL Editor (Dashboard → SQL Editor).
Paste **only the SQL blocks** — not the headings.

---

## 1. Voice Role column

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS voice_role text DEFAULT 'voice'
  CHECK (voice_role IN ('voice','storyteller','prayer_warrior','worship_leader','encourager','community_builder','content_creator','helper'));
```

---

## 2. Notification preference columns

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notify_follows  boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_reactions boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_comments  boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_prayers   boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_blessings boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_dms       boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_echoes    boolean DEFAULT true;
```

---

## 3. Verified badge column

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false;
```

---

## 4. Audio URL on posts (for essay background music)

```sql
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS audio_url text;
```

---

## 5. Events table

```sql
CREATE TABLE IF NOT EXISTS events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text NOT NULL,
  location        text,
  event_date      timestamptz NOT NULL,
  ends_at         timestamptz,
  ticket_price    numeric,
  ticket_currency text DEFAULT 'RWF',
  max_attendees   integer,
  cover_image_url text,
  is_free         boolean NOT NULL DEFAULT true,
  is_virtual      boolean NOT NULL DEFAULT false,
  stream_url      text,
  tags            text[] DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public read events" ON events
  FOR SELECT USING (true);

CREATE POLICY "authenticated create events" ON events
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = organizer_id);

CREATE POLICY "organizer update events" ON events
  FOR UPDATE TO authenticated
  USING (auth.uid() = organizer_id);

CREATE POLICY "organizer delete events" ON events
  FOR DELETE TO authenticated
  USING (auth.uid() = organizer_id);
```

---

## 6. Event tickets table

```sql
CREATE TABLE IF NOT EXISTS event_tickets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status      text NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','paid','failed','refunded')),
  amount      numeric NOT NULL DEFAULT 0,
  currency    text NOT NULL DEFAULT 'RWF',
  paypack_ref text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, user_id)
);

-- RLS
ALTER TABLE event_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user reads own tickets" ON event_tickets
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "authenticated insert tickets" ON event_tickets
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "authenticated update own tickets" ON event_tickets
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Service role can update ticket status (for webhook)
CREATE POLICY "service update tickets" ON event_tickets
  FOR UPDATE USING (true);
```

---

## 7. Storage bucket RLS policies

Run each block separately for each bucket (`images`, `voices`, `shorts`):

```sql
-- images bucket upload + read
CREATE POLICY "authenticated upload images" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'images');
CREATE POLICY "public read images" ON storage.objects
  FOR SELECT USING (bucket_id = 'images');

-- voices bucket upload + read
CREATE POLICY "authenticated upload voices" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'voices');
CREATE POLICY "public read voices" ON storage.objects
  FOR SELECT USING (bucket_id = 'voices');

-- shorts bucket upload + read
CREATE POLICY "authenticated upload shorts" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'shorts');
CREATE POLICY "public read shorts" ON storage.objects
  FOR SELECT USING (bucket_id = 'shorts');
```

If policies already exist, you'll get an "already exists" error — that's fine, skip those.

---

## Notes

- Run migrations 1–6 in order — each is idempotent (`IF NOT EXISTS`).
- Migration 5 and 6 create the Events system. Run them together.
- `voice_role` replaces the old XP/level badge in the UI (columns stay in DB for now).
- `is_verified` defaults to false — set it manually in Supabase for verified voices.
- `audio_url` on posts stores background music for essays uploaded via `/write`.
- For the event ticket webhook, add `/api/events/webhook` as the Paypack webhook URL in the Paypack dashboard.
