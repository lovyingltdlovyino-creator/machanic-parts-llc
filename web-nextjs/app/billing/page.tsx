'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Check, CreditCard } from 'lucide-react'

const PLAN_DEFS = [
  {
    id: 'free',
    name: 'Free',
    emoji: '✅',
    highlights: [
      'Limited ads views',
      'Appear in Others',
    ],
    features: [
      'Up to 2 active listings (admin-adjustable)',
      'Community access',
    ],
  },
  {
    id: 'basic',
    name: 'Basic',
    emoji: '',
    highlights: [
      '2x more clients',
      'Full listings in Others',
    ],
    features: [
      'Up to 5 active listings',
      'Standard visibility',
    ],
    monthlyPrice: 15.0,
  },
  {
    id: 'premium',
    name: 'Premium',
    emoji: '✨',
    highlights: [
      '5x more clients',
      'Boosts + Featured slots',
    ],
    features: [
      'Up to 20 active listings',
      'Basic analytics',
    ],
    monthlyPrice: 30.0,
  },
  {
    id: 'vip',
    name: 'VIP',
    emoji: '👑',
    highlights: [
      '7x more clients',
      'Lead generation access',
    ],
    features: [
      'Up to 50 active listings',
      'Advanced analytics',
      'Bulk upload',
    ],
    monthlyPrice: 46.0,
  },
  {
    id: 'vip_gold',
    name: 'VIP Gold',
    emoji: '🥇',
    highlights: [
      '10x more clients',
      'Priority placement',
    ],
    features: [
      'Up to 100 active listings',
      'Advanced analytics',
      'Priority placement + Lead gen',
    ],
    monthlyPrice: 59.0,
  },
]

const TERM_LABELS: Record<string, string> = {
  monthly: '1 month',
  quarterly: '3 months',
  semiannual: '6 months',
  annual: '12 months',
}

