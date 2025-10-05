import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../widgets/footer.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        title: const Text('Terms of Service'),
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
                  colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Image.asset('assets/images/logo.png', height: 48, fit: BoxFit.contain),
                      ),
                      Text(
                        'Simple terms for a safe marketplace',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
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
                      _bullet('Eligibility', 'You must be 18+ to use the marketplace.'),
                      _bullet('Accounts & Security', 'Keep your login details secure and up to date.'),
                      _bullet('Listings & Transactions', 'Sellers must provide accurate information. Buyers should review listings before purchase.'),
                      _bullet('Prohibited Use', 'No fraud, fake listings, or abuse of the platform.'),
                      _bullet('Liability', 'Mechanic Part LLC provides the platform but does not guarantee third‑party product quality.'),
                      _bullet('Disputes', 'Buyers and sellers should resolve issues directly; we may assist when needed.'),
                      _bullet('Changes', 'We may update these Terms; continued use means you accept them.'),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => context.go('/home'),
                            child: const Text('Back to Home'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/contact'),
                            child: const Text('Contact Support'),
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

  Widget _bullet(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 18)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(color: Colors.black87, height: 1.5),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
