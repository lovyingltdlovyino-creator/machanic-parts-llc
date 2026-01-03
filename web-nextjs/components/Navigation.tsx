'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Package, MessageSquare, User, LogOut } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'

export function Navigation() {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const [user, setUser] = useState<any>(null)
  const [userType, setUserType] = useState<string>('buyer')

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      setUser(user)
      if (user) {
        supabase
          .from('profiles')
          .select('user_type')
          .eq('id', user.id)
          .single()
          .then(({ data }) => {
            setUserType(data?.user_type || 'buyer')
          })
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
    })

    return () => subscription.unsubscribe()
  }, [supabase])

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
    router.refresh()
  }

  const isActive = (path: string) => pathname === path

  return (
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link href="/" className="flex items-center space-x-2">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">MP</span>
              </div>
              <span className="font-semibold text-lg text-gray-900">Mechanic Part LLC</span>
            </Link>
          </div>

          <div className="flex items-center space-x-4">
            <Link
              href="/"
              className={`flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium ${
                isActive('/') ? 'bg-blue-50 text-blue-600' : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <Home className="w-4 h-4" />
              <span>Browse</span>
            </Link>

            {user && userType === 'seller' && (
              <Link
                href="/my-products"
                className={`flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium ${
                  isActive('/my-products') ? 'bg-blue-50 text-blue-600' : 'text-gray-700 hover:bg-gray-50'
                }`}
              >
                <Package className="w-4 h-4" />
                <span>My Products</span>
              </Link>
            )}

            {user && (
              <>
                <Link href="/" className="text-gray-700 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium">
                  Browse
                </Link>
                <Link href="/blog" className="text-gray-700 hover:text-gray-900 px-3 py-2 rounded-md text-sm font-medium">
                  Blog
                </Link>
                <Link
                  href="/chat"
                  className={`flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium ${
                    isActive('/chat') ? 'bg-blue-50 text-blue-600' : 'text-gray-700 hover:bg-gray-50'
                  }`}
                >
                  <MessageSquare className="w-4 h-4" />
                  <span>Chat</span>
                </Link>

                <Link
                  href="/profile"
                  className={`flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium ${
                    isActive('/profile') ? 'bg-blue-50 text-blue-600' : 'text-gray-700 hover:bg-gray-50'
                  }`}
                >
                  <User className="w-4 h-4" />
                  <span>Profile</span>
                </Link>

                <button
                  onClick={handleSignOut}
                  className="flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  <LogOut className="w-4 h-4" />
                  <span>Sign Out</span>
                </button>
              </>
            )}

            {!user && (
              <Link
                href="/auth"
                className="px-4 py-2 rounded-md text-sm font-medium bg-blue-600 text-white hover:bg-blue-700"
              >
                Sign In
              </Link>
            )}
          </div>
        </div>
      </div>
    </nav>
  )
}
