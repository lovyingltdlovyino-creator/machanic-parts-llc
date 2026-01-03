'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Plus, Edit, Trash2, Eye, EyeOff } from 'lucide-react'

interface BlogPost {
  id: string
  title: string
  slug: string
  published: boolean
  published_at: string | null
  views: number
  created_at: string
}

export default function BlogManagementPage() {
  const [posts, setPosts] = useState<BlogPost[]>([])
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editingPost, setEditingPost] = useState<BlogPost | null>(null)
  const [formData, setFormData] = useState({
    title: '',
    slug: '',
    content: '',
    excerpt: '',
    featured_image_url: '',
    published: false
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
      await loadPosts()
    } catch (error) {
      console.error('Error:', error)
      router.push('/')
    } finally {
      setLoading(false)
    }
  }

  const loadPosts = async () => {
    const { data, error } = await supabase
      .from('blog_posts')
      .select('id, title, slug, published, published_at, views, created_at')
      .order('created_at', { ascending: false })

    if (error) {
      console.error('Error loading posts:', error)
    } else if (data) {
      setPosts(data)
    }
  }

  const generateSlug = (title: string) => {
    return title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const postData = {
        ...formData,
        slug: formData.slug || generateSlug(formData.title),
        author_id: user.id,
        published_at: formData.published ? new Date().toISOString() : null
      }

      if (editingPost) {
        const { error } = await supabase
          .from('blog_posts')
          .update(postData)
          .eq('id', editingPost.id)
        
        if (error) throw error
        alert('Post updated successfully')
      } else {
        const { error } = await supabase
          .from('blog_posts')
          .insert([postData])
        
        if (error) throw error
        alert('Post created successfully')
      }
      
      setShowForm(false)
      setEditingPost(null)
      setFormData({
        title: '',
        slug: '',
        content: '',
        excerpt: '',
        featured_image_url: '',
        published: false
      })
      await loadPosts()
    } catch (error: any) {
      console.error('Error saving post:', error)
      alert(`Failed to save post: ${error.message}`)
    }
  }

  const handleEdit = async (post: BlogPost) => {
    const { data, error } = await supabase
      .from('blog_posts')
      .select('*')
      .eq('id', post.id)
      .single()

    if (error || !data) {
      alert('Failed to load post details')
      return
    }

    setEditingPost(post)
    setFormData({
      title: data.title,
      slug: data.slug,
      content: data.content || '',
      excerpt: data.excerpt || '',
      featured_image_url: data.featured_image_url || '',
      published: data.published
    })
    setShowForm(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this post?')) return
    
    const { error } = await supabase
      .from('blog_posts')
      .delete()
      .eq('id', id)
    
    if (error) {
      console.error('Error deleting post:', error)
      alert('Failed to delete post')
    } else {
      alert('Post deleted successfully')
      await loadPosts()
    }
  }

  const togglePublished = async (post: BlogPost) => {
    const { error } = await supabase
      .from('blog_posts')
      .update({ 
        published: !post.published,
        published_at: !post.published ? new Date().toISOString() : null
      })
      .eq('id', post.id)
    
    if (error) {
      console.error('Error toggling post:', error)
      alert('Failed to update post status')
    } else {
      await loadPosts()
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
          <h1 className="text-3xl font-bold text-gray-900">Blog Management</h1>
          <button
            onClick={() => {
              setShowForm(!showForm)
              setEditingPost(null)
              setFormData({
                title: '',
                slug: '',
                content: '',
                excerpt: '',
                featured_image_url: '',
                published: false
              })
            }}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-4 h-4" />
            New Post
          </button>
        </div>

        {showForm && (
          <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
            <h2 className="text-xl font-bold mb-4">{editingPost ? 'Edit Post' : 'Create Post'}</h2>
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
                <label className="block text-sm font-medium text-gray-700 mb-2">Slug</label>
                <input
                  type="text"
                  value={formData.slug}
                  onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  placeholder="auto-generated-from-title"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Excerpt</label>
                <textarea
                  value={formData.excerpt}
                  onChange={(e) => setFormData({ ...formData, excerpt: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  rows={2}
                  placeholder="Brief description for listing pages"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Content * (HTML supported)</label>
                <textarea
                  value={formData.content}
                  onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg font-mono text-sm"
                  rows={15}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Featured Image URL</label>
                <input
                  type="url"
                  value={formData.featured_image_url}
                  onChange={(e) => setFormData({ ...formData, featured_image_url: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={formData.published}
                  onChange={(e) => setFormData({ ...formData, published: e.target.checked })}
                  className="rounded"
                />
                <label className="text-sm font-medium text-gray-700">Published</label>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  {editingPost ? 'Update' : 'Create'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowForm(false)
                    setEditingPost(null)
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
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Views</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {posts.map((post) => (
                <tr key={post.id}>
                  <td className="px-6 py-4 text-sm text-gray-900">{post.title}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">{post.views}</td>
                  <td className="px-6 py-4 text-sm">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      post.published ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'
                    }`}>
                      {post.published ? 'Published' : 'Draft'}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-500">
                    {new Date(post.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 text-sm text-right">
                    <button
                      onClick={() => togglePublished(post)}
                      className="text-gray-600 hover:text-gray-900 mr-3"
                      title={post.published ? 'Unpublish' : 'Publish'}
                    >
                      {post.published ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                    <button
                      onClick={() => handleEdit(post)}
                      className="text-blue-600 hover:text-blue-900 mr-3"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDelete(post.id)}
                      className="text-red-600 hover:text-red-900"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {posts.length === 0 && (
            <div className="text-center py-12">
              <p className="text-gray-500">No blog posts yet. Create your first post!</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
