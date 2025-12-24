'use client'

import { useRouter } from 'next/navigation'
import { Car, Settings, Disc, Zap, Wrench } from 'lucide-react'

const categories = [
  { name: 'Vehicles & Cars', icon: Car, color: 'bg-blue-100 text-blue-600 border-blue-200', type: 'vehicle' },
  { name: 'Engine Parts', icon: Settings, color: 'bg-orange-100 text-orange-600 border-orange-200', type: 'part', category: 'engine' },
  { name: 'Tires & Wheels', icon: Disc, color: 'bg-green-100 text-green-600 border-green-200', type: 'part', category: 'tyres' },
  { name: 'Electronics', icon: Zap, color: 'bg-purple-100 text-purple-600 border-purple-200', type: 'part', category: 'electronics' },
  { name: 'Body Parts', icon: Wrench, color: 'bg-red-100 text-red-600 border-red-200', type: 'part', category: 'body' },
]

export function Categories() {
  const router = useRouter()

  const handleCategoryClick = (category: typeof categories[0]) => {
    // Build search params for filtering
    const params = new URLSearchParams()
    params.set('type', category.type)
    if (category.category) {
      params.set('category', category.category)
    }
    
    // Navigate to search/browse page with filters
    router.push(`/?${params.toString()}`)
  }

  return (
    <div className="px-4 py-8">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-2xl font-bold text-gray-900">Categories</h2>
        <button 
          onClick={() => router.push('/')}
          className="text-green-600 font-semibold hover:text-green-700 transition-colors"
        >
          View All
        </button>
      </div>

      <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide">
        {categories.map((category, index) => {
          const Icon = category.icon
          return (
            <button
              key={index}
              onClick={() => handleCategoryClick(category)}
              className="flex-shrink-0 flex flex-col items-center gap-2 group cursor-pointer"
            >
              <div className={`w-16 h-16 rounded-2xl ${category.color} border-2 flex items-center justify-center shadow-sm group-hover:shadow-md group-hover:scale-105 transition-all`}>
                <Icon className="w-8 h-8" />
              </div>
              <span className="text-xs font-semibold text-gray-700 text-center max-w-[85px] leading-tight">
                {category.name}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
