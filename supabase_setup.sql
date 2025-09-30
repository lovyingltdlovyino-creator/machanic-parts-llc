-- Supabase Database Setup for Mechanic Parts Marketplace
-- Run these SQL commands in your Supabase SQL Editor

-- 1. Create or update the profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    business_name TEXT,
    contact_person TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    business_description TEXT,
    years_in_business INTEGER DEFAULT 0,
    specialties TEXT,
    business_type TEXT DEFAULT 'individual',
    rating NUMERIC(3,2) DEFAULT 5.0,
    profile_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns if table already exists
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS contact_person TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS zip_code TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_description TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS years_in_business INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS specialties TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS business_type TEXT DEFAULT 'individual';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 5.0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 2. Add missing columns to listings table if they don't exist
ALTER TABLE public.listings 
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;

-- 3. Add foreign key constraint for owner_id (if not already exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'listings_owner_id_fkey'
    ) THEN
        ALTER TABLE public.listings 
        ADD CONSTRAINT listings_owner_id_fkey 
        FOREIGN KEY (owner_id) REFERENCES public.profiles(id);
    END IF;
END $$;

-- Admin dashboard & moderation
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS admin_blocked BOOLEAN DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_profiles_admin_blocked ON public.profiles(admin_blocked);

CREATE TABLE IF NOT EXISTS public.plan_prices (
  plan_id TEXT PRIMARY KEY,
  monthly_usd INT NOT NULL
);
INSERT INTO public.plan_prices (plan_id, monthly_usd) VALUES
  ('basic',1500),('premium',3000),('vip',4600),('vip_gold',5900)
ON CONFLICT (plan_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.admin_get_metrics()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE v_total INT; v_admins INT; v_sellers INT; v_buyers INT; v_blocked INT;
        v_active INT; v_featured INT; v_paid INT; v_mrr INT; has_ut BOOLEAN;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.is_admin) THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.profiles;
  SELECT COUNT(*) INTO v_admins FROM public.profiles WHERE is_admin IS TRUE;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='user_type'
  ) INTO has_ut;
  IF has_ut THEN
    SELECT COUNT(*) INTO v_sellers FROM public.profiles WHERE lower(coalesce(user_type,''))='seller';
    SELECT COUNT(*) INTO v_buyers  FROM public.profiles WHERE lower(coalesce(user_type,''))='buyer';
  ELSE
    SELECT COUNT(DISTINCT owner_id) INTO v_sellers FROM public.listings; v_buyers:=GREATEST(v_total-v_sellers-v_admins,0);
  END IF;
  SELECT COUNT(*) INTO v_blocked FROM public.profiles WHERE admin_blocked;
  SELECT COUNT(*) INTO v_active FROM public.listings WHERE status='active';
  SELECT COUNT(*) INTO v_featured FROM public.listings WHERE is_featured;
  SELECT COUNT(*) INTO v_paid FROM public.profiles WHERE coalesce(active_plan_id,'free')<>'free' AND coalesce(subscription_status,'active') IN ('active','trialing');
  SELECT COALESCE(SUM(pp.monthly_usd),0) INTO v_mrr FROM public.profiles p JOIN public.plan_prices pp ON pp.plan_id=p.active_plan_id
    WHERE coalesce(p.active_plan_id,'free')<>'free' AND coalesce(p.subscription_status,'active') IN ('active','trialing');
  RETURN jsonb_build_object('total_users',v_total,'admins',v_admins,'sellers',v_sellers,'buyers',v_buyers,'blocked_users',v_blocked,
    'active_listings',v_active,'featured_listings',v_featured,'paid_subscribers',v_paid,'estimated_mrr_usd',v_mrr);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_list_users(
  search TEXT DEFAULT NULL,
  p_limit INT DEFAULT 25,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  business_name TEXT,
  contact_person TEXT,
  city TEXT,
  state TEXT,
  active_plan_id TEXT,
  admin_blocked BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.is_admin) THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT p.id,
         (u.email)::text AS email,
         (p.business_name)::text AS business_name,
         (p.contact_person)::text AS contact_person,
         (p.city)::text AS city,
         (p.state)::text AS state,
         COALESCE(p.active_plan_id::text,'free') AS active_plan_id,
         COALESCE(p.admin_blocked, FALSE) AS admin_blocked
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE search IS NULL OR
        (u.email)::text ILIKE ('%'||search||'%') OR
        COALESCE(p.business_name::text,'') ILIKE ('%'||search||'%') OR
        COALESCE(p.contact_person::text,'') ILIKE ('%'||search||'%') OR
        COALESCE(p.city::text,'') ILIKE ('%'||search||'%') OR
        COALESCE(p.state::text,'') ILIKE ('%'||search||'%') OR
        COALESCE(p.zip_code::text,'') ILIKE ('%'||search||'%')
  ORDER BY u.created_at DESC NULLS LAST, p.created_at DESC NULLS LAST
  LIMIT COALESCE(p_limit,25) OFFSET COALESCE(p_offset,0);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_set_user_blocked(_user_id UUID, _blocked BOOLEAN, _reason TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.is_admin) THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET admin_blocked=COALESCE(_blocked,FALSE), updated_at=NOW() WHERE id=_user_id;
  UPDATE public.listings SET admin_blocked=COALESCE(_blocked,FALSE) WHERE owner_id=_user_id;
