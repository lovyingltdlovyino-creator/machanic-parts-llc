import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    // Hide footer on mobile screens (both web and native) to keep UI clean
    final width = MediaQuery.of(context).size.width;
    // Hide footer on all mobile screens regardless of platform
    if (width < 700) {
      return const SizedBox.shrink();
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brand(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(onPressed: () => context.go('/about'), child: const Text('About Us')),
                        TextButton(onPressed: () => context.go('/contact'), child: const Text('Contact Us')),
                        TextButton(onPressed: () => context.go('/privacy'), child: const Text('Privacy Policy')),
                        TextButton(onPressed: () => context.go('/terms'), child: const Text('Terms of Service')),
                        ElevatedButton(
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
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Text(
                  '© $year Mechanic Part LLC. All rights reserved.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
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

  // Removed long sections; footer now only shows navigation links.
}
