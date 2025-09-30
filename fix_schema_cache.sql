-- Fix chat database schema issues

-- 1. Add missing read_at column to messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE;

-- 2. Create proper foreign key relationship between messages and profiles
-- First check if the foreign key exists
SELECT constraint_name 
FROM information_schema.table_constraints 
WHERE table_name = 'messages' AND constraint_type = 'FOREIGN KEY';

-- Add foreign key if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'messages' 
        AND constraint_name = 'messages_sender_id_fkey'
    ) THEN
        ALTER TABLE public.messages 
        ADD CONSTRAINT messages_sender_id_fkey 
        FOREIGN KEY (sender_id) REFERENCES public.profiles(id);
    END IF;
END $$;

-- 3. Force schema cache refresh
NOTIFY pgrst, 'reload schema';

-- 4. Verify the changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'messages' AND column_name = 'read_at';

SELECT constraint_name, constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'messages' AND constraint_type = 'FOREIGN KEY';

-- First, verify the messages table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'messages'
ORDER BY ordinal_position;

-- Reload the schema cache (this forces Supabase to refresh its internal cache)
NOTIFY pgrst, 'reload schema';

-- Alternative method: Touch the table to trigger cache refresh
COMMENT ON TABLE messages IS 'Chat messages table - updated to refresh cache';

-- Verify the table structure exists correctly
SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'messages' 
    AND column_name = 'content'
) as content_column_exists;

-- If the content column doesn't exist for some reason, add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'messages' 
        AND column_name = 'content'
    ) THEN
        ALTER TABLE messages ADD COLUMN content TEXT NOT NULL;
    END IF;
END $$;

-- Grant necessary permissions
GRANT ALL ON messages TO authenticated;
GRANT ALL ON conversations TO authenticated;

-- Ensure RLS is properly configured
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- Verify all policies exist
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('messages', 'conversations')
ORDER BY tablename, policyname;
