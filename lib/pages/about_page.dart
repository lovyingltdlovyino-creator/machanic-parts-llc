import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../widgets/footer.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('About Us'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero
            Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset('assets/images/logo.png', height: 72, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Mechanic Part LLC',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Body
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Our Mission', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'At Mechanic Part LLC, we connect car owners, mechanics, and auto part sellers in one trusted online marketplace. '
                        'Our mission is simple: to make finding and selling car parts easier, faster, and safer.',
                        style: GoogleFonts.poppins(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _featureCard(Icons.search, 'Wide Selection', 'Browse listings from trusted sellers across the country.'),
                          _featureCard(Icons.verified, 'Trusted Sellers', 'We emphasize transparency and customer trust.'),
                          _featureCard(Icons.local_shipping, 'Fast Process', 'Save time and money finding the right parts.'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => context.go('/home'),
                            child: const Text('Back to Home'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/auth'),
                            child: const Text('Become a Seller'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String subtitle) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 0,
        color: const Color(0xFFF7FAFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFE6F0FF), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: const Color(0xFF2C6BED)),
              ),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
