-- =====================================================
-- SUPABASE DATABASE SETUP FOR PROPER RELATIONSHIPS
-- =====================================================

-- 1. First, let's ensure the foreign key relationship exists
-- Add foreign key constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'listings_owner_id_fkey' 
        AND table_name = 'listings'
    ) THEN
        ALTER TABLE listings 
        ADD CONSTRAINT listings_owner_id_fkey 
        FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 2. Enable Row Level Security on profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies for profiles table
-- Allow everyone to read profiles (for public listings)
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
CREATE POLICY "Public profiles are viewable by everyone" 
ON profiles FOR SELECT 
USING (true);

-- Allow users to update their own profiles
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

-- Allow users to insert their own profiles
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" 
ON profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

-- 4. Ensure listings table has proper RLS policies
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Allow everyone to read active listings
DROP POLICY IF EXISTS "Public listings are viewable by everyone" ON listings;
CREATE POLICY "Public listings are viewable by everyone" 
ON listings FOR SELECT 
USING (status = 'active');

-- Allow users to manage their own listings
DROP POLICY IF EXISTS "Users can manage own listings" ON listings;
CREATE POLICY "Users can manage own listings" 
ON listings FOR ALL 
USING (auth.uid() = owner_id);

-- 5. Grant necessary permissions
GRANT SELECT ON profiles TO anon, authenticated;
GRANT SELECT ON listings TO anon, authenticated;
GRANT ALL ON listings TO authenticated;
GRANT ALL ON profiles TO authenticated;

-- 6. Create a view for listings with seller info (alternative approach)
DROP VIEW IF EXISTS listings_with_seller;
CREATE VIEW listings_with_seller AS
SELECT 
    l.*,
    p.city as seller_city,
    p.state as seller_state,
    p.business_name as seller_business_name,
    p.contact_person as seller_contact_person,
    p.rating as seller_rating
FROM listings l
LEFT JOIN profiles p ON l.owner_id = p.id;

-- Grant access to the view
GRANT SELECT ON listings_with_seller TO anon, authenticated;

-- =====================================================
-- VERIFICATION QUERIES (run these to check setup)
-- =====================================================

-- Check if foreign key exists
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
    AND tc.table_name = 'listings'
    AND kcu.column_name = 'owner_id';

-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('listings', 'profiles');

-- Test the view
SELECT id, title, seller_city, seller_state, seller_business_name 
FROM listings_with_seller 
LIMIT 5;
