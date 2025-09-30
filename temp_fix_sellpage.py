from pathlib import Path

path = Path(r"lib/main.dart")
text = path.read_text()
start = text.index("  Widget _buildProfilePrompt() {")
end = text.index("\n  Widget _buildSellerPrompt()", start)
replacement = """  Widget _buildProfilePrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Parts'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Your Profile',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to complete your seller profile before you can create listings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final homeShell = context.findAncestorStateOfType<_HomeShellState>();
                    if (homeShell != null) {
                      homeShell.switchToTab(3);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit),
                  label: Text(
                    'Complete Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Parts'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign In Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to sign in to list items for sale',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
"""
path.write_text(text[:start] + replacement + text[end:])
