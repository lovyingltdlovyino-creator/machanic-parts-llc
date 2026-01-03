'use client'

import { useState } from 'react'
import Image from 'next/image'
import { MoreVertical, Edit, Trash2 } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

interface MyProductCardProps {
  listing: any
  onUpdate: () => void
}

export function MyProductCard({ listing, onUpdate }: MyProductCardProps) {
  const [showMenu, setShowMenu] = useState(false)
  const [updating, setUpdating] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const photos = listing.listing_photos || []
  const firstPhoto = photos.find((p: any) => p.sort_order === 0) || photos[0]
  
  const imageUrl = firstPhoto?.storage_path 
    ? `https://pyfughpblzbgrfuhymka.supabase.co/storage/v1/object/public/listing-images/${firstPhoto.storage_path}`
    : '/placeholder-part.jpg'

  const handleStatusUpdate = async (status: string) => {
    setUpdating(true)
    setShowMenu(false)
    
    try {
      const { error } = await supabase
        .from('listings')
        .update({ status })
        .eq('id', listing.id)

      if (error) throw error

      alert(`Listing marked as ${status}`)
      onUpdate()
    } catch (error) {
      console.error('Error updating status:', error)
      alert('Failed to update status. Please try again.')
    } finally {
      setUpdating(false)
    }
  }

  const handleBoost = async () => {
    setUpdating(true)
    setShowMenu(false)
    
    try {
      const { error } = await supabase.rpc('use_boost', {
        _listing_id: listing.id
      })

      if (error) throw error

      alert('Boost applied successfully!')
      onUpdate()
    } catch (error: any) {
      console.error('Error applying boost:', error)
      alert(error.message || 'Failed to apply boost. Please try again.')
    } finally {
      setUpdating(false)
    }
  }

  const handleToggleFeatured = async () => {
    setUpdating(true)
    setShowMenu(false)
    
    const newFeaturedState = !listing.is_featured
    
    try {
      const { error } = await supabase.rpc('set_featured', {
        _listing_id: listing.id,
        _enabled: newFeaturedState
      })

      if (error) throw error

      alert(newFeaturedState ? 'Marked as Featured' : 'Removed from Featured')
      onUpdate()
    } catch (error: any) {
      console.error('Error toggling featured:', error)
      alert(error.message || 'Failed to toggle featured status. Please try again.')
    } finally {
      setUpdating(false)
    }
  }

  const handleDelete = async () => {
    if (!confirm('Are you sure you want to delete this listing? This action cannot be undone.')) {
      return
    }

    setUpdating(true)
    setShowMenu(false)
    
    try {
      const { error } = await supabase
        .from('listings')
        .delete()
        .eq('id', listing.id)

      if (error) throw error

      alert('Listing deleted successfully')
      onUpdate()
    } catch (error) {
      console.error('Error deleting listing:', error)
      alert('Failed to delete listing. Please try again.')
    } finally {
      setUpdating(false)
    }
  }

  return (
    <div className="bg-white rounded-lg shadow-sm p-4 flex items-center gap-4 relative">
      <div className="relative w-16 h-16 flex-shrink-0 bg-gray-100 rounded-lg overflow-hidden">
        <Image
          src={imageUrl}
          alt={listing.title || 'Product'}
          fill
          className="object-cover"
          sizes="64px"
          unoptimized
        />
      </div>

      <div className="flex-1 min-w-0">
        <h3 className="font-semibold text-gray-900 truncate">
          {listing.title || 'Untitled Listing'}
        </h3>
        <p className="text-sm text-gray-600">
          Status: {listing.status || 'active'} | USD {listing.price_usd?.toFixed(2) || '0.00'}
        </p>
      </div>

      <div className="relative">
        <button
          onClick={() => setShowMenu(!showMenu)}
          disabled={updating}
          className="p-2 hover:bg-gray-100 rounded-full transition-colors disabled:opacity-50"
        >
          <MoreVertical className="w-5 h-5 text-gray-600" />
        </button>

        {showMenu && (
          <>
            <div 
              className="fixed inset-0 z-10" 
              onClick={() => setShowMenu(false)}
            />
            <div className="absolute right-0 top-full mt-1 w-48 bg-white rounded-lg shadow-lg border border-gray-200 py-1 z-20">
              <button
                onClick={() => {
                  setShowMenu(false)
                  router.push(`/edit-listing/${listing.id}`)
                }}
                className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50 flex items-center gap-2"
              >
                <Edit className="w-4 h-4" />
                Edit
              </button>
              
              <div className="border-t border-gray-200 my-1" />
              
              <button
                onClick={() => handleStatusUpdate('active')}
                className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50"
              >
                Mark as Active
              </button>
              <button
                onClick={() => handleStatusUpdate('draft')}
                className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50"
              >
                Mark as Draft
              </button>
              <button
                onClick={() => handleStatusUpdate('sold')}
                className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50"
              >
                Mark as Sold
              </button>
              
              <div className="border-t border-gray-200 my-1" />
              
              <button
                onClick={handleBoost}
                className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50"
              >
                Boost (24-72h)
              </button>
              <button
                onClick={handleToggleFeatured}
                className="w-full px-4 py-2 text-left text-sm hover:bg-gray-50"
              >
                {listing.is_featured ? 'Remove Featured' : 'Mark as Featured'}
              </button>
              
              <div className="border-t border-gray-200 my-1" />
              
              <button
                onClick={handleDelete}
                className="w-full px-4 py-2 text-left text-sm hover:bg-red-50 text-red-600 flex items-center gap-2"
              >
                <Trash2 className="w-4 h-4" />
                Delete
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
