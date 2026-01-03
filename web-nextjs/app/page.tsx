'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { ListingCard } from '@/components/ListingCard'
import { SearchBar } from '@/components/SearchBar'
import { FeaturedCarousel } from '@/components/FeaturedCarousel'
import { Categories } from '@/components/Categories'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { AdsSidebar } from '@/components/AdsSidebar'

const ITEMS_PER_PAGE = 20

export default function Home() {
  const [featuredListings, setFeaturedListings] = useState<any[]>([])
  const [allListings, setAllListings] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [currentPage, setCurrentPage] = useState(1)
  const [totalCount, setTotalCount] = useState(0)
  const supabase = createClient()

  useEffect(() => {
    loadListings()
  }, [currentPage])

  const loadListings = async () => {
    setLoading(true)
    try {
      // Fetch featured listings for carousel (only on first page)
      if (currentPage === 1) {
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
            const order = Object.fromEntries(ids.map((id, i) => [id, i]))
            const sorted = data.sort((a, b) => (order[a.id] ?? 999) - (order[b.id] ?? 999))
            setFeaturedListings(sorted)
          }
        }
      }

      // Get total count
      const { count } = await supabase
        .from('listings_ranked')
        .select('id', { count: 'exact', head: true })

      if (count) {
        setTotalCount(count)
      }

      // Fetch paginated listings
      const offset = (currentPage - 1) * ITEMS_PER_PAGE
      const { data: allRankedIds } = await supabase
        .from('listings_ranked')
        .select('id')
        .order('score', { ascending: false })
        .range(offset, offset + ITEMS_PER_PAGE - 1)

      if (allRankedIds && allRankedIds.length > 0) {
        const ids = allRankedIds.map(r => r.id)
        const { data } = await supabase
          .from('listings')
          .select(`
            *,
            listing_photos(storage_path, sort_order),
            profiles(business_name, user_type, city, state)
          `)
          .in('id', ids)
        
        if (data) {
          const order = Object.fromEntries(ids.map((id, i) => [id, i]))
          const sorted = data.sort((a, b) => (order[a.id] ?? 999) - (order[b.id] ?? 999))
          setAllListings(sorted)
        }
      }
    } catch (error) {
      console.error('Error loading listings:', error)
    } finally {
      setLoading(false)
    }
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

      {/* All Listings Section with Ads Sidebar */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex gap-8">
          {/* Main Content */}
          <div className="flex-1">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-gray-900">All Listings</h2>
              <p className="text-sm text-gray-600">
                Page {currentPage} of {Math.ceil(totalCount / ITEMS_PER_PAGE) || 1}
              </p>
            </div>

            {loading ? (
              <div className="text-center py-12">
                <p className="text-gray-500">Loading...</p>
              </div>
            ) : allListings.length > 0 ? (
              <>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                  {allListings.map((listing) => (
                    <ListingCard key={listing.id} listing={listing} />
                  ))}
                </div>
                
                {/* Pagination Controls */}
                <div className="flex justify-center items-center gap-4 mt-8">
                  <button
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                    className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <ChevronLeft className="w-4 h-4" />
                    Previous
                  </button>
                  
                  <span className="text-sm text-gray-600">
                    Page {currentPage} of {Math.ceil(totalCount / ITEMS_PER_PAGE)}
                  </span>
                  
                  <button
                    onClick={() => setCurrentPage(p => p + 1)}
                    disabled={currentPage >= Math.ceil(totalCount / ITEMS_PER_PAGE)}
                    className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Next
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              </>
            ) : (
              <div className="text-center py-12">
                <p className="text-gray-500">No listings available at this time.</p>
              </div>
            )}
          </div>

          {/* Ads Sidebar - Desktop Only */}
          <aside className="hidden lg:block w-80 flex-shrink-0">
            <div className="sticky top-8">
              <AdsSidebar />
            </div>
          </aside>
        </div>
      </div>
    </div>
  )
}
