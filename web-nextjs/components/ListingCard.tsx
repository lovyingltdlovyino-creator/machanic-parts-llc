import Link from 'next/link'
import Image from 'next/image'
import { MapPin } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface ListingCardProps {
  listing: any
}

export function ListingCard({ listing }: ListingCardProps) {
  const photos = listing.listing_photos || []
  const firstPhoto = photos.find((p: any) => p.sort_order === 0) || photos[0]
  
  const imageUrl = firstPhoto?.storage_path 
    ? `https://pyfughpblzbgrfuhymka.supabase.co/storage/v1/object/public/listing-images/${firstPhoto.storage_path}`
    : '/placeholder-part.jpg'

  return (
    <Link href={`/listing/${listing.id}`} className="group">
      <div className="bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow overflow-hidden">
        <div className="relative aspect-square bg-gray-100">
          <Image
            src={imageUrl}
            alt={listing.title || 'Product'}
            fill
            className="object-cover group-hover:scale-105 transition-transform duration-200"
            sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 25vw"
            unoptimized
          />
          {listing.condition && (
            <span className="absolute top-2 right-2 px-2 py-1 text-xs font-medium bg-white rounded-full">
              {listing.condition}
            </span>
          )}
        </div>
        
        <div className="p-4">
          <h3 className="font-semibold text-gray-900 mb-1 line-clamp-2">
            {listing.title || 'Untitled Listing'}
          </h3>
          
          <div className="flex items-center text-sm text-gray-600 mb-2">
            <MapPin className="w-3 h-3 mr-1" />
            <span>
              {listing.profiles?.city && listing.profiles?.state 
                ? `${listing.profiles.city}, ${listing.profiles.state}`
                : listing.profiles?.city || listing.profiles?.state || listing.zip_code || 'Location not specified'}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-lg font-bold text-blue-600">
              {formatPrice(listing.price || listing.price_usd)}
            </span>
            {listing.profiles?.business_name && (
              <span className="text-xs text-gray-500">
                {listing.profiles.business_name}
              </span>
            )}
          </div>
        </div>
      </div>
    </Link>
  )
}
