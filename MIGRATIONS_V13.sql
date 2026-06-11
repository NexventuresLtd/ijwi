-- V13: Essay support - subtitle, music_url, cover_color on posts

ALTER TABLE posts ADD COLUMN IF NOT EXISTS subtitle text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS music_url text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS cover_color text;
