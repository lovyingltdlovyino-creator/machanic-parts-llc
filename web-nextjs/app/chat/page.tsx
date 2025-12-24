import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function ChatPage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/auth')
  }

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Messages</h1>
        
        <div className="bg-white rounded-lg shadow-sm p-12 text-center">
          <p className="text-gray-500 mb-4">No messages yet.</p>
          <p className="text-sm text-gray-400">
            Start a conversation by contacting a seller from their listing page.
          </p>
        </div>
      </div>
    </div>
  )
}
