export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-lg shadow-sm p-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-6">Privacy Policy</h1>
          
          <div className="prose prose-lg max-w-none space-y-6 text-gray-700">
            <p>Last updated: December 2024</p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8">Information We Collect</h2>
            <p>
              We collect information you provide directly to us, such as when you create an account, 
              post a listing, or communicate with other users through our platform.
            </p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8">How We Use Your Information</h2>
            <p>
              We use the information we collect to provide, maintain, and improve our services, 
              to communicate with you, and to protect our users and platform.
            </p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8">Information Sharing</h2>
            <p>
              We do not sell your personal information. We may share your information with service 
              providers who help us operate our platform, or when required by law.
            </p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8">Data Security</h2>
            <p>
              We implement appropriate technical and organizational measures to protect your personal 
              information against unauthorized access, alteration, or destruction.
            </p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8">Contact Us</h2>
            <p>
              If you have questions about this Privacy Policy, please contact us at{' '}
              <a href="mailto:mechanicpart247@gmail.com" className="text-blue-600 hover:text-blue-700">
                mechanicpart247@gmail.com
              </a>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
