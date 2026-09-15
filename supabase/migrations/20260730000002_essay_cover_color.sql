-- Add cover_color to essays table
ALTER TABLE essays ADD COLUMN IF NOT EXISTS cover_color TEXT;
