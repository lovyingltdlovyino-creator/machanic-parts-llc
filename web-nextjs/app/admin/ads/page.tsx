'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Plus, Edit, Trash2, Eye, EyeOff } from 'lucide-react'

interface Ad {
  id: string
  title: string
  image_url: string | null
  link_url: string | null
  position: string
  active: boolean
  display_order: number
}

export default function AdsManagementPage() {
  const [ads, setAds] = useState<Ad[]>([])
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editingAd, setEditingAd] = useState<Ad | null>(null)
  const [formData, setFormData] = useState({
    title: '',
    image_url: '',
    link_url: '',
    position: 'sidebar',
    active: true,
    display_order: 0
  })
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

      const { data: profile } = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle()

      if (!profile?.is_admin) {
        alert('Access denied. Admins only.')
        router.push('/')
        return
      }

      setIsAdmin(true)
      await loadAds()
    } catch (error) {
      console.error('Error:', error)
      router.push('/')
    } finally {
      setLoading(false)
    }
  }

  const loadAds = async () => {
    const { data, error } = await supabase
      .from('ads')
      .select('*')
      .order('display_order', { ascending: true })

    if (error) {
      console.error('Error loading ads:', error)
    } else if (data) {
      setAds(data)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    try {
      if (editingAd) {
        const { error } = await supabase
          .from('ads')
          .update(formData)
          .eq('id', editingAd.id)
        
        if (error) throw error
        alert('Ad updated successfully')
      } else {
        const { error } = await supabase
          .from('ads')
          .insert([formData])
        
        if (error) throw error
        alert('Ad created successfully')
      }
      
      setShowForm(false)
      setEditingAd(null)
      setFormData({
        title: '',
        image_url: '',
        link_url: '',
        position: 'sidebar',
        active: true,
        display_order: 0
      })
      await loadAds()
    } catch (error) {
      console.error('Error saving ad:', error)
      alert('Failed to save ad')
    }
  }

  const handleEdit = (ad: Ad) => {
    setEditingAd(ad)
    setFormData({
      title: ad.title,
      image_url: ad.image_url || '',
      link_url: ad.link_url || '',
      position: ad.position,
      active: ad.active,
      display_order: ad.display_order
    })
    setShowForm(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this ad?')) return
    
    const { error } = await supabase
      .from('ads')
      .delete()
      .eq('id', id)
    
    if (error) {
      console.error('Error deleting ad:', error)
      alert('Failed to delete ad')
    } else {
      alert('Ad deleted successfully')
      await loadAds()
    }
  }

  const toggleActive = async (ad: Ad) => {
    const { error } = await supabase
      .from('ads')
      .update({ active: !ad.active })
      .eq('id', ad.id)
    
    if (error) {
      console.error('Error toggling ad:', error)
      alert('Failed to update ad status')
    } else {
      await loadAds()
    }
  }

  if (loading) {
    return <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
      <p className="text-gray-500">Loading...</p>
    </div>
  }

  if (!isAdmin) {
    return null
  }

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold text-gray-900">Ads Management</h1>
          <button
            onClick={() => {
              setShowForm(!showForm)
              setEditingAd(null)
              setFormData({
                title: '',
                image_url: '',
                link_url: '',
                position: 'sidebar',
                active: true,
                display_order: 0
              })
            }}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-4 h-4" />
            New Ad
          </button>
        </div>

        {showForm && (
          <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
            <h2 className="text-xl font-bold mb-4">{editingAd ? 'Edit Ad' : 'Create Ad'}</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Title *</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Image URL</label>
                <input
                  type="url"
                  value={formData.image_url}
                  onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Link URL</label>
                <input
                  type="url"
                  value={formData.link_url}
                  onChange={(e) => setFormData({ ...formData, link_url: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  placeholder="https://example.com"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Display Order</label>
                <input
                  type="number"
                  value={formData.display_order}
                  onChange={(e) => setFormData({ ...formData, display_order: parseInt(e.target.value) })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  min="0"
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={formData.active}
                  onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                  className="rounded"
                />
                <label className="text-sm font-medium text-gray-700">Active</label>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  {editingAd ? 'Update' : 'Create'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowForm(false)
                    setEditingAd(null)
                  }}
                  className="px-4 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        <div className="bg-white rounded-lg shadow-sm overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Title</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Position</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Order</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {ads.map((ad) => (
                <tr key={ad.id}>
                  <td className="px-6 py-4 text-sm text-gray-900">{ad.title}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">{ad.position}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">{ad.display_order}</td>
                  <td className="px-6 py-4 text-sm">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      ad.active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'
                    }`}>
                      {ad.active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-right">
                    <button
                      onClick={() => toggleActive(ad)}
                      className="text-gray-600 hover:text-gray-900 mr-3"
                      title={ad.active ? 'Deactivate' : 'Activate'}
                    >
                      {ad.active ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                    <button
                      onClick={() => handleEdit(ad)}
                      className="text-blue-600 hover:text-blue-900 mr-3"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDelete(ad.id)}
                      className="text-red-600 hover:text-red-900"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {ads.length === 0 && (
            <div className="text-center py-12">
              <p className="text-gray-500">No ads yet. Create your first ad!</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
