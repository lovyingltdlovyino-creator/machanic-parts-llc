-- Fix zip_centroids INSERT with geometry column

-- 1. Check the table structure first
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'zip_centroids' 
ORDER BY ordinal_position;

-- 2. Insert ZIP codes with geometry calculated from lat/lng
-- Using ST_Point to create geometry from latitude/longitude
INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude, geom) 
VALUES ('00851', 'Bayamon', 'PR', 18.3833, -66.1500, ST_Point(-66.1500, 18.3833))
ON CONFLICT (zip) DO NOTHING;

-- 3. Add common test ZIP codes with geometry
INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude, geom) VALUES
('90210', 'Beverly Hills', 'CA', 34.0901, -118.4065, ST_Point(-118.4065, 34.0901)),
('10001', 'New York', 'NY', 40.7505, -73.9934, ST_Point(-73.9934, 40.7505)),
('60601', 'Chicago', 'IL', 41.8781, -87.6298, ST_Point(-87.6298, 41.8781))
ON CONFLICT (zip) DO NOTHING;

-- 4. Alternative: If ST_Point doesn't work, try this format
-- INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude, geom) 
-- VALUES ('00851', 'Bayamon', 'PR', 18.3833, -66.1500, ST_GeomFromText('POINT(-66.1500 18.3833)', 4326))
-- ON CONFLICT (zip) DO NOTHING;

-- 5. Fix the listings table zip column
ALTER TABLE public.listings 
ALTER COLUMN zip TYPE VARCHAR(10);

-- 6. Force schema cache refresh
NOTIFY pgrst, 'reload schema';

-- 7. Verify the ZIP codes were added
SELECT zip, primary_city, state, latitude, longitude FROM zip_centroids WHERE zip IN ('00851', '90210', '10001');