END; $$;

NOTIFY pgrst, 'reload schema';
-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for profiles table
-- Allow users to read all profiles (for seller information display)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'Public profiles are viewable by everyone'
  ) THEN
    CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
      FOR SELECT USING (true);
  END IF;
END $$;

-- Allow users to insert their own profile
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'Users can insert their own profile'
  ) THEN
    CREATE POLICY "Users can insert their own profile" ON public.profiles
      FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- Allow users to update their own profile
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'Users can update their own profile'
  ) THEN
    CREATE POLICY "Users can update their own profile" ON public.profiles
      FOR UPDATE USING (auth.uid() = id);
  END IF;
END $$;

-- 6. Create RLS policies for listings table
-- Allow everyone to view active listings
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'listings'
      AND policyname = 'Active listings are viewable by everyone'
  ) THEN
    CREATE POLICY "Active listings are viewable by everyone" ON public.listings
      FOR SELECT USING (status = 'active');
  END IF;
END $$;

-- Allow authenticated users with completed profiles to insert listings
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'listings'
      AND policyname = 'Users with completed profiles can insert listings'
  ) THEN
    CREATE POLICY "Users with completed profiles can insert listings" ON public.listings
      FOR INSERT WITH CHECK (
          auth.uid() = owner_id 
          AND EXISTS (
              SELECT 1 FROM public.profiles 
              WHERE id = auth.uid() 
              AND profile_completed = true
          )
      );
  END IF;
END $$;

-- Allow users to update their own listings
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'listings'
      AND policyname = 'Users can update their own listings'
  ) THEN
    CREATE POLICY "Users can update their own listings" ON public.listings
      FOR UPDATE USING (auth.uid() = owner_id);
  END IF;
END $$;

-- Allow users to delete their own listings
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'listings'
      AND policyname = 'Users can delete their own listings'
  ) THEN
    CREATE POLICY "Users can delete their own listings" ON public.listings
      FOR DELETE USING (auth.uid() = owner_id);
  END IF;
END $$;

-- 7. Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Create trigger for profiles table
DROP TRIGGER IF EXISTS on_profiles_updated ON public.profiles;
CREATE TRIGGER on_profiles_updated
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 9. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_business_name ON public.profiles(business_name);
CREATE INDEX IF NOT EXISTS idx_profiles_city_state ON public.profiles(city, state);
CREATE INDEX IF NOT EXISTS idx_listings_owner_id ON public.listings(owner_id);
CREATE INDEX IF NOT EXISTS idx_listings_is_featured ON public.listings(is_featured) WHERE is_featured = true;

