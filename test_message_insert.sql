-- Test message insertion directly in database

-- 1. Check if we can insert a test message
-- First, get a valid conversation_id and user_id
SELECT 
    c.id as conversation_id,
    c.buyer_id,
    c.seller_id
FROM conversations c
LIMIT 1;

-- 2. Check profiles table for valid user IDs
SELECT id, contact_person FROM profiles LIMIT 3;

-- 3. Try inserting a test message (replace with actual IDs from above)
-- INSERT INTO messages (conversation_id, sender_id, content, created_at)
-- VALUES ('your-conversation-id', 'your-user-id', 'Test message', NOW());

-- 4. Check if the message was inserted
SELECT 
    m.id,
    m.conversation_id,
    m.sender_id,
    m.content,
    m.created_at
FROM messages m
ORDER BY m.created_at DESC
LIMIT 5;

-- 5. Check RLS policies on messages table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'messages';

-- 6. Check if realtime is enabled for messages table
SELECT schemaname, tablename, rowsecurity
FROM pg_tables 
WHERE tablename = 'messages';
