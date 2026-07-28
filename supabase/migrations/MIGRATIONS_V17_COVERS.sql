-- V17: Create covers storage bucket for event cover images
-- Run in Supabase SQL Editor

INSERT INTO storage.buckets (id, name, public)
VALUES ('covers', 'covers', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload cover images
CREATE POLICY "Authenticated users can upload covers"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'covers');

-- Allow public read of covers
CREATE POLICY "Public can view covers"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'covers');
