import { createClient } from '@/lib/supabase/server'
import { ListingCard } from '@/components/ListingCard'
import { SearchBar } from '@/components/SearchBar'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export default async function Home() {
  const supabase = await createClient()

  let listings: any[] = []

  try {
    // Fetch featured listings
    const { data: rankedIds, error: rankedError } = await supabase
      .from('listings_ranked')
      .select('id')
      .eq('is_featured', true)
      .order('score', { ascending: false })
      .limit(12)

    if (rankedError) {
      console.error('Error fetching ranked listings:', rankedError)
    }

    const ids = rankedIds?.map(r => r.id) || []
    
    if (ids.length > 0) {
      const { data, error } = await supabase
        .from('listings')
        .select(`
          *,
          listing_photos(storage_path, sort_order),
          profiles(business_name, user_type)
        `)
        .in('id', ids)
      
      if (error) {
        console.error('Error fetching listings:', error)
      } else {
        listings = data || []
        
        // Sort by ranked order
        const order = Object.fromEntries(ids.map((id, i) => [id, i]))
        listings.sort((a, b) => (order[a.id] ?? 999) - (order[b.id] ?? 999))
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

      {/* Listings Section */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">Featured Listings</h2>
        </div>

        {listings.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {listings.map((listing) => (
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
