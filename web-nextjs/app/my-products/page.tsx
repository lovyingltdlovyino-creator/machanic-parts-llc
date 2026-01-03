'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { MyProductCard } from '@/components/MyProductCard'
import { Plus, Award, RefreshCw } from 'lucide-react'

export default function MyProductsPage() {
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [listings, setListings] = useState<any[]>([])
  const [planStats, setPlanStats] = useState<any>(null)
  const [loadingStats, setLoadingStats] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    checkUserAndLoadListings()
  }, [])

  const checkUserAndLoadListings = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push('/auth')
        return
      }

      const userType = user.user_metadata?.user_type || 'buyer'
      if (userType !== 'seller') {
        router.push('/')
        return
      }

      setUser(user)
      await Promise.all([loadListings(user.id), loadPlanStats(user.id)])
    } catch (error) {
      console.error('Error checking user:', error)
      router.push('/auth')
    } finally {
      setLoading(false)
    }
  }

  const loadListings = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('listings')
        .select(`
          *,
          listing_photos(storage_path, sort_order)
        `)
        .eq('owner_id', userId)
        .order('created_at', { ascending: false })

      if (error) throw error
      setListings(data || [])
    } catch (error) {
      console.error('Error loading listings:', error)
    }
  }

  const loadPlanStats = async (userId: string) => {
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('active_plan_id')
        .eq('id', userId)
        .maybeSingle()

      const planId = profile?.active_plan_id || 'free'

      const { data: capabilities } = await supabase
        .from('plan_capabilities')
        .select('monthly_boosts, featured_slots')
        .eq('plan_id', planId)
        .maybeSingle()

      const { data: usage } = await supabase
        .from('seller_usage')
        .select('boosts_used')
        .eq('seller_id', userId)
        .order('period_start', { ascending: false })
        .limit(1)
        .maybeSingle()

      const featuredCount = listings.filter(l => l.is_featured).length

      setPlanStats({
        planId,
        monthlyBoosts: capabilities?.monthly_boosts || 0,
        featuredSlots: capabilities?.featured_slots || 0,
        boostsUsed: usage?.boosts_used || 0,
        featuredUsed: featuredCount
      })
    } catch (error) {
      console.error('Error loading plan stats:', error)
    }
  }

  const handleRefresh = async () => {
    if (!user) return
    setLoadingStats(true)
    await Promise.all([loadListings(user.id), loadPlanStats(user.id)])
    setLoadingStats(false)
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    )
  }

  const featuredCount = listings.filter(l => l.is_featured).length

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold text-gray-900">My Products</h1>
          <button
            onClick={() => router.push('/create-listing')}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-4 h-4" />
            Add Listing
          </button>
        </div>

        {/* Plan Stats Card */}
        {planStats && (
          <div className="bg-white rounded-lg shadow-sm p-4 mb-6">
            <div className="flex items-center gap-3">
              <Award className="w-6 h-6 text-blue-600" />
              <div className="flex-1">
                <p className="font-semibold text-gray-900">
                  Plan: {planStats.planId}
                </p>
                <p className="text-sm text-gray-600">
                  Boosts: {planStats.boostsUsed} / {planStats.monthlyBoosts}  •  Featured used: {featuredCount} / {planStats.featuredSlots}
                </p>
              </div>
              <button
                onClick={handleRefresh}
                disabled={loadingStats}
                className="px-3 py-1.5 text-sm text-blue-600 hover:bg-blue-50 rounded transition-colors disabled:opacity-50"
              >
                <RefreshCw className={`w-4 h-4 ${loadingStats ? 'animate-spin' : ''}`} />
              </button>
            </div>
          </div>
        )}

        {/* Listings */}
        {listings.length > 0 ? (
          <div className="space-y-3">
            {listings.map((listing) => (
              <MyProductCard 
                key={listing.id} 
                listing={listing}
                onUpdate={() => handleRefresh()}
              />
            ))}
          </div>
        ) : (
          <div className="text-center py-12 bg-white rounded-lg">
            <p className="text-gray-500 mb-4">You haven't created any listings yet.</p>
            <button
              onClick={() => router.push('/create-listing')}
              className="inline-flex items-center gap-2 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              <Plus className="w-4 h-4" />
              Create Your First Listing
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
