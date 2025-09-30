import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Us', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'We’d love to hear from you!\n\n'
                  'Mechanic Part LLC\n'
                  '2619 Old North Sharon Amity Rd\n'
                  'Charlotte, NC 28205\n'
                  'United States\n\n'
                  'Email: support@mechanicpart.com (replace with your real support email)\n'
                  'Phone: +1 (XXX) XXX-XXXX (optional)\n\n'
                  'For quick assistance, please use the Help Center or Contact Form on our website.',
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
