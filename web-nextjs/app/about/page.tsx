export default function AboutPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-lg shadow-sm p-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-6">About Mechanic Part LLC</h1>
          
          <div className="prose prose-lg max-w-none">
            <p className="text-gray-700 mb-4">
              Welcome to Mechanic Part LLC, your trusted marketplace for quality auto parts. 
              We connect buyers with verified sellers across the country, making it easier than 
              ever to find the parts you need.
            </p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8 mb-4">Our Mission</h2>
            <p className="text-gray-700 mb-4">
              Our mission is to simplify the process of buying and selling auto parts by providing 
              a secure, user-friendly platform that brings together mechanics, parts dealers, and 
              auto enthusiasts.
            </p>

            <h2 className="text-2xl font-bold text-gray-900 mt-8 mb-4">Why Choose Us</h2>
            <ul className="list-disc pl-6 text-gray-700 space-y-2">
              <li>Verified sellers and quality listings</li>
              <li>Secure transactions and buyer protection</li>
              <li>Easy search and filtering tools</li>
              <li>Direct communication with sellers</li>
              <li>Competitive pricing</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
