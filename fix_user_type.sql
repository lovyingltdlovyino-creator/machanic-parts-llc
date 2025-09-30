-- Fix missing user_type column in profiles table
-- Run this in Supabase SQL Editor

-- Add user_type column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'buyer' CHECK (user_type IN ('buyer', 'seller'));

-- Update existing profiles to have user_type based on their auth metadata
-- This will set user_type from the auth.users raw_user_meta_data
UPDATE public.profiles 
SET user_type = COALESCE(
    (SELECT (raw_user_meta_data->>'user_type')::text 
     FROM auth.users 
     WHERE auth.users.id = profiles.id), 
    'buyer'
)
WHERE user_type IS NULL OR user_type = '';

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_user_type ON public.profiles(user_type);

-- Update the RLS policy to ensure users can only create profiles with their own user_type
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (
        auth.uid() = id AND
        user_type = COALESCE((auth.jwt()->>'user_metadata'->>'user_type')::text, 'buyer')
    );
