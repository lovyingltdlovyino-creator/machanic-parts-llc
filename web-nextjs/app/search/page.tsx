import { createClient } from '@/lib/supabase/server'
import { ListingCard } from '@/components/ListingCard'
import { SearchBar } from '@/components/SearchBar'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ query?: string; type?: string; category?: string }>
}) {
  const params = await searchParams
  const supabase = await createClient()
  let listings: any[] = []

  try {
    let query = supabase
      .from('listings')
      .select(`
        *,
        listing_photos(storage_path, sort_order),
        profiles(business_name, user_type, city, state)
      `)

    // Filter by type (vehicle or part)
    // Note: database uses 'car' not 'vehicle' for the type enum
    if (params.type) {
      const dbType = params.type === 'vehicle' ? 'car' : params.type
      query = query.eq('type', dbType)
    }

    // Filter by category (for parts)
    if (params.category) {
      query = query.eq('category', params.category)
    }

    // Search by query text
    if (params.query) {
      query = query.or(`title.ilike.%${params.query}%,description.ilike.%${params.query}%`)
    }

    const { data, error } = await query.order('created_at', { ascending: false }).limit(20)

    if (error) {
      console.error('Search error:', error)
    } else {
      listings = data || []
    }
  } catch (error) {
    console.error('Exception during search:', error)
  }

  const filterText = params.type 
    ? `${params.type === 'vehicle' ? 'Vehicles' : 'Parts'}${params.category ? ` - ${params.category}` : ''}`
    : params.query 
    ? `"${params.query}"`
    : 'All Listings'

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-gradient-to-br from-gray-900 via-blue-900 to-gray-800 text-white py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold mb-4">Search Results</h1>
          <SearchBar />
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">
            {filterText} ({listings.length} results)
          </h2>
        </div>

        {listings.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {listings.map((listing) => (
              <ListingCard key={listing.id} listing={listing} />
            ))}
          </div>
        ) : (
          <div className="text-center py-12">
            <p className="text-gray-500">No listings found matching your criteria.</p>
          </div>
        )}
      </div>
    </div>
  )
}
