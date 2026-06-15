-- V16: Add deleted flag to direct_messages

ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false;
