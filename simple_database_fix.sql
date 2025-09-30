-- =====================================================
-- SIMPLE DATABASE FIX - Run this after diagnostic
-- =====================================================

-- 1. Ensure profiles table exists with correct structure
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    business_name TEXT,
    contact_person TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    business_description TEXT,
    years_in_business INTEGER,
    specialties TEXT,
    business_type TEXT,
    rating NUMERIC DEFAULT 5.0,
    profile_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Ensure listings table has owner_id column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' 
        AND column_name = 'owner_id'
    ) THEN
        ALTER TABLE listings ADD COLUMN owner_id UUID;
    END IF;
END $$;

-- 3. Drop existing foreign key if it exists (to recreate it properly)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'listings_owner_id_fkey' 
        AND table_name = 'listings'
    ) THEN
        ALTER TABLE listings DROP CONSTRAINT listings_owner_id_fkey;
    END IF;
END $$;

-- 4. Add the foreign key relationship
ALTER TABLE listings 
ADD CONSTRAINT listings_owner_id_fkey 
FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 5. Enable RLS on both tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- 6. Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Public listings are viewable by everyone" ON listings;
DROP POLICY IF EXISTS "Users can manage own listings" ON listings;

-- 7. Create RLS policies
-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone" 
ON profiles FOR SELECT 
USING (true);

CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" 
ON profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

-- Listings policies  
CREATE POLICY "Public listings are viewable by everyone" 
ON listings FOR SELECT 
USING (status = 'active' OR status IS NULL);

CREATE POLICY "Users can manage own listings" 
ON listings FOR ALL 
USING (auth.uid() = owner_id);

-- 8. Grant permissions
GRANT SELECT ON profiles TO anon, authenticated;
GRANT SELECT ON listings TO anon, authenticated;
GRANT ALL ON listings TO authenticated;
GRANT ALL ON profiles TO authenticated;

-- 9. Update existing listings to have owner_id if they don't
-- (This assumes you have some way to identify the owner, adjust as needed)
UPDATE listings 
SET owner_id = (
    SELECT id FROM auth.users LIMIT 1
)
WHERE owner_id IS NULL;

-- 10. Test the relationship
SELECT 
    l.id,
    l.title,
    p.city,
    p.state,
    p.business_name
FROM listings l
LEFT JOIN profiles p ON l.owner_id = p.id
LIMIT 3;
