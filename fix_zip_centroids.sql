-- Fix zip_centroids INSERT with correct column names

-- 1. First check the actual table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'zip_centroids' 
ORDER BY ordinal_position;

-- 2. Check existing data format
SELECT * FROM zip_centroids LIMIT 3;

-- 3. Insert ZIP codes with all required columns
-- Based on the error, we need to include primary_city
INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude) 
VALUES ('00851', 'Bayamon', 'PR', 18.3833, -66.1500)
ON CONFLICT (zip) DO NOTHING;

-- 4. Add common test ZIP codes with proper column names
INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude) VALUES
('90210', 'Beverly Hills', 'CA', 34.0901, -118.4065),
('10001', 'New York', 'NY', 40.7505, -73.9934),
('60601', 'Chicago', 'IL', 41.8781, -87.6298)
ON CONFLICT (zip) DO NOTHING;

-- 5. Fix the listings table zip column
ALTER TABLE public.listings 
ALTER COLUMN zip TYPE VARCHAR(10);

-- 6. Force schema cache refresh
NOTIFY pgrst, 'reload schema';

-- 7. Verify the ZIP codes were added
SELECT zip, primary_city, state FROM zip_centroids WHERE zip IN ('00851', '90210', '10001');
