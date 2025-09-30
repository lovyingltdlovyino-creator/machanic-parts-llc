-- Debug chat messaging issue - check database structure and data

-- 1. Check messages table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'messages' 
ORDER BY ordinal_position;

-- 2. Check conversations table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'conversations' 
ORDER BY ordinal_position;

-- 3. Check recent messages and their conversation IDs
SELECT 
    m.id,
    m.conversation_id,
    m.sender_id,
    m.content,
    m.created_at,
    p.contact_person as sender_name
FROM messages m
LEFT JOIN profiles p ON m.sender_id = p.id
ORDER BY m.created_at DESC
LIMIT 10;

-- 4. Check conversations and their participants
SELECT 
    c.id as conversation_id,
    c.buyer_id,
    c.seller_id,
    c.listing_id,
    buyer.contact_person as buyer_name,
    seller.contact_person as seller_name,
    c.created_at
FROM conversations c
LEFT JOIN profiles buyer ON c.buyer_id = buyer.id
LEFT JOIN profiles seller ON c.seller_id = seller.id
ORDER BY c.created_at DESC
LIMIT 10;

-- 5. Check RLS policies on messages table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'messages';

-- 6. Check if there are any triggers on messages table
SELECT trigger_name, event_manipulation, action_statement 
FROM information_schema.triggers 
WHERE event_object_table = 'messages';
