-- Fix ZIP column length in listings table
-- The current zip column is too short (character(2)) for 5-digit ZIP codes

-- First, check current column definition
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'listings' AND column_name = 'zip';

-- Alter the zip column to allow 5-digit ZIP codes
ALTER TABLE public.listings 
ALTER COLUMN zip TYPE VARCHAR(10);

-- Also check and fix zip_code column in profiles table if needed
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'zip_code';

-- Fix profiles zip_code column if it's also too short
ALTER TABLE public.profiles 
ALTER COLUMN zip_code TYPE VARCHAR(10);

-- Verify the changes
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE (table_name = 'listings' AND column_name = 'zip') 
   OR (table_name = 'profiles' AND column_name = 'zip_code');
