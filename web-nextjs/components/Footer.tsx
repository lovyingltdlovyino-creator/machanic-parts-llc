'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'

export function Footer() {
  const currentYear = new Date().getFullYear()
  const [isSeller, setIsSeller] = useState(false)
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    checkUserType()
  }, [])
  
  const checkUserType = async () => {
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      
      if (user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('user_type')
          .eq('id', user.id)
          .maybeSingle()
        
        if (profile?.user_type === 'seller') {
          setIsSeller(true)
        }
      }
    } catch (error) {
      console.error('Error checking user type:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <footer className="bg-gray-50 border-t border-gray-200 mt-auto">
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="flex flex-col items-center space-y-6">
          <div className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-sm">MP</span>
            </div>
            <span className="font-semibold text-gray-900">Mechanic Part LLC</span>
          </div>

          <div className="flex flex-wrap justify-center gap-2 text-sm">
            <Link href="/about" className="text-gray-600 hover:text-gray-900 px-3 py-1">
              About Us
            </Link>
            <span className="text-gray-400">•</span>
            <Link href="/contact" className="text-gray-600 hover:text-gray-900 px-3 py-1">
              Contact Us
            </Link>
            <span className="text-gray-400">•</span>
            <Link href="/privacy" className="text-gray-600 hover:text-gray-900 px-3 py-1">
              Privacy Policy
            </Link>
            <span className="text-gray-400">•</span>
            <Link href="/terms" className="text-gray-600 hover:text-gray-900 px-3 py-1">
              Terms of Service
            </Link>
          </div>

          {!loading && !isSeller && (
            <Link
              href="/auth"
              className="px-6 py-2 rounded-lg bg-blue-600 text-white text-sm font-medium hover:bg-blue-700"
            >
              Become a Seller
            </Link>
          )}

          <p className="text-sm text-gray-600">
            © {currentYear} Mechanic Part LLC. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  )
}
