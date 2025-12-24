'use client'

import { useState, useEffect, useCallback } from 'react'
import useEmblaCarousel from 'embla-carousel-react'
import Image from 'next/image'
import Link from 'next/link'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface CarouselProps {
  listings: any[]
}

export function FeaturedCarousel({ listings }: CarouselProps) {
  const [emblaRef, emblaApi] = useEmblaCarousel({ loop: true, align: 'center' })
  const [selectedIndex, setSelectedIndex] = useState(0)

  const scrollPrev = useCallback(() => emblaApi && emblaApi.scrollPrev(), [emblaApi])
  const scrollNext = useCallback(() => emblaApi && emblaApi.scrollNext(), [emblaApi])

  const onSelect = useCallback(() => {
    if (!emblaApi) return
    setSelectedIndex(emblaApi.selectedScrollSnap())
  }, [emblaApi])

  useEffect(() => {
    if (!emblaApi) return
    onSelect()
    emblaApi.on('select', onSelect)
    emblaApi.on('reInit', onSelect)

    // Auto-play
    const interval = setInterval(() => {
      emblaApi.scrollNext()
    }, 5000)

    return () => {
      clearInterval(interval)
      emblaApi.off('select', onSelect)
    }
  }, [emblaApi, onSelect])

  if (listings.length === 0) return null

  return (
    <div className="relative px-4 py-8">
      <div className="overflow-hidden" ref={emblaRef}>
        <div className="flex gap-4">
          {listings.map((listing) => {
            const photos = listing.listing_photos || []
            const firstPhoto = photos.find((p: any) => p.sort_order === 0) || photos[0]
            const imageUrl = firstPhoto?.storage_path
              ? `https://pyfughpblzbgrfuhymka.supabase.co/storage/v1/object/public/listing-images/${firstPhoto.storage_path}`
              : '/placeholder-part.jpg'

            return (
              <Link
                key={listing.id}
                href={`/listing/${listing.id}`}
                className="flex-[0_0_85%] md:flex-[0_0_70%] min-w-0"
              >
                <div className="relative h-72 rounded-2xl overflow-hidden shadow-2xl group">
                  <Image
                    src={imageUrl}
                    alt={listing.title || 'Product'}
                    fill
                    className="object-cover group-hover:scale-105 transition-transform duration-500"
                    unoptimized
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent" />
                  
                  <div className="absolute bottom-0 left-0 right-0 p-6 text-white">
                    {listing.condition && (
                      <span className="inline-block px-3 py-1 bg-white/20 backdrop-blur-sm rounded-full text-xs font-medium mb-2">
                        {listing.condition}
                      </span>
                    )}
                    <h3 className="text-2xl font-bold mb-2 line-clamp-2">
                      {listing.title || 'Untitled Listing'}
                    </h3>
                    <p className="text-3xl font-bold text-green-400">
                      {formatPrice(listing.price || listing.price_usd)}
                    </p>
                  </div>
                </div>
              </Link>
            )
          })}
        </div>
      </div>

      {/* Navigation Buttons */}
      <button
        onClick={scrollPrev}
        className="absolute left-2 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/90 shadow-lg flex items-center justify-center hover:bg-white transition-colors z-10"
        aria-label="Previous"
      >
        <ChevronLeft className="w-6 h-6 text-gray-800" />
      </button>
      <button
        onClick={scrollNext}
        className="absolute right-2 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/90 shadow-lg flex items-center justify-center hover:bg-white transition-colors z-10"
        aria-label="Next"
      >
        <ChevronRight className="w-6 h-6 text-gray-800" />
      </button>

      {/* Indicators */}
      <div className="flex justify-center gap-2 mt-4">
        {listings.map((_, index) => (
          <button
            key={index}
            onClick={() => emblaApi?.scrollTo(index)}
            className={`w-2 h-2 rounded-full transition-all ${
              index === selectedIndex ? 'bg-blue-600 w-8' : 'bg-gray-300'
            }`}
            aria-label={`Go to slide ${index + 1}`}
          />
        ))}
      </div>
    </div>
  )
}
