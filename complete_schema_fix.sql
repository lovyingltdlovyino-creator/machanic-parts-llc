-- Complete database schema fix for chat functionality
-- This addresses the foreign key relationship issue between messages and profiles

-- 1. First, check current table structures
SELECT 
    t.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'public' 
AND t.table_name IN ('messages', 'profiles', 'conversations')
ORDER BY t.table_name, c.ordinal_position;

-- 2. Check existing foreign keys
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
AND tc.table_name IN ('messages', 'conversations');

-- 3. Drop existing foreign key if it exists (to recreate it properly)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'messages' 
        AND constraint_name = 'messages_sender_id_fkey'
    ) THEN
        ALTER TABLE public.messages DROP CONSTRAINT messages_sender_id_fkey;
    END IF;
END $$;

-- 4. Ensure profiles table has proper primary key
ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id) ON CONFLICT DO NOTHING;

-- 5. Add the read_at column if it doesn't exist
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE;

-- 6. Create the foreign key relationship properly
ALTER TABLE public.messages 
ADD CONSTRAINT messages_sender_id_fkey 
FOREIGN KEY (sender_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 7. Ensure proper indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);

-- 8. Grant proper permissions
GRANT ALL ON public.messages TO authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.conversations TO authenticated;

-- 9. Ensure RLS is enabled
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- 10. Force multiple schema cache refreshes
NOTIFY pgrst, 'reload schema';
SELECT pg_notify('pgrst', 'reload schema');

-- 11. Verify the foreign key was created
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'messages'
AND kcu.column_name = 'sender_id';

-- 12. Test the relationship by trying a join
SELECT m.id, m.content, p.contact_person
FROM public.messages m
LEFT JOIN public.profiles p ON m.sender_id = p.id
LIMIT 1;
