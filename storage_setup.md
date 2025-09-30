# Supabase Storage Setup for Listing Images

## 1. Create Storage Bucket

In your Supabase dashboard, go to **Storage** and create a new bucket:

- **Bucket name**: `listing-images`
- **Public bucket**: ✅ Enable (allows public read access)
- **File size limit**: 50MB (recommended)
- **Allowed MIME types**: `image/*`

## 2. Storage Policies

After creating the bucket, set up these policies in the **Storage** > **Policies** section:

### Policy 1: Public Read Access
```sql
-- Allow anyone to view images
CREATE POLICY "Public Access" ON storage.objects
FOR SELECT USING (bucket_id = 'listing-images');
```

### Policy 2: Authenticated Upload
```sql
-- Allow authenticated users to upload images
CREATE POLICY "Authenticated users can upload listing images" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'listing-images' 
    AND auth.role() = 'authenticated'
);
```

### Policy 3: Users can update their own images
```sql
-- Allow users to update/delete their own images
CREATE POLICY "Users can update own listing images" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'listing-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own listing images" ON storage.objects
FOR DELETE USING (
    bucket_id = 'listing-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);
```

## 3. Folder Structure

Images will be organized by user ID:
```
listing-images/
├── user-id-1/
│   ├── listing-1-image-1.jpg
│   ├── listing-1-image-2.jpg
│   └── listing-2-image-1.jpg
├── user-id-2/
│   └── listing-3-image-1.jpg
└── ...
```

## 4. Environment Variables

Make sure your Flutter app has the correct Supabase configuration:

```dart
// In your main.dart or environment setup
const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

## 5. Testing the Setup

1. Run the SQL setup script in Supabase SQL Editor
2. Create the storage bucket with policies
3. Test image upload through the app
4. Verify images display correctly on homepage and product details

## 6. Optional: Sample Data

To test with sample listings, you can insert test data after setting up a profile:

```sql
-- First, create a profile for your test user
-- Then insert sample listings that reference your profile ID
INSERT INTO public.listings (
    title,
    description,
    price,
    condition,
    make,
    model,
    year,
    vin,
    owner_id,
    status,
    is_featured
) VALUES (
    'Honda Civic Engine Block',
    'Used engine block from 2018 Honda Civic, excellent condition',
    1500.00,
    'used',
    'Honda',
    'Civic',
    2018,
    'SAMPLE123456789',
    auth.uid(), -- Your user ID
    'active',
    true
);
```
