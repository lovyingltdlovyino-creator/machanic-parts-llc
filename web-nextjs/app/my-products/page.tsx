import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { ListingCard } from '@/components/ListingCard'
import Link from 'next/link'
import { Plus } from 'lucide-react'

export default async function MyProductsPage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/auth')
  }

  // Check if user is seller
  const { data: profile } = await supabase
    .from('profiles')
    .select('user_type')
    .eq('id', user.id)
    .single()

  if (profile?.user_type !== 'seller') {
    redirect('/')
  }

  // Fetch user's listings
  const { data: listings } = await supabase
    .from('listings')
    .select(`
      *,
      listing_photos(storage_path, sort_order),
      profiles(business_name, user_type)
    `)
    .eq('seller_id', user.id)
    .order('created_at', { ascending: false })

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900">My Products</h1>
          <Link
            href="/create-listing"
            className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-4 h-4" />
            <span>Add Listing</span>
          </Link>
        </div>

        {listings && listings.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {listings.map((listing) => (
              <ListingCard key={listing.id} listing={listing} />
            ))}
          </div>
        ) : (
          <div className="text-center py-12 bg-white rounded-lg">
            <p className="text-gray-500 mb-4">You haven't created any listings yet.</p>
            <Link
              href="/create-listing"
              className="inline-flex items-center space-x-2 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              <Plus className="w-4 h-4" />
              <span>Create Your First Listing</span>
            </Link>
          </div>
        )}
      </div>
    </div>
  )
}
