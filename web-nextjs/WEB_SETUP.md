# Web Application Setup - Next.js TypeScript

This is the web frontend for Mechanic Part LLC, built with Next.js, TypeScript, and Tailwind CSS.

## 🚀 What Was Changed

### Architecture
- **Separated web from mobile**: Web is now Next.js (TypeScript), mobile remains Flutter
- **Modern stack**: Next.js 15 App Router, TypeScript, Tailwind CSS, Supabase
- **Same database**: Both web and mobile use the same Supabase backend

### File Structure
```
web-nextjs/
├── app/                    # Next.js App Router pages
│   ├── auth/              # Authentication
│   ├── listing/[id]/      # Product details
│   ├── my-products/       # Seller dashboard
│   ├── profile/           # User profile
│   ├── chat/              # Messages
│   ├── about/             # Static pages
│   ├── contact/
│   ├── privacy/
│   ├── terms/
│   └── complete-profile/  # Profile completion
├── components/            # Reusable React components
│   ├── Navigation.tsx
│   ├── Footer.tsx
│   ├── SearchBar.tsx
│   └── ListingCard.tsx
├── lib/                   # Utilities
│   ├── supabase/         # Supabase clients
│   └── utils.ts          # Helper functions
└── .env.local            # Environment variables
```

## 📋 Prerequisites

1. Node.js 18+ installed
2. Supabase project (already configured)
3. Environment variables set in `.env.local`

## 🛠️ Setup Instructions

### 1. Install Dependencies
```bash
cd web-nextjs
npm install
```

### 2. Environment Variables
The `.env.local` file is already configured with your Supabase credentials:
```
NEXT_PUBLIC_SUPABASE_URL=https://pyfughpblzbgrfuhymka.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 3. Run Development Server
```bash
npm run dev
```

Visit `http://localhost:3000`

### 4. Build for Production
```bash
npm run build
npm start
```

## 🚀 Deployment

### Netlify Deployment (Recommended)

1. **Update Netlify Configuration**:
   - In Netlify dashboard, change the base directory to `web-nextjs`
   - Build command: `npm run build`
   - Publish directory: `.next`

2. **Environment Variables**:
   Add these to Netlify dashboard under Site Settings → Environment Variables:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://pyfughpblzbgrfuhymka.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here
   ```

3. **Deploy**:
   - Push to GitHub
   - Netlify will automatically deploy

## ✅ What's Working

### Pages Implemented
- ✅ Home page with listings and search
- ✅ Authentication (sign in/sign up)
- ✅ Product details page
- ✅ Seller dashboard (My Products)
- ✅ Profile page
- ✅ Chat page
- ✅ Static pages (About, Contact, Privacy, Terms)
- ✅ Complete profile flow

### Features
- ✅ Supabase authentication
- ✅ Server-side rendering (SSR) for listings
- ✅ Client-side navigation
- ✅ Responsive design (mobile + desktop)
- ✅ Image optimization with Next.js Image
- ✅ Professional navigation and footer

## 📱 Mobile App (Flutter)

The Flutter mobile app (`lib/` directory) remains **completely unchanged** and continues to work as before:
- iOS app still builds and runs normally
- All mobile features intact
- Uses same Supabase backend

## 🔄 Migration Strategy

### Current State
- Web: Next.js TypeScript (new)
- Mobile: Flutter (unchanged)
- Backend: Supabase (shared)

### Deployment Options

**Option 1: Separate Domains** (Recommended)
- Web: mechanicpartllc.com (Netlify - Next.js)
- Mobile: Flutter iOS app (TestFlight/App Store)

**Option 2: Subdomain**
- Web: www.mechanicpartllc.com (Next.js)
- API/Mobile: Uses Supabase directly

## 🐛 Known Issues & TODOs

### Needs Implementation
- [ ] Create listing page (sellers can't add new products yet)
- [ ] Edit listing functionality
- [ ] Real-time chat messaging
- [ ] Image upload for listings
- [ ] Advanced search filters
- [ ] Pagination for listings
- [ ] User settings page

### Optional Enhancements
- [ ] Add carousel/slider for featured products
- [ ] Implement favorites/saved listings
- [ ] Add reviews/ratings system
- [ ] Push notifications (web)
- [ ] Dark mode

## 📊 Database Schema

No database changes needed - uses existing Supabase tables:
- `listings` - Product listings
- `profiles` - User profiles
- `listing_photos` - Product images
- `listings_ranked` - Featured/ranked listings
- `messages` & `conversations` - Chat (exists but needs UI)

## 🔑 Key Differences from Flutter Web

| Feature | Flutter Web | Next.js Web |
|---------|-------------|-------------|
| **Language** | Dart | TypeScript |
| **Framework** | Flutter | React/Next.js |
| **Styling** | Flutter widgets | Tailwind CSS |
| **SEO** | Poor | Excellent (SSR) |
| **Performance** | Heavy bundle | Fast, optimized |
| **Mobile** | ✅ Works | ✅ Responsive |

## 🎯 Next Steps

1. **Test locally**: `npm run dev` and verify all pages work
2. **Configure Netlify**: Update base directory to `web-nextjs`
3. **Deploy**: Push to GitHub for automatic deployment
4. **Implement missing features**: Create listing, edit, etc.
5. **Mobile remains unchanged**: Continue using Flutter for iOS app

## 💡 Tips

- **Hot reload**: Next.js has fast refresh - changes appear instantly
- **TypeScript**: Catch errors at compile time
- **Server components**: Most pages use SSR for better SEO
- **Client components**: Use `'use client'` for interactivity

## 📞 Support

If you encounter issues:
1. Check `.env.local` has correct Supabase credentials
2. Verify Node.js version is 18+
3. Clear `.next` cache: `rm -rf .next` then rebuild
4. Check Netlify build logs for deployment issues