-- 10. Insert sample profile data (optional - for testing)
-- Uncomment the following if you want to add sample data
/*
INSERT INTO public.profiles (
    id, 
    business_name, 
    contact_person, 
    phone, 
    address, 
    city, 
    state, 
    zip_code, 
    business_description, 
    years_in_business, 
    specialties, 
    business_type, 
    rating
) VALUES (
    '00000000-0000-0000-0000-000000000001', -- Replace with actual user ID
    'AutoParts Pro',
    'John Smith',
    '(555) 123-4567',
    '123 Main Street',
    'Detroit',
    'MI',
    '48201',
    'Professional auto parts dealer with over 15 years of experience in the automotive industry.',
    15,
    'Engine components, Electrical systems, Honda parts, Toyota parts',
    'parts_dealer',
    4.8
) ON CONFLICT (id) DO NOTHING;
*/

-- 11. Extra profile columns for billing/admin (idempotent)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS active_plan_id TEXT DEFAULT 'free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;

-- 12. Global app config (admin adjustable)
CREATE TABLE IF NOT EXISTS public.app_config (
  id INT PRIMARY KEY CHECK (id = 1),
  subscriptions_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  free_cap_override INT NOT NULL DEFAULT 2,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO public.app_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'app_config' AND policyname = 'app_config_read'
  ) THEN
    CREATE POLICY app_config_read ON public.app_config FOR SELECT USING (true);
  END IF;
END $$;

-- Admin RPCs used by AdminPage
CREATE OR REPLACE FUNCTION public.set_subscriptions_enabled(_enabled BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  UPDATE public.app_config SET subscriptions_enabled = _enabled, updated_at = NOW() WHERE id = 1;
END; $$;

CREATE OR REPLACE FUNCTION public.set_free_cap(_cap INT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  UPDATE public.app_config SET free_cap_override = GREATEST(0, _cap), updated_at = NOW() WHERE id = 1;
END; $$;

-- 13. Plan capabilities (admin adjustable; baseline seed below)
CREATE TABLE IF NOT EXISTS public.plan_capabilities (
  plan_id TEXT PRIMARY KEY,
  max_active_listings INT,
  ranking_weight NUMERIC,
  featured_slots INT,
  monthly_boosts INT,
  boost_multiplier NUMERIC,
  boost_hours INT,
  lead_access BOOLEAN,
  analytics_level TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.plan_capabilities ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'plan_capabilities' AND policyname = 'plan_caps_read'
  ) THEN
    CREATE POLICY plan_caps_read ON public.plan_capabilities FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'plan_capabilities' AND policyname = 'plan_caps_admin_upd'
  ) THEN
    CREATE POLICY plan_caps_admin_upd ON public.plan_capabilities FOR UPDATE USING (
      EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE)
    );
  END IF;
END $$;

INSERT INTO public.plan_capabilities AS pc (plan_id, max_active_listings, ranking_weight, featured_slots, monthly_boosts, boost_multiplier, boost_hours, lead_access, analytics_level)
VALUES
  ('free',      2,    0.8, 0,  0, 1.0, 24, FALSE, 'none'),
  ('basic',     5,    1.0, 0,  2, 1.5, 24, FALSE, 'basic'),
  ('premium',  20,    2.0, 1,  4, 1.5, 24, FALSE, 'basic'),
  ('vip',      50,    3.0, 2,  8, 1.75,48, TRUE,  'advanced'),
  ('vip_gold',100,    5.0, 4, 12, 2.0, 72, TRUE,  'advanced')
ON CONFLICT (plan_id) DO UPDATE SET
  updated_at = NOW()
WHERE pc.plan_id = EXCLUDED.plan_id;

-- 14. Listing enhancements for boosts + counters (idempotent)
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS boost_until TIMESTAMPTZ;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS boost_multiplier NUMERIC DEFAULT 1.0;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS impressions INT DEFAULT 0;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS clicks INT DEFAULT 0;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
CREATE INDEX IF NOT EXISTS idx_listings_boost_until ON public.listings(boost_until);

