-- V14: Set admin role for d.niyonshut078@gmail.com
-- Run in Supabase SQL Editor

UPDATE profiles
SET is_admin = true
WHERE id = (
  SELECT id FROM auth.users WHERE email = 'd.niyonshut078@gmail.com'
);
