-- Chat System Database Schema for Mechanic Part Marketplace
-- Run this in Supabase SQL Editor

-- Create conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    buyer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure unique conversation per listing-buyer pair
    UNIQUE(listing_id, buyer_id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'system')),
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_conversations_buyer_id ON conversations(buyer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_seller_id ON conversations(seller_id);
CREATE INDEX IF NOT EXISTS idx_conversations_listing_id ON conversations(listing_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations(last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Enable Row Level Security
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for conversations
-- Users can see conversations where they are either buyer or seller
CREATE POLICY "Users can view their own conversations" ON conversations
    FOR SELECT USING (
        auth.uid() = buyer_id OR auth.uid() = seller_id
    );

-- Users can create conversations as buyers
CREATE POLICY "Buyers can create conversations" ON conversations
    FOR INSERT WITH CHECK (
        auth.uid() = buyer_id AND
        auth.uid() != seller_id
    );

-- Users can update conversations they participate in
CREATE POLICY "Participants can update conversations" ON conversations
    FOR UPDATE USING (
        auth.uid() = buyer_id OR auth.uid() = seller_id
    );

-- RLS Policies for messages
-- Users can see messages in conversations they participate in
CREATE POLICY "Users can view messages in their conversations" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.conversation_id 
            AND (conversations.buyer_id = auth.uid() OR conversations.seller_id = auth.uid())
        )
    );

-- Users can send messages in conversations they participate in
CREATE POLICY "Users can send messages in their conversations" ON messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.conversation_id 
            AND (conversations.buyer_id = auth.uid() OR conversations.seller_id = auth.uid())
        )
    );

-- Users can update their own messages (for read receipts, etc.)
CREATE POLICY "Users can update messages in their conversations" ON messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.conversation_id 
            AND (conversations.buyer_id = auth.uid() OR conversations.seller_id = auth.uid())
        )
    );

-- Function to update conversation last_message_at when new message is sent
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations 
    SET 
        last_message_at = NEW.created_at,
        updated_at = NOW()
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update conversation timestamp
DROP TRIGGER IF EXISTS trigger_update_conversation_last_message ON messages;
CREATE TRIGGER trigger_update_conversation_last_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_last_message();

-- Function to get conversation with participant details
CREATE OR REPLACE FUNCTION get_conversations_with_details(user_uuid UUID)
RETURNS TABLE (
    conversation_id UUID,
    listing_id UUID,
    listing_title TEXT,
    listing_price DECIMAL,
    other_user_id UUID,
    other_user_name TEXT,
    other_user_type TEXT,
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    unread_count BIGINT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as conversation_id,
        c.listing_id,
        l.title as listing_title,
        l.price_usd as listing_price,
        CASE 
            WHEN c.buyer_id = user_uuid THEN c.seller_id 
            ELSE c.buyer_id 
        END as other_user_id,
        CASE 
            WHEN c.buyer_id = user_uuid THEN p_seller.contact_person 
            ELSE p_buyer.contact_person 
        END as other_user_name,
        CASE 
            WHEN c.buyer_id = user_uuid THEN p_seller.user_type 
            ELSE p_buyer.user_type 
        END as other_user_type,
        (
            SELECT m.content 
            FROM messages m 
            WHERE m.conversation_id = c.id 
            ORDER BY m.created_at DESC 
            LIMIT 1
        ) as last_message,
        c.last_message_at,
        (
            SELECT COUNT(*) 
            FROM messages m 
            WHERE m.conversation_id = c.id 
            AND m.sender_id != user_uuid 
            AND m.read_at IS NULL
        ) as unread_count,
        c.created_at
    FROM conversations c
    JOIN listings l ON l.id = c.listing_id
    LEFT JOIN profiles p_seller ON p_seller.id = c.seller_id
    LEFT JOIN profiles p_buyer ON p_buyer.id = c.buyer_id
    WHERE c.buyer_id = user_uuid OR c.seller_id = user_uuid
    ORDER BY c.last_message_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Enable realtime for conversations and messages
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- Sample data (optional - remove in production)
-- This creates a test conversation and messages for development
/*
INSERT INTO conversations (listing_id, buyer_id, seller_id) VALUES 
(
    (SELECT id FROM listings LIMIT 1),
    (SELECT id FROM auth.users WHERE email LIKE '%buyer%' LIMIT 1),
    (SELECT id FROM auth.users WHERE email LIKE '%seller%' LIMIT 1)
);

INSERT INTO messages (conversation_id, sender_id, content) VALUES 
(
    (SELECT id FROM conversations LIMIT 1),
    (SELECT buyer_id FROM conversations LIMIT 1),
    'Hi, is this part still available?'
),
(
    (SELECT id FROM conversations LIMIT 1),
    (SELECT seller_id FROM conversations LIMIT 1),
    'Yes, it is! Would you like to know more details?'
);
*/
