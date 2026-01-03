import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import Image from 'next/image'
import { MapPin, Calendar, Tag } from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { format } from 'date-fns'

export const dynamic = 'force-dynamic'
export const revalidate = 0
export const dynamicParams = true

export default async function ListingDetailPage({ 
  params 
}: { 
  params: Promise<{ id: string }> 
}) {
  const { id } = await params
  const supabase = await createClient()

  let listing: any = null

  try {
    const { data, error } = await supabase
      .from('listings')
      .select(`
        *,
        listing_photos(storage_path, sort_order),
        profiles(business_name, user_type)
      `)
      .eq('id', id)
      .single()

    if (error) {
      console.error('Error fetching listing:', error)
      notFound()
    }

    listing = data
  } catch (error) {
    console.error('Exception fetching listing:', error)
    notFound()
  }

  if (!listing) {
    notFound()
  }

  const photos = (listing.listing_photos || []).sort((a: any, b: any) => 
    (a.sort_order || 0) - (b.sort_order || 0)
  )

  const imageUrls = photos.map((photo: any) => 
    `https://pyfughpblzbgrfuhymka.supabase.co/storage/v1/object/public/listing-images/${photo.storage_path}`
  )

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-lg shadow-sm overflow-hidden">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 p-8">
            {/* Image Gallery */}
            <div className="space-y-4">
              {imageUrls.length > 0 ? (
                <>
                  <div className="relative aspect-square rounded-lg overflow-hidden bg-gray-100">
                    <Image
                      src={imageUrls[0]}
                      alt={listing.title}
                      fill
                      className="object-cover"
                      priority
                      unoptimized
                    />
                  </div>
                  {imageUrls.length > 1 && (
                    <div className="grid grid-cols-4 gap-2">
                      {imageUrls.slice(1, 5).map((url: string, i: number) => (
                        <div key={i} className="relative aspect-square rounded-lg overflow-hidden bg-gray-100">
                          <Image
                            src={url}
                            alt={`Photo ${i + 2}`}
                            fill
                            className="object-cover"
                            unoptimized
                          />
                        </div>
                      ))}
                    </div>
                  )}
                </>
              ) : (
                <div className="aspect-square bg-gray-200 rounded-lg flex items-center justify-center">
                  <p className="text-gray-500">No images available</p>
                </div>
              )}
            </div>

            {/* Listing Details */}
            <div className="space-y-6">
              <div>
                <h1 className="text-3xl font-bold text-gray-900 mb-2">{listing.title}</h1>
                <p className="text-4xl font-bold text-blue-600">
                  {formatPrice(listing.price || listing.price_usd)}
                </p>
              </div>

              <div className="flex flex-wrap gap-4 text-sm text-gray-600">
                {listing.condition && (
                  <div className="flex items-center">
                    <Tag className="w-4 h-4 mr-1" />
                    <span>{listing.condition}</span>
                  </div>
                )}
                {listing.zip_code && (
                  <div className="flex items-center">
                    <MapPin className="w-4 h-4 mr-1" />
                    <span>{listing.zip_code}</span>
                  </div>
                )}
                {listing.created_at && (
                  <div className="flex items-center">
                    <Calendar className="w-4 h-4 mr-1" />
                    <span>Listed {format(new Date(listing.created_at), 'MMM d, yyyy')}</span>
                  </div>
                )}
              </div>

              {listing.description && (
                <div>
                  <h2 className="text-lg font-semibold text-gray-900 mb-2">Description</h2>
                  <p className="text-gray-700 whitespace-pre-wrap">{listing.description}</p>
                </div>
              )}

              {listing.year && listing.make && listing.model && (
                <div>
                  <h2 className="text-lg font-semibold text-gray-900 mb-2">Vehicle Compatibility</h2>
                  <p className="text-gray-700">
                    {listing.year} {listing.make} {listing.model}
                  </p>
                </div>
              )}

              {listing.profiles && (
                <div className="border-t pt-6">
                  <h2 className="text-lg font-semibold text-gray-900 mb-2">Seller Information</h2>
                  <div className="space-y-1">
                    {listing.profiles.business_name && (
                      <p className="text-gray-700">{listing.profiles.business_name}</p>
                    )}
                  </div>
                </div>
              )}

              <a 
                href={`/chat?listing_id=${listing.id}&seller_id=${listing.owner_id}`}
                className="block w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors text-center"
              >
                Chat with Seller
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
