import { createClient } from '@/lib/supabase/server'
import { ListingCard } from '@/components/ListingCard'
import { SearchBar } from '@/components/SearchBar'
import { FeaturedCarousel } from '@/components/FeaturedCarousel'
import { Categories } from '@/components/Categories'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export default async function Home() {
  const supabase = await createClient()

  let featuredListings: any[] = []
  let allListings: any[] = []

  try {
    // Fetch featured listings for carousel
    const { data: featuredIds } = await supabase
      .from('listings_ranked')
      .select('id')
      .eq('is_featured', true)
      .order('score', { ascending: false })
      .limit(5)

    if (featuredIds && featuredIds.length > 0) {
      const ids = featuredIds.map(r => r.id)
      const { data } = await supabase
        .from('listings')
        .select(`
          *,
          listing_photos(storage_path, sort_order),
          profiles(business_name, user_type)
        `)
        .in('id', ids)
      
      if (data) {
        featuredListings = data
        const order = Object.fromEntries(ids.map((id, i) => [id, i]))
        featuredListings.sort((a, b) => (order[a.id] ?? 999) - (order[b.id] ?? 999))
      }
    }

    // Fetch ALL listings (not just featured)
    const { data: allRankedIds } = await supabase
      .from('listings_ranked')
      .select('id')
      .order('score', { ascending: false})
      .limit(20)

    if (allRankedIds && allRankedIds.length > 0) {
      const ids = allRankedIds.map(r => r.id)
      const { data } = await supabase
        .from('listings')
        .select(`
          *,
          listing_photos(storage_path, sort_order),
          profiles(business_name, user_type)
        `)
        .in('id', ids)
      
      if (data) {
        allListings = data
        const order = Object.fromEntries(ids.map((id, i) => [id, i]))
        allListings.sort((a, b) => (order[a.id] ?? 999) - (order[b.id] ?? 999))
      }
    }
  } catch (error) {
    console.error('Error loading listings:', error)
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Hero Section */}
      <div className="bg-gradient-to-br from-gray-900 via-blue-900 to-gray-800 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
          <div className="text-center">
            <h1 className="text-4xl md:text-5xl font-bold mb-4">
              Find Quality Auto Parts Faster
            </h1>
            <p className="text-lg text-gray-300 mb-8">
              Browse thousands of listings from verified sellers across the country
            </p>
            <SearchBar />
          </div>
        </div>
      </div>

      {/* Categories Section */}
      <div className="max-w-7xl mx-auto">
        <Categories />
      </div>

      {/* Featured Carousel */}
      {featuredListings.length > 0 && (
        <div className="max-w-7xl mx-auto">
          <FeaturedCarousel listings={featuredListings} />
        </div>
      )}

      {/* All Listings Section */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">All Listings</h2>
        </div>

        {allListings.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {allListings.map((listing) => (
              <ListingCard key={listing.id} listing={listing} />
            ))}
          </div>
        ) : (
          <div className="text-center py-12">
            <p className="text-gray-500">No listings available at this time.</p>
          </div>
        )}
      </div>
    </div>
  )
}
