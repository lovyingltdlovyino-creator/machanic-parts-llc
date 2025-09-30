import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Us',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'At Mechanic Part LLC, we connect car owners, mechanics, and auto part sellers in one trusted online marketplace. '
                  'Our mission is simple: to make finding and selling car parts easier, faster, and safer.\n\n'
                  'Whether you’re a professional mechanic, a car enthusiast, or someone simply looking for a reliable replacement part, '
                  'our platform gives you access to a wide range of listings from trusted sellers. We are committed to transparency, '
                  'customer trust, and helping people save time and money on quality car parts.',
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