-- 15. Seller monthly usage
CREATE TABLE IF NOT EXISTS public.seller_usage (
  seller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  boosts_used INT NOT NULL DEFAULT 0,
  PRIMARY KEY (seller_id, period_start)
);
ALTER TABLE public.seller_usage ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'seller_usage' AND policyname = 'seller_usage_owner_read'
  ) THEN
    CREATE POLICY seller_usage_owner_read ON public.seller_usage FOR SELECT USING (seller_id = auth.uid());
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'seller_usage' AND policyname = 'seller_usage_owner_mut'
  ) THEN
    CREATE POLICY seller_usage_owner_mut ON public.seller_usage FOR INSERT WITH CHECK (seller_id = auth.uid());
    CREATE POLICY seller_usage_owner_upd ON public.seller_usage FOR UPDATE USING (seller_id = auth.uid());
  END IF;
END $$;

-- Helper: ensure usage row for current month
CREATE OR REPLACE FUNCTION public.ensure_usage_row(_seller UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  ps DATE := date_trunc('month', now())::date;
  pe DATE := (ps + INTERVAL '1 month')::date;
BEGIN
  INSERT INTO public.seller_usage (seller_id, period_start, period_end)
  VALUES (_seller, ps, pe)
  ON CONFLICT (seller_id, period_start) DO NOTHING;
END; $$;

-- 16. Enforce listing caps when gating is ON
CREATE OR REPLACE FUNCTION public.check_listing_cap()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  gating BOOLEAN;
  free_cap INT;
  plan TEXT;
  max_cap INT;
  active_count INT;
BEGIN
  SELECT subscriptions_enabled, free_cap_override INTO gating, free_cap FROM public.app_config WHERE id = 1;
  IF NOT COALESCE(gating, FALSE) THEN
    RETURN NEW;
  END IF;
  IF NEW.owner_id IS NULL THEN RETURN NEW; END IF;
  SELECT COALESCE(active_plan_id, 'free') INTO plan FROM public.profiles WHERE id = NEW.owner_id;
  SELECT max_active_listings INTO max_cap FROM public.plan_capabilities WHERE plan_id = plan;
  IF plan = 'free' THEN max_cap := COALESCE(free_cap, max_cap); END IF;

  IF NEW.status = 'active' THEN
    SELECT COUNT(*) INTO active_count
    FROM public.listings
    WHERE owner_id = NEW.owner_id AND status = 'active' AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000');
    IF COALESCE(active_count,0) >= COALESCE(max_cap,0) THEN
      RAISE EXCEPTION 'Listing cap exceeded for plan %', plan;
    END IF;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_check_cap_ins ON public.listings;
CREATE TRIGGER trg_check_cap_ins
  BEFORE INSERT ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.check_listing_cap();

DROP TRIGGER IF EXISTS trg_check_cap_upd ON public.listings;
CREATE TRIGGER trg_check_cap_upd
  BEFORE UPDATE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.check_listing_cap();

-- 17. Boost and Feature RPCs
CREATE OR REPLACE FUNCTION public.use_boost(_listing_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  l_owner UUID;
  plan TEXT;
  caps RECORD;
  ps DATE := date_trunc('month', now())::date;
  usage_row RECORD;
BEGIN
  SELECT owner_id INTO l_owner FROM public.listings WHERE id = _listing_id;
  IF l_owner IS NULL THEN RAISE EXCEPTION 'Listing not found'; END IF;
  IF l_owner <> auth.uid() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT COALESCE(active_plan_id, 'free') INTO plan FROM public.profiles WHERE id = l_owner;
  SELECT * INTO caps FROM public.plan_capabilities WHERE plan_id = plan;
  PERFORM public.ensure_usage_row(l_owner);
  SELECT * INTO usage_row FROM public.seller_usage WHERE seller_id = l_owner AND period_start = ps;

  IF COALESCE(usage_row.boosts_used,0) >= COALESCE(caps.monthly_boosts,0) THEN
    RAISE EXCEPTION 'No boosts remaining for plan %', plan;
  END IF;

  UPDATE public.listings
    SET boost_until = now() + make_interval(hours => COALESCE(caps.boost_hours,24)),
        boost_multiplier = COALESCE(caps.boost_multiplier,1.0)
  WHERE id = _listing_id;

  UPDATE public.seller_usage
    SET boosts_used = boosts_used + 1
  WHERE seller_id = l_owner AND period_start = ps;
END; $$;

CREATE OR REPLACE FUNCTION public.set_featured(_listing_id UUID, _enabled BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  l_owner UUID;
  plan TEXT;
  caps_slots INT;
  current_count INT;
BEGIN
  SELECT owner_id INTO l_owner FROM public.listings WHERE id = _listing_id;
  IF l_owner IS NULL THEN RAISE EXCEPTION 'Listing not found'; END IF;
  IF l_owner <> auth.uid() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT COALESCE(active_plan_id, 'free') INTO plan FROM public.profiles WHERE id = l_owner;
  SELECT featured_slots INTO caps_slots FROM public.plan_capabilities WHERE plan_id = plan;

  IF _enabled THEN
    SELECT COUNT(*) INTO current_count FROM public.listings WHERE owner_id = l_owner AND is_featured = TRUE;
    IF COALESCE(current_count,0) >= COALESCE(caps_slots,0) THEN
      RAISE EXCEPTION 'No featured slots remaining for plan %', plan;
    END IF;
  END IF;

  UPDATE public.listings SET is_featured = _enabled WHERE id = _listing_id;
END; $$;

-- 18. Ranked listings view (use in queries to surface higher-tier visibility)
DROP VIEW IF EXISTS public.listings_ranked;
CREATE VIEW public.listings_ranked AS
SELECT
  l.*,
  (
    COALESCE(pc.ranking_weight, 1.0)
    + CASE WHEN l.is_featured THEN 2.0 ELSE 0 END
    + CASE WHEN now() < l.boost_until THEN COALESCE(l.boost_multiplier, 1.0) ELSE 0 END
    + LEAST(
        1.0,
        GREATEST(0, 30 - (EXTRACT(EPOCH FROM (now() - COALESCE(l.created_at, now()))) / 86400.0)) / 30.0
      ) * 0.5
    + CASE WHEN COALESCE(l.impressions,0) > 0 THEN (COALESCE(l.clicks,0)::numeric / GREATEST(1, l.impressions)) ELSE 0 END
  ) AS score
FROM public.listings l
LEFT JOIN public.profiles p ON p.id = l.owner_id
LEFT JOIN public.plan_capabilities pc ON pc.plan_id = COALESCE(p.active_plan_id, 'free')
WHERE l.status = 'active';

CREATE INDEX IF NOT EXISTS idx_listings_ranked_score ON public.listings (is_featured) WHERE is_featured = true; -- partial helper

-- 19. Leads module (VIP/VIP Gold access)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  category TEXT,
  details TEXT,
  city TEXT,
  status TEXT DEFAULT 'open',
  assigned_to UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'leads' AND policyname = 'leads_buyer_insert'
  ) THEN
    CREATE POLICY leads_buyer_insert ON public.leads FOR INSERT WITH CHECK (buyer_id = auth.uid());
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'leads' AND policyname = 'leads_read_access'
  ) THEN
    CREATE POLICY leads_read_access ON public.leads FOR SELECT USING (
      buyer_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.active_plan_id IN ('vip','vip_gold')
      )
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'leads' AND policyname = 'leads_claim_update'
  ) THEN
    CREATE POLICY leads_claim_update ON public.leads FOR UPDATE USING (
      EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.active_plan_id IN ('vip','vip_gold'))
    );
  END IF;
