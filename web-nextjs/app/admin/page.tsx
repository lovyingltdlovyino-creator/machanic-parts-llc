'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Users, Store, ShoppingBag, DollarSign, Star, Shield, Activity, RefreshCw, Search } from 'lucide-react'

interface Metrics {
  total_users?: number
  sellers?: number
  buyers?: number
  admins?: number
  active_listings?: number
  featured_listings?: number
  blocked_users?: number
  paid_subscribers?: number
  estimated_mrr_usd?: number
}

interface PlanCapability {
  plan_id: string
  max_active_listings: number
  ranking_weight: number
  featured_slots: number
  monthly_boosts: number
  boost_multiplier: number
  boost_hours: number
  lead_access: boolean
  analytics_level: string
}

export default function AdminPage() {
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [activeTab, setActiveTab] = useState<'dashboard' | 'users' | 'settings'>('dashboard')
  const [metrics, setMetrics] = useState<Metrics>({})
  const [loadingMetrics, setLoadingMetrics] = useState(false)
  const [subscriptionsEnabled, setSubscriptionsEnabled] = useState(false)
  const [freeCap, setFreeCap] = useState(2)
  const [plans, setPlans] = useState<PlanCapability[]>([])
  const [users, setUsers] = useState<any[]>([])
  const [loadingUsers, setLoadingUsers] = useState(false)
  const [userSearch, setUserSearch] = useState('')
  const [saving, setSaving] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    checkAdminAndLoad()
  }, [])

  const checkAdminAndLoad = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push('/auth')
        return
      }

      // Check if user is admin
      let admin = false
      
      try {
        const { data: rpcResult } = await supabase.rpc('is_current_user_admin')
        if (rpcResult === true) {
          admin = true
        }
      } catch (e) {
        // RPC might not exist, fallback to profile check
      }

      if (!admin) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('role, user_type, is_admin')
          .eq('id', user.id)
          .maybeSingle()

        if (profile?.is_admin === true || 
            profile?.role?.toLowerCase() === 'admin' || 
            profile?.user_type?.toLowerCase() === 'admin') {
          admin = true
        }
      }

      if (!admin) {
        alert('Access denied. Admins only.')
        router.push('/')
        return
      }

      setIsAdmin(true)

      // Load config
      const { data: config } = await supabase
        .from('app_config')
        .select('subscriptions_enabled, free_cap_override')
        .maybeSingle()

      if (config) {
        setSubscriptionsEnabled(config.subscriptions_enabled || false)
        setFreeCap(config.free_cap_override || 2)
      }

      // Load plans
      const { data: plansData } = await supabase
        .from('plan_capabilities')
        .select('*')
        .order('plan_id')

      if (plansData) {
        setPlans(plansData)
      }

      // Load initial data
      await Promise.all([loadMetrics(), loadUsers()])
    } catch (error) {
      console.error('Error checking admin:', error)
      alert('Failed to load admin page')
      router.push('/')
    } finally {
      setLoading(false)
    }
  }

  const loadMetrics = async () => {
    setLoadingMetrics(true)
    try {
      const { data, error } = await supabase.rpc('admin_get_metrics')
      if (error) throw error
      if (data) {
        setMetrics(data)
      }
    } catch (error) {
      console.error('Error loading metrics:', error)
    } finally {
      setLoadingMetrics(false)
    }
  }

  const loadUsers = async () => {
    setLoadingUsers(true)
    try {
      const { data, error } = await supabase.rpc('admin_list_users', {
        search: userSearch.trim() || null,
        p_limit: 50,
        p_offset: 0
      })
      if (error) throw error
      if (data) {
        setUsers(data)
      }
    } catch (error) {
      console.error('Error loading users:', error)
    } finally {
      setLoadingUsers(false)
    }
  }

  const toggleUserBan = async (userId: string, block: boolean) => {
    try {
      const { error } = await supabase.rpc('admin_set_user_blocked', {
        _user_id: userId,
        _blocked: block,
        _reason: block ? 'Manual action from Admin Panel' : null
      })
      if (error) throw error
      alert(block ? 'User banned successfully' : 'User unbanned successfully')
      await loadUsers()
    } catch (error) {
      console.error('Error toggling ban:', error)
      alert('Failed to update user ban status')
    }
  }

  const updateSubscriptionsEnabled = async (enabled: boolean) => {
    setSaving(true)
    try {
      const { error } = await supabase.rpc('set_subscriptions_enabled', {
        _enabled: enabled
      })
      if (error) throw error
      setSubscriptionsEnabled(enabled)
      alert(`Subscriptions gating ${enabled ? 'enabled' : 'disabled'}`)
    } catch (error) {
      console.error('Error updating subscriptions:', error)
      alert('Failed to update subscriptions setting')
    } finally {
      setSaving(false)
    }
  }

  const updateFreeCap = async (cap: number) => {
    setSaving(true)
    try {
      const { error } = await supabase.rpc('set_free_cap', {
        _cap: cap
      })
      if (error) throw error
      setFreeCap(cap)
      alert(`Free cap set to ${cap}`)
    } catch (error) {
      console.error('Error updating free cap:', error)
      alert('Failed to update free cap')
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    )
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Not authorized. Admins only.</p>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
            <button
              onClick={loadMetrics}
              disabled={loadingMetrics}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${loadingMetrics ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
          
          <div className="flex gap-4 border-t border-gray-200">
            <button
              onClick={() => setActiveTab('dashboard')}
              className={`px-4 py-3 font-medium border-b-2 transition-colors ${
                activeTab === 'dashboard'
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-600 hover:text-gray-900'
              }`}
            >
              Dashboard
            </button>
            <button
              onClick={() => setActiveTab('users')}
              className={`px-4 py-3 font-medium border-b-2 transition-colors ${
                activeTab === 'users'
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-600 hover:text-gray-900'
              }`}
            >
              Users
            </button>
            <button
              onClick={() => setActiveTab('settings')}
              className={`px-4 py-3 font-medium border-b-2 transition-colors ${
                activeTab === 'settings'
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-600 hover:text-gray-900'
              }`}
            >
              Settings
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'dashboard' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <MetricCard icon={Users} label="Total Users" value={metrics.total_users || 0} />
            <MetricCard icon={Store} label="Sellers" value={metrics.sellers || 0} />
            <MetricCard icon={Users} label="Buyers" value={metrics.buyers || 0} />
            <MetricCard icon={Shield} label="Admins" value={metrics.admins || 0} />
            <MetricCard icon={Activity} label="Active Listings" value={metrics.active_listings || 0} />
            <MetricCard icon={Star} label="Featured Listings" value={metrics.featured_listings || 0} color="text-yellow-600" />
            <MetricCard icon={ShoppingBag} label="Paid Subscribers" value={metrics.paid_subscribers || 0} color="text-green-600" />
            <MetricCard icon={Shield} label="Blocked Users" value={metrics.blocked_users || 0} color="text-red-600" />
            <MetricCard 
              icon={DollarSign} 
              label="Est. MRR (USD)" 
              value={`$${((metrics.estimated_mrr_usd || 0) / 100).toFixed(2)}`} 
              color="text-green-600" 
            />
          </div>
        )}

        {activeTab === 'users' && (
          <div className="bg-white rounded-lg shadow-sm p-6">
            <div className="flex gap-4 mb-6">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                <input
                  type="text"
                  value={userSearch}
                  onChange={(e) => setUserSearch(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && loadUsers()}
                  placeholder="Search by email, name, city, state, zip..."
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <button
                onClick={loadUsers}
                disabled={loadingUsers}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
              >
                {loadingUsers ? 'Loading...' : 'Search'}
              </button>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Location</th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Plan</th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {users.map((user) => (
                    <tr key={user.id}>
                      <td className="px-4 py-3 text-sm">{user.email}</td>
                      <td className="px-4 py-3 text-sm">{user.business_name || user.contact_person || '—'}</td>
                      <td className="px-4 py-3 text-sm">
                        {[user.city, user.state].filter(Boolean).join(', ') || '—'}
                      </td>
                      <td className="px-4 py-3 text-sm uppercase">{user.active_plan_id || 'free'}</td>
                      <td className="px-4 py-3 text-sm">
                        {user.admin_blocked ? (
                          <span className="text-red-600 font-medium">Blocked</span>
                        ) : (
                          <span className="text-green-600 font-medium">Active</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-sm">
                        <button
                          onClick={() => toggleUserBan(user.id, !user.admin_blocked)}
                          className={`px-3 py-1 rounded text-xs font-medium ${
                            user.admin_blocked
                              ? 'bg-green-100 text-green-700 hover:bg-green-200'
                              : 'bg-red-100 text-red-700 hover:bg-red-200'
                          }`}
                        >
                          {user.admin_blocked ? 'Unban' : 'Ban'}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {users.length === 0 && (
                <p className="text-center py-8 text-gray-500">No users found</p>
              )}
            </div>
          </div>
        )}

        {activeTab === 'settings' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-lg font-bold mb-4">Subscription Settings</h2>
              
              <div className="flex items-center justify-between mb-6">
                <div>
                  <p className="font-medium text-gray-900">Enable Subscriptions Gating</p>
                  <p className="text-sm text-gray-500">Require paid plans for advanced features</p>
                </div>
                <button
                  onClick={() => updateSubscriptionsEnabled(!subscriptionsEnabled)}
                  disabled={saving}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    subscriptionsEnabled ? 'bg-blue-600' : 'bg-gray-200'
                  }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      subscriptionsEnabled ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium text-gray-900">Free Plan Listing Cap</p>
                  <p className="text-sm text-gray-500">Maximum listings for free tier</p>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    value={freeCap}
                    onChange={(e) => setFreeCap(parseInt(e.target.value) || 0)}
                    onKeyPress={(e) => {
                      if (e.key === 'Enter') {
                        updateFreeCap(freeCap)
                      }
                    }}
                    className="w-20 px-3 py-2 border border-gray-300 rounded-lg"
                    min="0"
                  />
                  <button
                    onClick={() => updateFreeCap(freeCap)}
                    disabled={saving}
                    className="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 text-sm"
                  >
                    Save
                  </button>
                </div>
              </div>

              <div className="mt-6 p-4 bg-blue-50 rounded-lg">
                <p className="text-sm text-blue-800">
                  <strong>Note:</strong> When gating is disabled, all limits are bypassed. 
                  Free cap applies only when gating is enabled.
                </p>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-lg font-bold mb-4">Plan Capabilities</h2>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Plan</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Max Listings</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Rank Weight</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Featured Slots</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Monthly Boosts</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Analytics</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {plans.map((plan) => (
                      <tr key={plan.plan_id}>
                        <td className="px-4 py-3 text-sm font-medium uppercase">{plan.plan_id}</td>
                        <td className="px-4 py-3 text-sm">{plan.max_active_listings}</td>
                        <td className="px-4 py-3 text-sm">{plan.ranking_weight}</td>
                        <td className="px-4 py-3 text-sm">{plan.featured_slots}</td>
                        <td className="px-4 py-3 text-sm">{plan.monthly_boosts}</td>
                        <td className="px-4 py-3 text-sm">{plan.analytics_level}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

function MetricCard({ icon: Icon, label, value, color = 'text-blue-600' }: { 
  icon: any, 
  label: string, 
  value: string | number,
  color?: string 
}) {
  return (
    <div className="bg-white rounded-lg shadow-sm p-6">
      <div className="flex items-center gap-4">
        <div className={`p-3 rounded-lg bg-gray-100`}>
          <Icon className={`w-6 h-6 ${color}`} />
        </div>
        <div className="flex-1">
          <p className="text-sm text-gray-600">{label}</p>
          <p className="text-2xl font-bold text-gray-900">{value}</p>
        </div>
      </div>
    </div>
  )
}
