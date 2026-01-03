-- Ads table for sidebar advertisements
CREATE TABLE IF NOT EXISTS ads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  image_url TEXT,
  link_url TEXT,
  position TEXT DEFAULT 'sidebar',
  active BOOLEAN DEFAULT true,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE ads ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view active ads
CREATE POLICY "Anyone can view active ads"
  ON ads FOR SELECT
  USING (active = true);

-- Policy: Only admins can manage ads
CREATE POLICY "Admins can manage ads"
  ON ads FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Blog posts table
CREATE TABLE IF NOT EXISTS blog_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  content TEXT NOT NULL,
  excerpt TEXT,
  featured_image_url TEXT,
  author_id UUID REFERENCES auth.users(id),
  published BOOLEAN DEFAULT false,
  published_at TIMESTAMPTZ,
  views INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Blog categories
CREATE TABLE IF NOT EXISTS blog_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Blog post categories junction table
CREATE TABLE IF NOT EXISTS blog_post_categories (
  blog_post_id UUID REFERENCES blog_posts(id) ON DELETE CASCADE,
  category_id UUID REFERENCES blog_categories(id) ON DELETE CASCADE,
  PRIMARY KEY (blog_post_id, category_id)
);

-- Enable RLS for blog tables
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_post_categories ENABLE ROW LEVEL SECURITY;

-- Blog policies: Anyone can view published posts
CREATE POLICY "Anyone can view published blog posts"
  ON blog_posts FOR SELECT
  USING (published = true);

-- Only admins can manage blog posts
CREATE POLICY "Admins can manage blog posts"
  ON blog_posts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Anyone can view categories
CREATE POLICY "Anyone can view categories"
  ON blog_categories FOR SELECT
  TO public
  USING (true);

-- Admins can manage categories
CREATE POLICY "Admins can manage categories"
  ON blog_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Anyone can view post-category associations
CREATE POLICY "Anyone can view post categories"
  ON blog_post_categories FOR SELECT
  TO public
  USING (true);

-- Admins can manage post-category associations
CREATE POLICY "Admins can manage post categories"
  ON blog_post_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_blog_posts_slug ON blog_posts(slug);
CREATE INDEX IF NOT EXISTS idx_blog_posts_published ON blog_posts(published, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_ads_active_order ON ads(active, display_order);
