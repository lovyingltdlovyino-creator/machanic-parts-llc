import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy Policy', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'Your privacy matters to us. We collect basic information (like name, email, and contact details) when you register or interact on our platform. '
                  'This information is used only to provide services, improve your experience, and ensure secure transactions. We never sell your personal data to third parties.\n\n'
                  'Payments are processed through secure, trusted third-party providers (e.g., Stripe). You may request deletion of your data at any time by contacting our support team. '
                  'For more details, please read our full Privacy Policy (you can expand later with legal wording).',
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
