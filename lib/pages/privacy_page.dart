import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../widgets/footer.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        title: const Text('Privacy Policy'),
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
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
                        'We respect your privacy',
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
                      _section('Information We Collect',
                          'Basic account details like name, email, and contact info when you register or interact with our platform.'),
                      _section('How We Use Your Data',
                          'To provide services, improve your experience, and ensure secure transactions.'),
                      _section('Data Sharing',
                          'We do not sell your personal data. Payments are processed via secure third‑party providers (e.g., Stripe).'),
                      _section('Your Choices',
                          'You can request deletion of your account and data by contacting support. We will honor valid requests promptly.'),
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

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: GoogleFonts.poppins(height: 1.6, color: Colors.grey.shade800)),
        ],
      ),
    );
  }
}
