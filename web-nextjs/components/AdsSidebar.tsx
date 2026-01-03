'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { ExternalLink } from 'lucide-react'

interface Ad {
  id: string
  title: string
  image_url: string | null
  link_url: string | null
  display_order: number
}

export function AdsSidebar() {
  const [ads, setAds] = useState<Ad[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadAds()
  }, [])

  const loadAds = async () => {
    try {
      const supabase = createClient()
      const { data, error } = await supabase
        .from('ads')
        .select('*')
        .eq('active', true)
        .eq('position', 'sidebar')
        .order('display_order', { ascending: true })
        .limit(5)

      if (error) throw error
      if (data) {
        setAds(data)
      }
    } catch (error) {
      console.error('Error loading ads:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading || ads.length === 0) {
    return null
  }

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-bold text-gray-900">Sponsored</h3>
      {ads.map((ad) => (
        <a
          key={ad.id}
          href={ad.link_url || '#'}
          target="_blank"
          rel="noopener noreferrer"
          className="block bg-white rounded-lg shadow-sm p-4 hover:shadow-md transition-shadow"
        >
          {ad.image_url && (
            <img
              src={ad.image_url}
              alt={ad.title}
              className="w-full h-48 object-cover rounded-lg mb-3"
            />
          )}
          <div className="flex items-start justify-between gap-2">
            <h4 className="font-medium text-gray-900 text-sm">{ad.title}</h4>
            <ExternalLink className="w-4 h-4 text-gray-400 flex-shrink-0" />
          </div>
        </a>
      ))}
    </div>
  )
}
