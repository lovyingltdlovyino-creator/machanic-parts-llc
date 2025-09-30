-- =====================================================
-- DATABASE DIAGNOSTIC SCRIPT
-- Run this first to check current state
-- =====================================================

-- 1. Check if tables exist
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('listings', 'profiles')
ORDER BY table_name;

-- 2. Check listings table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'listings' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check profiles table structure  
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check existing foreign keys
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name IN ('listings', 'profiles');

-- 5. Check if owner_id column exists in listings
SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'listings' 
    AND column_name = 'owner_id'
    AND table_schema = 'public'
) as owner_id_exists;

-- 6. Check if id column exists in profiles
SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' 
    AND column_name = 'id'
    AND table_schema = 'public'
) as profiles_id_exists;

-- 7. Sample data check
SELECT 'listings' as table_name, count(*) as row_count FROM listings
UNION ALL
SELECT 'profiles' as table_name, count(*) as row_count FROM profiles;