END $$;

-- 20. Listing events + analytics tracking
CREATE TABLE IF NOT EXISTS public.listing_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  listing_id UUID REFERENCES public.listings(id) ON DELETE CASCADE,
  viewer_id UUID,
  type TEXT CHECK (type IN ('impression','click','chat')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.listing_events ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'listing_events' AND policyname = 'events_insert_public'
  ) THEN
    CREATE POLICY events_insert_public ON public.listing_events FOR INSERT WITH CHECK (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'listing_events' AND policyname = 'events_owner_read'
  ) THEN
    CREATE POLICY events_owner_read ON public.listing_events FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM public.listings l WHERE l.id = listing_id AND l.owner_id = auth.uid()
      )
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.track_event(_listing_id UUID, _type TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT (_type IN ('impression','click','chat')) THEN
    RAISE EXCEPTION 'Invalid event type %', _type;
  END IF;
  INSERT INTO public.listing_events (listing_id, viewer_id, type) VALUES (_listing_id, auth.uid(), _type);
  IF _type = 'impression' THEN
    UPDATE public.listings SET impressions = COALESCE(impressions,0) + 1 WHERE id = _listing_id;
  ELSIF _type = 'click' THEN
    UPDATE public.listings SET clicks = COALESCE(clicks,0) + 1 WHERE id = _listing_id;
  END IF;
END; $$;

-- 21. Ranked search function (ordered by score desc)
CREATE OR REPLACE FUNCTION public.search_listings(_q TEXT DEFAULT NULL, _city TEXT DEFAULT NULL)
RETURNS SETOF public.listings AS $$
  SELECT l.* FROM public.listings_ranked lr
  JOIN public.listings l ON l.id = lr.id
  WHERE l.status = 'active'
    AND (_q IS NULL OR l.title ILIKE '%'||_q||'%' OR l.description ILIKE '%'||_q||'%')
    AND (_city IS NULL OR l.city = _city)
  ORDER BY lr.score DESC, l.created_at DESC
  LIMIT 200;
$$ LANGUAGE sql STABLE;

-- 22. ZIP centroids and ZIP+radius search (idempotent)
CREATE TABLE IF NOT EXISTS public.zip_centroids (
  zip TEXT PRIMARY KEY,
  primary_city TEXT,
  city TEXT,
  state TEXT,
  latitude NUMERIC,
  longitude NUMERIC
);

CREATE INDEX IF NOT EXISTS idx_zip_centroids_state ON public.zip_centroids(state);

-- RPC: search listings by ZIP within radius (miles). Returns JSONB per row with distance_miles
CREATE OR REPLACE FUNCTION public.search_listings_by_zip(search_zip TEXT, radius_miles NUMERIC DEFAULT 25)
RETURNS SETOF JSONB
LANGUAGE sql
STABLE
AS $$
WITH src AS (
  SELECT z.latitude AS lat, z.longitude AS lon
  FROM public.zip_centroids z
  WHERE z.zip = search_zip
  LIMIT 1
), lz AS (
  SELECT l.*, p.city AS seller_city, p.state AS seller_state, p.zip_code AS seller_zip,
         z.latitude AS lat2, z.longitude AS lon2
  FROM public.listings l
  JOIN public.profiles p ON p.id = l.owner_id
  JOIN public.zip_centroids z ON z.zip = p.zip_code
  WHERE l.status = 'active'
), dist AS (
  SELECT lz.*, src.lat AS lat1, src.lon AS lon1,
    (6371.0 * acos(LEAST(1.0, GREATEST(-1.0,
       cos(radians(src.lat))*cos(radians(lz.lat2))*cos(radians(lz.lon2 - src.lon)) + sin(radians(src.lat))*sin(radians(lz.lat2))
    )))) AS distance_km
  FROM lz, src
  WHERE src.lat IS NOT NULL AND lz.lat2 IS NOT NULL
)
SELECT jsonb_build_object(
  'id', id,
  'owner_id', owner_id,
  'title', title,
  'description', description,
  'price_usd', price_usd,
  'category', category,
  'condition', condition,
  'make', make,
  'model', model,
  'year', year,
  'status', status,
  'is_featured', is_featured,
  'boost_until', boost_until,
  'boost_multiplier', boost_multiplier,
  'impressions', impressions,
  'clicks', clicks,
  'created_at', created_at,
  'city', seller_city,
  'state', seller_state,
  'zip', seller_zip,
  'distance_miles', (distance_km * 0.621371)::numeric
)
FROM dist
WHERE (distance_km * 0.621371) <= COALESCE(radius_miles, 25)
ORDER BY (distance_km * 0.621371), created_at DESC
LIMIT 500;
$$;
