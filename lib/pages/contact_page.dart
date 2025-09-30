import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/footer.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Contact Us'),
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
                  colors: [Color(0xFF2E73FF), Color(0xFF00C2FF)],
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
                        'We’d love to hear from you',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
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
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _contactCard(
                            context,
                            icon: Icons.email_outlined,
                            title: 'Email',
                            subtitle: 'support@mechanicpart.com',
                            onTap: () => launchUrl(Uri.parse('mailto:support@mechanicpart.com')),
                          ),
                          _contactCard(
                            context,
                            icon: Icons.phone_outlined,
                            title: 'Phone',
                            subtitle: '+1 (XXX) XXX-XXXX',
                            onTap: () => launchUrl(Uri.parse('tel:+1XXXXXXXXXX')),
                          ),
                          _contactCard(
                            context,
                            icon: Icons.location_on_outlined,
                            title: 'Address',
                            subtitle: '2619 Old North Sharon Amity Rd,\nCharlotte, NC 28205, United States',
                            onTap: () {},
                          ),
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

  Widget _contactCard(BuildContext context, {required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 0,
        color: const Color(0xFFF7FAFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFE6F0FF), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: const Color(0xFF2C6BED)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
