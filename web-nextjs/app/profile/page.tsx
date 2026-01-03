'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { User, Phone, Store, MapPin, Badge, Calendar, List, FileText, Info, Mail, Shield, FileCheck, LogOut, Edit, Save, Trash2 } from 'lucide-react'

export default function ProfilePage() {
  const [user, setUser] = useState<any>(null)
  const [profile, setProfile] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [editMode, setEditMode] = useState(false)
  const [saving, setSaving] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  // Form fields
  const [businessName, setBusinessName] = useState('')
  const [contactPerson, setContactPerson] = useState('')
  const [phone, setPhone] = useState('')
  const [address, setAddress] = useState('')
  const [city, setCity] = useState('')
  const [state, setState] = useState('')
  const [zipCode, setZipCode] = useState('')
  const [businessDescription, setBusinessDescription] = useState('')
  const [yearsInBusiness, setYearsInBusiness] = useState('')
  const [specialties, setSpecialties] = useState('')
  const [businessType, setBusinessType] = useState('individual')

  useEffect(() => {
    loadProfile()
  }, [])

  const loadProfile = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push('/auth')
        return
      }

      setUser(user)

      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle()

      if (profileData) {
        setProfile(profileData)
        setBusinessName(profileData.business_name || '')
        setContactPerson(profileData.contact_person || '')
        setPhone(profileData.phone || '')
        setAddress(profileData.address || '')
        setCity(profileData.city || '')
        setState(profileData.state || '')
        setZipCode(profileData.zip_code || '')
        setBusinessDescription(profileData.business_description || '')
        setYearsInBusiness(profileData.years_in_business?.toString() || '')
        setSpecialties(profileData.specialties || '')
        setBusinessType(profileData.business_type || 'individual')
      }
    } catch (error) {
      console.error('Error loading profile:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      const isComplete = businessName.trim() && contactPerson.trim() && phone.trim() && 
                        address.trim() && city.trim() && state.trim() && zipCode.trim()

      const { error } = await supabase
        .from('profiles')
        .update({
          business_name: businessName,
          contact_person: contactPerson,
          phone: phone,
          address: address,
          city: city,
          state: state,
          zip_code: zipCode,
          business_description: businessDescription,
          years_in_business: yearsInBusiness ? parseInt(yearsInBusiness) : null,
          specialties: specialties,
          business_type: businessType,
          profile_completed: isComplete
        })
        .eq('id', user.id)

      if (error) throw error

      alert('Profile updated successfully!')
      await loadProfile()
      setEditMode(false)
    } catch (error) {
      console.error('Error saving profile:', error)
      alert('Failed to save profile. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    alert('Signed out successfully')
    router.push('/')
    router.refresh()
  }

  const handleDeleteAccount = async () => {
    if (!confirm('Are you sure you want to delete your account? This action cannot be undone. All your data including listings and messages will be permanently deleted.')) {
      return
    }

    try {
      setSaving(true)

      // Delete user's listings
      await supabase.from('listings').delete().eq('owner_id', user.id)

      // Delete user's conversations
      await supabase.from('conversations').delete().or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`)

      // Delete user's profile
      await supabase.from('profiles').delete().eq('id', user.id)

      // Sign out
      await supabase.auth.signOut()

      alert('Account deleted successfully. You have been signed out.')
      router.push('/')
      router.refresh()
    } catch (error) {
      console.error('Error deleting account:', error)
      alert('Failed to delete account. Please try again.')
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

  if (!user) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <div className="text-center">
          <User className="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h2 className="text-2xl font-semibold text-gray-900 mb-2">Sign In Required</h2>
          <p className="text-gray-600 mb-6">You need to sign in to view and edit your profile.</p>
          <button
            onClick={() => router.push('/auth')}
            className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Sign In
          </button>
        </div>
      </div>
    )
  }

  const location = city && state ? `${city}, ${state}` : city || state || 'Location not set'
  // Check profile first, then user_metadata as fallback
  const userType = profile?.user_type || user.user_metadata?.user_type || 'buyer'
  const isSeller = userType === 'seller'

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold text-gray-900">Your Profile</h1>
          <div className="flex gap-2">
            {!editMode ? (
              <>
                <button
                  onClick={() => setEditMode(true)}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  <Edit className="w-4 h-4" />
                  Edit
                </button>
                <button
                  onClick={handleLogout}
                  className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
                >
                  <LogOut className="w-4 h-4" />
                  Logout
                </button>
              </>
            ) : (
              <>
                <button
                  onClick={() => setEditMode(false)}
                  className="px-4 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400"
                  disabled={saving}
                >
                  Cancel
                </button>
                <button
                  onClick={handleSave}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                  disabled={saving}
                >
                  <Save className="w-4 h-4" />
                  {saving ? 'Saving...' : 'Save'}
                </button>
              </>
            )}
          </div>
        </div>

        {/* Profile Summary Card */}
        <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-full bg-blue-100 flex items-center justify-center">
              <User className="w-7 h-7 text-blue-600" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-gray-900">
                {businessName || contactPerson || 'Your Profile'}
              </h2>
              <p className="text-gray-600">{location}</p>
            </div>
          </div>
        </div>

        {/* Seller Plan Card */}
        {isSeller && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-6 mb-6">
            <div className="flex justify-between items-start">
              <div>
                <h3 className="font-bold text-green-900 mb-2">Your Plan</h3>
                <p className="text-sm font-semibold">
                  {profile?.active_plan_id === 'basic' ? 'Basic' :
                   profile?.active_plan_id === 'premium' ? 'Premium' :
                   profile?.active_plan_id === 'vip' ? 'VIP' :
                   profile?.active_plan_id === 'vip_gold' ? 'VIP Gold' : 'Free'}
                  {' '}({profile?.subscription_status || 'inactive'})
                </p>
              </div>
              <button
                onClick={() => router.push('/billing')}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm"
              >
                {profile?.active_plan_id === 'free' || !profile?.active_plan_id ? 'Upgrade' : 'Manage Plan'}
              </button>
            </div>
          </div>
        )}

        {/* Profile Details */}
        <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
          <div className="space-y-4">
            {editMode ? (
              <>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Business Name *</label>
                  <input
                    type="text"
                    value={businessName}
                    onChange={(e) => setBusinessName(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Contact Person *</label>
                  <input
                    type="text"
                    value={contactPerson}
                    onChange={(e) => setContactPerson(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Phone *</label>
                  <input
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Business Type</label>
                  <select
                    value={businessType}
                    onChange={(e) => setBusinessType(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="individual">Individual</option>
                    <option value="company">Company</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Address *</label>
                  <input
                    type="text"
                    value={address}
                    onChange={(e) => setAddress(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-2">City *</label>
                    <input
                      type="text"
                      value={city}
                      onChange={(e) => setCity(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-2">State *</label>
                    <input
                      type="text"
                      value={state}
                      onChange={(e) => setState(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      required
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">ZIP Code *</label>
                  <input
                    type="text"
                    value={zipCode}
                    onChange={(e) => setZipCode(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Years in Business</label>
                  <input
                    type="number"
                    value={yearsInBusiness}
                    onChange={(e) => setYearsInBusiness(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Specialties</label>
                  <input
                    type="text"
                    value={specialties}
                    onChange={(e) => setSpecialties(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., Engine repair, Body work"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Business Description</label>
                  <textarea
                    value={businessDescription}
                    onChange={(e) => setBusinessDescription(e.target.value)}
                    rows={4}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="Tell us about your business..."
                  />
                </div>
              </>
            ) : (
              <>
                <InfoTile icon={Phone} label="Phone" value={phone} />
                <InfoTile icon={Store} label="Business Type" value={businessType} />
                <InfoTile icon={MapPin} label="Address" value={address} />
                <InfoTile icon={Badge} label="Contact Person" value={contactPerson} />
                <InfoTile icon={Calendar} label="Years in Business" value={yearsInBusiness} />
                <InfoTile icon={List} label="Specialties" value={specialties} />
                <InfoTile icon={FileText} label="Description" value={businessDescription} />
              </>
            )}
          </div>
        </div>

        {/* Help & Legal Section */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-bold text-gray-900 mb-4">Help & Legal</h3>
          <div className="space-y-2">
            <button
              onClick={() => router.push('/about')}
              className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 rounded-lg transition-colors"
            >
              <Info className="w-5 h-5 text-gray-600" />
              <span>About Us</span>
            </button>
            <button
              onClick={() => router.push('/contact')}
              className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 rounded-lg transition-colors"
            >
              <Mail className="w-5 h-5 text-gray-600" />
              <span>Contact Us</span>
            </button>
            <button
              onClick={() => router.push('/privacy')}
              className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 rounded-lg transition-colors"
            >
              <Shield className="w-5 h-5 text-gray-600" />
              <span>Privacy Policy</span>
            </button>
            <button
              onClick={() => router.push('/terms')}
              className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 rounded-lg transition-colors"
            >
              <FileCheck className="w-5 h-5 text-gray-600" />
              <span>Terms of Service</span>
            </button>
          </div>

          <div className="mt-6 pt-6 border-t border-gray-200">
            {!isSeller && (
              <button
                onClick={() => router.push('/auth')}
                className="w-full mb-3 px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold"
              >
                Become a Seller
              </button>
            )}
            <button
              onClick={handleDeleteAccount}
              disabled={saving}
              className="w-full flex items-center justify-center gap-2 px-4 py-3 border-2 border-red-500 text-red-500 rounded-lg hover:bg-red-50 font-semibold disabled:opacity-50"
            >
              <Trash2 className="w-4 h-4" />
              Delete Account
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

function InfoTile({ icon: Icon, label, value }: { icon: any, label: string, value: string }) {
  return (
    <div className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
      <Icon className="w-5 h-5 text-blue-600 mt-0.5" />
      <div className="flex-1">
        <p className="text-sm font-semibold text-gray-700">{label}</p>
        <p className="text-gray-900">{value || '—'}</p>
      </div>
    </div>
  )
}
