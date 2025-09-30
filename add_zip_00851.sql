-- Add ZIP code 00851 to zip_centroids table
-- Based on your database structure: zip, state, geom, latitude, longitude, city

INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude, city, geom) 
VALUES ('00851', 'Bayamon', 'PR', 18.3833, -66.1500, 'Bayamon', ST_Point(-66.1500, 18.3833))
ON CONFLICT (zip) DO NOTHING;

-- Add a few more common ZIP codes for testing
INSERT INTO zip_centroids (zip, primary_city, state, latitude, longitude, city, geom) VALUES
('90210', 'Beverly Hills', 'CA', 34.0901, -118.4065, 'Beverly Hills', ST_Point(-118.4065, 34.0901)),
('10001', 'New York', 'NY', 40.7505, -73.9934, 'New York', ST_Point(-73.9934, 40.7505)),
('60601', 'Chicago', 'IL', 41.8781, -87.6298, 'Chicago', ST_Point(-87.6298, 41.8781))
ON CONFLICT (zip) DO NOTHING;

-- Verify the ZIP codes were added
SELECT zip, state, city, latitude, longitude FROM zip_centroids WHERE zip IN ('00851', '90210', '10001');
