-- Debug ZIP column issue
-- Check current column definitions and constraints

-- 1. Check listings table structure
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'listings' 
  AND column_name = 'zip';

-- 2. Check if there are any constraints on the zip column
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
LEFT JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public' 
  AND tc.table_name = 'listings' 
  AND ccu.column_name = 'zip';

-- 3. Force schema cache refresh
NOTIFY pgrst, 'reload schema';

-- 4. Try the column alteration again with explicit schema
ALTER TABLE public.listings 
ALTER COLUMN zip TYPE TEXT;

-- 5. Verify the change took effect
SELECT 
    column_name, 
    data_type, 
    character_maximum_length
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'listings' 
  AND column_name = 'zip';
