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
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 32,
                        width: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 32,
                            width: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0052CC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.build_rounded, color: Colors.white, size: 18),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Mechanic Part LLC',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C2C2C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Navigation Links - Centered
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFooterLink(context, 'About Us', '/about'),
                    _buildFooterDivider(),
                    _buildFooterLink(context, 'Contact Us', '/contact'),
                    _buildFooterDivider(),
                    _buildFooterLink(context, 'Privacy Policy', '/privacy'),
                    _buildFooterDivider(),
                    _buildFooterLink(context, 'Terms of Service', '/terms'),
                  ],
                ),
                const SizedBox(height: 16),
                
                // CTA Button
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => context.go('/auth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Become a Seller',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Copyright - Centered
                Text(
                  '© $year Mechanic Part LLC. All rights reserved.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String label, String route) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterDivider() {
    return Text(
      '•',
      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
    );
  }

  // Removed long sections; footer now only shows navigation links.
}
