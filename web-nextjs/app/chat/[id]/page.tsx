'use client'

import { useEffect, useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter, useParams } from 'next/navigation'
import { Send, ArrowLeft } from 'lucide-react'

export default function ConversationPage() {
  const [user, setUser] = useState<any>(null)
  const [conversation, setConversation] = useState<any>(null)
  const [messages, setMessages] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [messageText, setMessageText] = useState('')
  const [otherUserTyping, setOtherUserTyping] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const typingTimeoutRef = useRef<NodeJS.Timeout>()
  const router = useRouter()
  const params = useParams()
  const supabase = createClient()
  const conversationId = params.id as string

  useEffect(() => {
    loadConversation()
  }, [conversationId])

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  useEffect(() => {
    if (!conversation) return

    // Set up realtime subscription for new messages
    const channel = supabase
      .channel(`messages_${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload) => {
          loadSingleMessage(payload.new.id)
        }
      )
      .subscribe()

    // Set up typing indicators
    const typingChannel = supabase
      .channel(`typing_${conversationId}`)
      .on('broadcast', { event: 'typing' }, (payload) => {
        if (payload.payload.sender_id !== user?.id) {
          setOtherUserTyping(payload.payload.is_typing)
          if (payload.payload.is_typing) {
            setTimeout(() => setOtherUserTyping(false), 3000)
          }
        }
      })
      .subscribe()

    return () => {
      channel.unsubscribe()
      typingChannel.unsubscribe()
    }
  }, [conversation, user])

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const loadConversation = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push('/auth')
        return
      }

      setUser(user)

      // Load conversation with related data
      const { data: convoData, error: convoError } = await supabase
        .from('conversations')
        .select('*')
        .eq('id', conversationId)
        .single()

      if (convoError) throw convoError

      // Load buyer and seller profiles
      const { data: buyerProfile } = await supabase
        .from('profiles')
        .select('business_name, contact_person')
        .eq('id', convoData.buyer_id)
        .single()

      const { data: sellerProfile } = await supabase
        .from('profiles')
        .select('business_name, contact_person')
        .eq('id', convoData.seller_id)
        .single()

      // Load listing
      const { data: listing } = await supabase
        .from('listings')
        .select('id, title, price_usd')
        .eq('id', convoData.listing_id)
        .maybeSingle()

      const enrichedConvo = {
        ...convoData,
        buyer: buyerProfile,
        seller: sellerProfile,
        listing: listing
      }

      setConversation(enrichedConvo)

      // Load messages
      await loadMessages(conversationId, user.id)

    } catch (error) {
      console.error('Error loading conversation:', error)
      router.push('/chat')
    } finally {
      setLoading(false)
    }
  }

  const loadMessages = async (convId: string, userId: string) => {
    try {
      const { data: messagesData, error } = await supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', convId)
        .order('created_at', { ascending: true })

      if (error) throw error

      // Get sender names for all messages
      const senderIds = [...new Set(messagesData?.map(m => m.sender_id) || [])]
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, contact_person, business_name')
        .in('id', senderIds)

      const profileMap = new Map(profiles?.map(p => [p.id, p]) || [])

      const enrichedMessages = messagesData?.map(msg => ({
        ...msg,
        sender_name: profileMap.get(msg.sender_id)?.contact_person || 
                     profileMap.get(msg.sender_id)?.business_name || 'Unknown'
      })) || []

      setMessages(enrichedMessages)

      // Mark messages as read
      await markMessagesAsRead(convId, userId)
    } catch (error) {
      console.error('Error loading messages:', error)
    }
  }

  const loadSingleMessage = async (messageId: string) => {
    try {
      const { data: messageData } = await supabase
        .from('messages')
        .select('*')
        .eq('id', messageId)
        .single()

      if (!messageData) return

      const { data: senderProfile } = await supabase
        .from('profiles')
        .select('contact_person, business_name')
        .eq('id', messageData.sender_id)
        .single()

      const enrichedMessage = {
        ...messageData,
        sender_name: senderProfile?.contact_person || senderProfile?.business_name || 'Unknown'
      }

      setMessages(prev => {
        const exists = prev.find(m => m.id === messageId)
        if (exists) return prev
        return [...prev, enrichedMessage].sort((a, b) => 
          new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
        )
      })
    } catch (error) {
      console.error('Error loading single message:', error)
    }
  }

  const markMessagesAsRead = async (convId: string, userId: string) => {
    try {
      await supabase
        .from('messages')
        .update({ read_at: new Date().toISOString() })
        .eq('conversation_id', convId)
        .neq('sender_id', userId)
        .is('read_at', null)
    } catch (error) {
      console.error('Error marking messages as read:', error)
    }
  }

  const handleSendMessage = async () => {
    if (!messageText.trim() || sending || !user) return

    setSending(true)
    try {
      const { error } = await supabase
        .from('messages')
        .insert({
          conversation_id: conversationId,
          sender_id: user.id,
          content: messageText.trim(),
        })

      if (error) throw error

      // Update conversation updated_at
      await supabase
        .from('conversations')
        .update({ updated_at: new Date().toISOString() })
        .eq('id', conversationId)

      setMessageText('')
      sendTypingIndicator(false)
    } catch (error) {
      console.error('Error sending message:', error)
      alert('Failed to send message. Please try again.')
    } finally {
      setSending(false)
    }
  }

  const handleTyping = (text: string) => {
    setMessageText(text)

    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current)
    }

    if (text.trim()) {
      sendTypingIndicator(true)
      typingTimeoutRef.current = setTimeout(() => {
        sendTypingIndicator(false)
      }, 1000)
    } else {
      sendTypingIndicator(false)
    }
  }

  const sendTypingIndicator = (isTyping: boolean) => {
    if (!user) return
    supabase
      .channel(`typing_${conversationId}`)
      .send({
        type: 'broadcast',
        event: 'typing',
        payload: { sender_id: user.id, is_typing: isTyping }
      })
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSendMessage()
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    )
  }

  if (!conversation) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Conversation not found</p>
      </div>
    )
  }

  const isUserBuyer = conversation.buyer_id === user?.id
  const otherUserProfile = isUserBuyer ? conversation.seller : conversation.buyer
  const otherUserName = otherUserProfile?.business_name || otherUserProfile?.contact_person || 'User'

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 px-4 py-4">
        <div className="max-w-4xl mx-auto flex items-center gap-4">
          <button
            onClick={() => router.push('/chat')}
            className="p-2 hover:bg-gray-100 rounded-full transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="flex-1">
            <h1 className="font-semibold text-gray-900">{otherUserName}</h1>
            {conversation.listing && (
              <p className="text-sm text-gray-600">
                Re: {conversation.listing.title}
              </p>
            )}
          </div>
          {conversation.listing?.price_usd && (
            <div className="text-right">
              <p className="text-lg font-bold text-blue-600">
                ${conversation.listing.price_usd.toLocaleString()}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto">
        <div className="max-w-4xl mx-auto px-4 py-6">
          {messages.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500">No messages yet. Start the conversation!</p>
            </div>
          ) : (
            <div className="space-y-4">
              {messages.map((message) => {
                const isOwnMessage = message.sender_id === user?.id
                return (
                  <div
                    key={message.id}
                    className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}
                  >
                    <div className={`max-w-[70%] ${isOwnMessage ? 'text-right' : 'text-left'}`}>
                      {!isOwnMessage && (
                        <p className="text-xs text-gray-500 mb-1">{message.sender_name}</p>
                      )}
                      <div
                        className={`rounded-lg px-4 py-2 ${
                          isOwnMessage
                            ? 'bg-blue-600 text-white'
                            : 'bg-white text-gray-900 border border-gray-200'
                        }`}
                      >
                        <p className="whitespace-pre-wrap break-words">{message.content}</p>
                      </div>
                      <p className="text-xs text-gray-400 mt-1">
                        {new Date(message.created_at).toLocaleTimeString([], {
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </p>
                    </div>
                  </div>
                )
              })}
              {otherUserTyping && (
                <div className="flex justify-start">
                  <div className="bg-white border border-gray-200 rounded-lg px-4 py-2">
                    <div className="flex gap-1">
                      <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></span>
                      <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></span>
                      <span className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></span>
                    </div>
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>
          )}
        </div>
      </div>

      {/* Input */}
      <div className="bg-white border-t border-gray-200 px-4 py-4">
        <div className="max-w-4xl mx-auto flex gap-2">
          <input
            type="text"
            value={messageText}
            onChange={(e) => handleTyping(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type a message..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={sending}
          />
          <button
            onClick={handleSendMessage}
            disabled={!messageText.trim() || sending}
            className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <Send className="w-4 h-4" />
            {sending ? 'Sending...' : 'Send'}
          </button>
        </div>
      </div>
    </div>
  )
}
