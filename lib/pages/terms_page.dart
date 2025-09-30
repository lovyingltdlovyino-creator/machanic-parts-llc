import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terms of Service', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'By using our website, you agree to the following:\n\n'
                  '• Eligibility: You must be 18 years or older to use our marketplace.\n'
                  '• User Accounts: You are responsible for keeping your account secure.\n'
                  '• Listings & Transactions: Sellers must provide accurate information. Buyers should review listings before purchase.\n'
                  '• Prohibited Use: Fraudulent activity, fake listings, and abuse of the platform are not allowed.\n'
                  '• Liability: Mechanic Part LLC provides the platform but does not guarantee the condition or quality of third-party listed products.\n'
                  '• Disputes: Issues between buyers and sellers should be resolved directly, though we may step in to assist when needed.\n'
                  '• Changes: We may update these Terms as needed, and continued use of the platform means you accept them.',
                  style: GoogleFonts.poppins(height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