export default function BillingPage() {
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [activePlanId, setActivePlanId] = useState<string>('free')
  const [subscriptionStatus, setSubscriptionStatus] = useState<string>('inactive')
  const [term, setTerm] = useState<string>('monthly')
  const [loadingCheckout, setLoadingCheckout] = useState(false)
  const [loadingPortal, setLoadingPortal] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    checkUserAndLoadPlan()
  }, [])

  const checkUserAndLoadPlan = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push('/auth')
        return
      }

      const userType = user.user_metadata?.user_type || 'buyer'
      if (userType !== 'seller') {
        alert('Billing is available to sellers only.')
        router.push('/')
        return
      }

      setUser(user)
      await loadCurrentPlan(user.id)
    } catch (error) {
      console.error('Error checking user:', error)
      router.push('/auth')
    } finally {
      setLoading(false)
    }
  }

  const loadCurrentPlan = async (userId: string) => {
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('active_plan_id, subscription_status')
        .eq('id', userId)
        .maybeSingle()

      if (profile) {
        setActivePlanId(profile.active_plan_id || 'free')
        setSubscriptionStatus(profile.subscription_status || 'inactive')
      }
    } catch (error) {
      console.error('Error loading plan:', error)
    }
  }

  const calculateTermPrice = (monthlyPrice: number, selectedTerm: string): number => {
    switch (selectedTerm) {
      case 'monthly':
        return monthlyPrice
      case 'quarterly':
        return monthlyPrice * 3 * 0.95
      case 'semiannual':
        return monthlyPrice * 6 * 0.90
      case 'annual':
        return monthlyPrice * 12 * 0.85
      default:
        return monthlyPrice
    }
  }

  const handleStartCheckout = async (planId: string) => {
    if (planId === 'free') return

    setLoadingCheckout(true)
    try {
      const { data, error } = await supabase.functions.invoke('createCheckoutSession', {
        body: {
          plan_id: planId,
          term: term,
        },
      })

      if (error) throw error

      if (data && data.checkout_url) {
        window.location.href = data.checkout_url
      } else {
        alert('Failed to start checkout. Please try again.')
      }
    } catch (error) {
      console.error('Error starting checkout:', error)
      alert('Failed to start checkout. Please try again.')
    } finally {
      setLoadingCheckout(false)
    }
  }

  const handleOpenPortal = async () => {
    setLoadingPortal(true)
    try {
      const { data, error } = await supabase.functions.invoke('createBillingPortal')

      if (error) throw error

      if (data && data.portal_url) {
        window.location.href = data.portal_url
      } else {
        alert('Failed to open billing portal. Please try again.')
      }
    } catch (error) {
      console.error('Error opening portal:', error)
      alert('Failed to open billing portal. Please try again.')
    } finally {
      setLoadingPortal(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Subscription Plans</h1>
          <div className="flex items-center justify-between">
            <p className="text-gray-600">
              Current Plan: <span className="font-semibold">
                {activePlanId === 'free' ? 'Free' : activePlanId.replace('_', ' ').toUpperCase()}
              </span>
              {activePlanId !== 'free' && (
                <span className="ml-2 text-sm text-gray-500">({subscriptionStatus})</span>
              )}
            </p>
            {activePlanId !== 'free' && (
              <button
                onClick={handleOpenPortal}
                disabled={loadingPortal}
                className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 disabled:opacity-50"
              >
                <CreditCard className="w-4 h-4" />
                {loadingPortal ? 'Loading...' : 'Manage Billing'}
              </button>
            )}
          </div>
        </div>

        {/* Term Selection */}
        <div className="mb-8">
          <p className="text-sm font-semibold text-gray-700 mb-3">Billing Period</p>
          <div className="flex flex-wrap gap-2">
            {Object.entries(TERM_LABELS).map(([key, label]) => (
              <button
                key={key}
                onClick={() => setTerm(key)}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  term === key
                    ? 'bg-green-100 text-green-900 border-2 border-green-500'
                    : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
                }`}
              >
                {label}
                {key !== 'monthly' && (
                  <span className="ml-1 text-xs">
                    (Save {key === 'quarterly' ? '5%' : key === 'semiannual' ? '10%' : '15%'})
                  </span>
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Plans Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6">
          {PLAN_DEFS.map((plan) => {
            const isCurrent = activePlanId === plan.id
            const price = plan.monthlyPrice ? calculateTermPrice(plan.monthlyPrice, term) : 0

            return (
              <div
                key={plan.id}
                className={`bg-white rounded-lg shadow-sm p-6 flex flex-col ${
                  isCurrent ? 'ring-2 ring-blue-500' : ''
                }`}
              >
                <div className="mb-4">
                  <div className="flex items-center gap-2 mb-2">
                    {plan.emoji && <span className="text-2xl">{plan.emoji}</span>}
                    <h3 className="text-xl font-bold text-gray-900">{plan.name}</h3>
                  </div>
                  {isCurrent && (
                    <span className="inline-block px-2 py-1 bg-blue-100 text-blue-800 text-xs font-semibold rounded">
                      Current Plan
                    </span>
                  )}
                </div>

                <div className="mb-4">
                  <p className="text-3xl font-bold text-gray-900">
                    {plan.id === 'free' ? 'Free' : `$${price.toFixed(2)}`}
                  </p>
                  {plan.id !== 'free' && (
                    <p className="text-sm text-gray-500">per {TERM_LABELS[term]}</p>
                  )}
                </div>

                <div className="mb-6 space-y-2">
                  {plan.highlights.map((highlight, index) => (
                    <p key={index} className="text-sm font-semibold text-gray-900">
                      • {highlight}
                    </p>
                  ))}
                </div>

                <div className="mb-6 space-y-2 flex-1">
                  {plan.features.map((feature, index) => (
                    <div key={index} className="flex items-start gap-2">
                      <Check className="w-4 h-4 text-green-600 mt-0.5 flex-shrink-0" />
                      <p className="text-sm text-gray-600">{feature}</p>
                    </div>
                  ))}
                </div>

                <button
                  onClick={() => handleStartCheckout(plan.id)}
                  disabled={loadingCheckout || isCurrent || plan.id === 'free'}
                  className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                    isCurrent
                      ? 'bg-gray-100 text-gray-500 cursor-not-allowed'
                      : plan.id === 'free'
                      ? 'bg-gray-200 text-gray-600 cursor-not-allowed'
                      : 'bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50'
                  }`}
                >
                  {isCurrent
                    ? 'Current Plan'
                    : plan.id === 'free'
                    ? 'Free Plan'
                    : loadingCheckout
                    ? 'Processing...'
                    : 'Subscribe'}
                </button>
              </div>
            )
          })}
        </div>

        <div className="mt-12 bg-blue-50 border border-blue-200 rounded-lg p-6">
          <h3 className="font-bold text-blue-900 mb-2">Need Help?</h3>
          <p className="text-sm text-blue-800 mb-4">
            If you have questions about plans or billing, please contact our support team.
          </p>
          <button
            onClick={() => router.push('/contact')}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-semibold"
          >
            Contact Support
          </button>
        </div>
      </div>
    </div>
  )
}
