-- Check for triggers and constraints that might be causing ZIP validation

-- 1. Check for triggers on listings table
SELECT trigger_name, event_manipulation, action_statement 
FROM information_schema.triggers 
WHERE event_object_table = 'listings';

-- 2. Check for RLS policies on listings table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'listings';

-- 3. Check for functions that might be called by triggers
SELECT routine_name, routine_definition
FROM information_schema.routines 
WHERE routine_name LIKE '%listing%' OR routine_name LIKE '%zip%';

-- 4. Try to insert a simple listing without ZIP to test
-- This will help us see what's really happening
SELECT 'Testing basic insert...' as status;
