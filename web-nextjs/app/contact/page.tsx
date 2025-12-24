export default function ContactPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-lg shadow-sm p-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-6">Contact Us</h1>
          
          <div className="space-y-6">
            <p className="text-gray-700">
              Have questions or need assistance? We're here to help!
            </p>

            <div>
              <h2 className="text-xl font-semibold text-gray-900 mb-2">Email</h2>
              <p className="text-gray-700">
                <a href="mailto:mechanicpart247@gmail.com" className="text-blue-600 hover:text-blue-700">
                  mechanicpart247@gmail.com
                </a>
              </p>
            </div>

            <div>
              <h2 className="text-xl font-semibold text-gray-900 mb-2">Business Hours</h2>
              <p className="text-gray-700">Monday - Friday: 9:00 AM - 6:00 PM EST</p>
              <p className="text-gray-700">Saturday - Sunday: Closed</p>
            </div>

            <div className="pt-4">
              <p className="text-sm text-gray-600">
                We typically respond to all inquiries within 24-48 hours.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
