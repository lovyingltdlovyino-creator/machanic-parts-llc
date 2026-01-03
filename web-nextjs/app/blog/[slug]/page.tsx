'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useParams, useRouter } from 'next/navigation'
import { Calendar, Eye, ArrowLeft } from 'lucide-react'

interface BlogPost {
  id: string
  title: string
  content: string
  featured_image_url: string | null
  published_at: string
  views: number
}

export default function BlogPostPage() {
  const [post, setPost] = useState<BlogPost | null>(null)
  const [loading, setLoading] = useState(true)
  const params = useParams()
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    if (params.slug) {
      loadPost(params.slug as string)
    }
  }, [params.slug])

  const loadPost = async (slug: string) => {
    try {
      const { data, error } = await supabase
        .from('blog_posts')
        .select('*')
        .eq('slug', slug)
        .eq('published', true)
        .maybeSingle()

      if (error) throw error
      if (data) {
        setPost(data)
        // Increment view count
        await supabase
          .from('blog_posts')
          .update({ views: (data.views || 0) + 1 })
          .eq('id', data.id)
      }
    } catch (error) {
      console.error('Error loading blog post:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 py-8 flex items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    )
  }

  if (!post) {
    return (
      <div className="min-h-screen bg-gray-50 py-8">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Post Not Found</h1>
          <button
            onClick={() => router.push('/blog')}
            className="text-blue-600 hover:text-blue-800"
          >
            ← Back to Blog
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <button
          onClick={() => router.push('/blog')}
          className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Blog
        </button>

        <article className="bg-white rounded-lg shadow-sm overflow-hidden">
          {post.featured_image_url && (
            <img
              src={post.featured_image_url}
              alt={post.title}
              className="w-full h-96 object-cover"
            />
          )}
          <div className="p-8">
            <h1 className="text-4xl font-bold text-gray-900 mb-4">{post.title}</h1>
            
            <div className="flex items-center gap-6 text-sm text-gray-500 mb-8 pb-8 border-b border-gray-200">
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4" />
                {new Date(post.published_at).toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric'
                })}
              </div>
              <div className="flex items-center gap-2">
                <Eye className="w-4 h-4" />
                {post.views} views
              </div>
            </div>

            <div 
              className="prose prose-lg max-w-none"
              dangerouslySetInnerHTML={{ __html: post.content }}
            />
          </div>
        </article>
      </div>
    </div>
  )
}
