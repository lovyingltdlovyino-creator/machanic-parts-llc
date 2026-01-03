'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter, useSearchParams } from 'next/navigation'

export default function ChatPage() {
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [conversations, setConversations] = useState<any[]>([])
  const router = useRouter()
  const searchParams = useSearchParams()
  const supabase = createClient()

  useEffect(() => {
    const checkUser = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        // Show sign in prompt
        const shouldSignIn = confirm('Sign In Required\n\nYou need to sign in to contact sellers and buy items.')
        if (shouldSignIn) {
          router.push('/auth')
        } else {
          router.push('/')
        }
        return
      }

      setUser(user)

      // Check if user needs to complete profile (buyers only)
      const userType = user.user_metadata?.user_type || 'buyer'
      if (userType === 'buyer') {
        const { data: profile } = await supabase
          .from('profiles')
          .select('profile_completed')
          .eq('id', user.id)
          .maybeSingle()

        if (!profile || profile.profile_completed !== true) {
          const shouldComplete = confirm('Complete Your Profile\n\nPlease complete your profile before contacting sellers.')
          if (shouldComplete) {
            router.push('/complete-profile')
          } else {
            router.push('/')
          }
          return
        }
      }

      // Load conversations
      await loadConversations(user)

      // Check if coming from listing page with seller_id and listing_id
      const listingId = searchParams.get('listing_id')
      const sellerId = searchParams.get('seller_id')

      if (listingId && sellerId) {
        await handleContactSeller(user, listingId, sellerId)
      } else {
        setLoading(false)
      }
    }

    checkUser()
  }, [searchParams])

  const handleContactSeller = async (user: any, listingId: string, sellerId: string) => {
    try {
      // Check if user is trying to chat with themselves
      if (user.id === sellerId) {
        alert('You cannot start a chat with yourself.')
        router.push('/')
        return
      }

      // Check if conversation already exists
      const { data: existingConversation } = await supabase
        .from('conversations')
        .select('*')
        .eq('buyer_id', user.id)
        .eq('seller_id', sellerId)
        .eq('listing_id', listingId)
        .maybeSingle()

      if (existingConversation) {
        // Conversation exists, just stay on chat page to show it
        setLoading(false)
        return
      }

      // Create new conversation
      const { data: newConversation, error } = await supabase
        .from('conversations')
        .insert({
          buyer_id: user.id,
          seller_id: sellerId,
          listing_id: listingId,
        })
        .select()
        .single()

      if (error) throw error

      // Conversation created, reload conversations
      await loadConversations(user)
      setLoading(false)
    } catch (error) {
      console.error('Error creating conversation:', error)
      alert('Failed to start chat. Please try again.')
      router.push('/')
    }
  }

  const loadConversations = async (currentUser: any) => {
    try {
      // First get conversations
      const { data: convos, error: convosError } = await supabase
        .from('conversations')
        .select('*')
        .or(`buyer_id.eq.${currentUser.id},seller_id.eq.${currentUser.id}`)
        .order('updated_at', { ascending: false })

      if (convosError) throw convosError

      if (!convos || convos.length === 0) {
        setConversations([])
        return
      }

      // Get unique user IDs and listing IDs
      const userIds = new Set<string>()
      const listingIds = new Set<string>()
      
      convos.forEach(convo => {
        userIds.add(convo.buyer_id)
        userIds.add(convo.seller_id)
        if (convo.listing_id) listingIds.add(convo.listing_id)
      })

      // Fetch profiles
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, business_name, contact_person')
        .in('id', Array.from(userIds))

      // Fetch listings
      const { data: listings } = await supabase
        .from('listings')
        .select('id, title, price_usd')
        .in('id', Array.from(listingIds))

      // Map profiles and listings to conversations
      const profileMap = new Map(profiles?.map(p => [p.id, p]) || [])
      const listingMap = new Map(listings?.map(l => [l.id, l]) || [])

      const enrichedConvos = convos.map(convo => ({
        ...convo,
        buyer: profileMap.get(convo.buyer_id),
        seller: profileMap.get(convo.seller_id),
        listings: listingMap.get(convo.listing_id)
      }))

      setConversations(enrichedConvos)
    } catch (error) {
      console.error('Error loading conversations:', error)
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
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Messages</h1>
        
        {conversations.length > 0 ? (
          <div className="space-y-4">
            {conversations.map((conversation) => {
              const isUserBuyer = conversation.buyer_id === user?.id
              const otherUserProfile = isUserBuyer ? conversation.seller : conversation.buyer
              const otherUserName = otherUserProfile?.business_name || otherUserProfile?.contact_person || 'User'
              const listing = conversation.listings

              return (
                <div
                  key={conversation.id}
                  className="bg-white rounded-lg shadow-sm p-6 hover:shadow-md transition-shadow cursor-pointer"
                  onClick={() => router.push(`/chat/${conversation.id}`)}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <h3 className="font-semibold text-gray-900 mb-1">
                        {otherUserName}
                      </h3>
                      {listing && (
                        <p className="text-sm text-gray-600 mb-2">
                          Re: {listing.title}
                        </p>
                      )}
                      <p className="text-xs text-gray-400">
                        {new Date(conversation.updated_at).toLocaleDateString()}
                      </p>
                    </div>
                    {listing?.price_usd && (
                      <div className="text-right">
                        <p className="text-lg font-bold text-blue-600">
                          ${listing.price_usd.toLocaleString()}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow-sm p-12 text-center">
            <p className="text-gray-500 mb-4">No messages yet.</p>
            <p className="text-sm text-gray-400">
              Start a conversation by clicking "Chat with Seller" on any listing page.
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
