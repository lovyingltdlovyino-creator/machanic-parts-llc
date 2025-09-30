-- Quick fix for ZIP validation and listing creation issues

-- 1. First, check what's in the zip_centroids table
SELECT COUNT(*) as total_zips FROM zip_centroids;
SELECT * FROM zip_centroids WHERE zip LIKE '00%' LIMIT 5;

-- 2. Check if 00851 exists in zip_centroids
SELECT * FROM zip_centroids WHERE zip = '00851';

-- 3. Add the missing ZIP code to zip_centroids table
-- 00851 is Bayamón, Puerto Rico
INSERT INTO zip_centroids (zip, latitude, longitude, city, state) 
VALUES ('00851', 18.3833, -66.1500, 'Bayamon', 'PR')
ON CONFLICT (zip) DO NOTHING;

-- 4. Also add some common test ZIP codes
INSERT INTO zip_centroids (zip, latitude, longitude, city, state) VALUES
('90210', 34.0901, -118.4065, 'Beverly Hills', 'CA'),
('10001', 40.7505, -73.9934, 'New York', 'NY'),
('60601', 41.8781, -87.6298, 'Chicago', 'IL')
ON CONFLICT (zip) DO NOTHING;

-- 5. Fix the listings table zip column to handle full ZIP codes
ALTER TABLE public.listings 
ALTER COLUMN zip TYPE VARCHAR(10);

-- 6. Force schema cache refresh
NOTIFY pgrst, 'reload schema';

-- 7. Verify the changes
SELECT zip, city, state FROM zip_centroids WHERE zip IN ('00851', '90210', '10001');
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'listings' AND column_name = 'zip';

-- Quick fix for missing columns in profiles table
-- Run this in your Supabase SQL Editor

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS contact_person TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS zip_code TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_description TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS years_in_business INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS specialties TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_type TEXT DEFAULT 'individual';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 5.0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
