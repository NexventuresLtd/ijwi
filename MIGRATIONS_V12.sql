-- V12: Add message column to notifications + read_at

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS message text;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at timestamptz;
