import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    final columns = [
                      _about(),
                      _contact(context),
                      _privacy(),
                      _terms(),
                      _sellerCta(context),
                    ];
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _brand(),
                          const SizedBox(height: 24),
                          ...columns.expand((w) => [w, const SizedBox(height: 24)]),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _brand(),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: columns[0]),
                              Expanded(child: columns[1]),
                              Expanded(child: columns[2]),
                              Expanded(child: columns[3]),
                              Expanded(child: columns[4]),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Text(
                  '© $year Mechanic Part LLC. All rights reserved.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() {
    return Row(
      children: [
        // Logo
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/logo.png',
            height: 36,
            width: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 36,
                width: 36,
                decoration: const BoxDecoration(color: Color(0xFF0052CC), shape: BoxShape.circle),
                child: const Icon(Icons.build_rounded, color: Colors.white, size: 20),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Mechanic Part LLC',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C2C2C),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C2C2C),
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: const Color(0xFF4F4F4F)),
    );
  }

  Widget _about() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('About Us'),
        _bodyText(
          'At Mechanic Part LLC, we connect car owners, mechanics, and auto part sellers in one trusted online marketplace. '
          'Our mission is simple: to make finding and selling car parts easier, faster, and safer.\n\n'
          'Whether you’re a professional mechanic, a car enthusiast, or someone simply looking for a reliable replacement part, '
          'our platform gives you access to a wide range of listings from trusted sellers. We are committed to transparency, '
          'customer trust, and helping people save time and money on quality car parts.',
        ),
      ],
    );
  }

  Widget _contact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Contact Us'),
        _bodyText(
          'We’d love to hear from you!\n'
          'Mechanic Part LLC\n'
          '2619 Old North Sharon Amity Rd\n'
          'Charlotte, NC 28205\n'
          'United States',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse('mailto:support@mechanicpart.com')),
              child: const Text('support@mechanicpart.com'),
            ),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('tel:+1XXXXXXXXXX')),
              child: const Text('+1 (XXX) XXX-XXXX'),
            ),
          ],
        ),
        _bodyText('For quick assistance, please use the Help Center or Contact Form on our website.'),
      ],
    );
  }

  Widget _privacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Privacy Policy'),
        _bodyText(
          'Your privacy matters to us. We collect basic information (like name, email, and contact details) when you register or interact on our platform. '
          'This information is used only to provide services, improve your experience, and ensure secure transactions. We never sell your personal data to third parties.\n\n'
          'Payments are processed through secure, trusted third-party providers (e.g., Stripe). You may request deletion of your data at any time by contacting our support team. '
          'For more details, please read our full Privacy Policy.',
        ),
      ],
    );
  }

  Widget _terms() {
    final bullet = '• ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Terms of Service'),
        _bodyText(
          '${bullet}Eligibility: You must be 18 years or older to use our marketplace.\n'
          '${bullet}User Accounts: You are responsible for keeping your account secure.\n'
          '${bullet}Listings & Transactions: Sellers must provide accurate information; buyers should review listings before purchase.\n'
          '${bullet}Prohibited Use: Fraud, fake listings, and abuse are not allowed.\n'
          '${bullet}Liability: Mechanic Part LLC provides the platform but does not guarantee third‑party product quality.\n'
          '${bullet}Disputes: Buyers and sellers should resolve issues directly; we may assist when needed.\n'
          '${bullet}Changes: We may update these Terms; continued use means you accept them.',
        ),
      ],
    );
  }

  Widget _sellerCta(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Become a Seller'),
        _bodyText(
          'Want to reach more customers and grow your business? Join Mechanic Part LLC as a seller today!\n\n'
          '• Create your free account\n'
          '• List your car parts or vehicles in minutes\n'
          '• Get access to buyers searching for reliable parts\n'
          '• Enjoy secure transactions and dedicated seller support',
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => context.go('/auth'),
          child: const Text('Start Selling Now'),
        ),
      ],
    );
  }
}
