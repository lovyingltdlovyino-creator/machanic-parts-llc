import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/footer.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          color: const Color(0xFF0052CC),
        ),
        title: Text(
          'Contact Us',
          style: GoogleFonts.poppins(
            color: const Color(0xFF2C2C2C),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Section with modern gradient
            Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 48 : 80,
                horizontal: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0052CC),
                    const Color(0xFF0066FF),
                    const Color(0xFF00897B),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          size: isMobile ? 48 : 64,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Get in Touch',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isMobile ? 32 : 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "We're here to help and answer any questions you might have",
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Contact Cards Section
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your preferred way to reach us',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Contact Cards Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            children: [
                              _modernContactCard(
                                context,
                                icon: Icons.email_rounded,
                                title: 'Email Support',
                                subtitle: 'support@mechanicpart.com',
                                description: 'Send us an email anytime',
                                color: const Color(0xFF0052CC),
                                onTap: () => launchUrl(Uri.parse('mailto:support@mechanicpart.com')),
                                width: isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 2,
                              ),
                              _modernContactCard(
                                context,
                                icon: Icons.phone_rounded,
                                title: 'Phone Support',
                                subtitle: '+1 (XXX) XXX-XXXX',
                                description: 'Mon-Fri from 8am to 6pm',
                                color: const Color(0xFF00897B),
                                onTap: () => launchUrl(Uri.parse('tel:+1XXXXXXXXXX')),
                                width: isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 2,
                              ),
                              _modernContactCard(
                                context,
                                icon: Icons.location_on_rounded,
                                title: 'Visit Us',
                                subtitle: '2619 Old North Sharon Amity Rd',
                                description: 'Charlotte, NC 28205, United States',
                                color: const Color(0xFFD72638),
                                onTap: () => launchUrl(Uri.parse('https://maps.google.com/?q=2619+Old+North+Sharon+Amity+Rd,Charlotte,NC+28205')),
                                width: constraints.maxWidth,
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Call-to-Action Section
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0052CC).withOpacity(0.1),
                              const Color(0xFF00897B).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF0052CC).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Ready to Start Selling?',
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C2C2C),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Join our marketplace and reach thousands of car owners and mechanics',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => context.go('/auth'),
                                  icon: const Icon(Icons.store_rounded),
                                  label: const Text('Become a Seller'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0052CC),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => context.go('/home'),
                                  icon: const Icon(Icons.home_rounded),
                                  label: const Text('Back to Home'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0052CC),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF0052CC),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _modernContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required double width,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
