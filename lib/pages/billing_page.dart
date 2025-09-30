import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _supabase = Supabase.instance.client;

  String _term = 'monthly';
  bool _loadingCheckout = false;
  bool _loadingPortal = false;
  String? _activePlanId; // null or 'free' means free
  String? _subscriptionStatus;
  Map<String, int>? _priceCents; // planId -> cents
  String? _currency; // e.g., 'usd'

  // Monthly USD prices (display only). Multi-month discounts: 3m -5%, 6m -10%, 12m -15%.
  final Map<String, double> _monthlyUsd = const {
    'basic': 15.0,
    'premium': 30.0,
    'vip': 46.0,
    'vip_gold': 59.0,
  };

  final List<Map<String, dynamic>> _planDefs = const [
    {
      'id': 'free',
      'name': 'Free',
      'emoji': '✅',
      'highlights': [
        'Limited ads views',
        'Appear in Others',
      ],
      'features': [
        'Up to 2 active listings (admin-adjustable)',
        'Community access',
      ],
    },
    {
      'id': 'basic',
      'name': 'Basic',
      'emoji': '',
      'highlights': [
        '2x more clients',
        'Full listings in Others',
      ],
      'features': [
        'Up to 5 active listings',
        'Standard visibility',
      ],
    },
    {
      'id': 'premium',
      'name': 'Premium',
      'emoji': '✨',
      'highlights': [
        '5x more clients',
        'Boosts + Featured slots',
      ],
      'features': [
        'Up to 20 active listings',
        'Basic analytics',
      ],
    },
    {
      'id': 'vip',
      'name': 'VIP',
      'emoji': '👑',
      'highlights': [
        '7x more clients',
        'Lead generation access',
      ],
      'features': [
        'Up to 50 active listings',
        'Advanced analytics',
        'Bulk upload',
      ],
    },
    {
      'id': 'vip_gold',
      'name': 'VIP Gold',
      'emoji': '🥇',
      'highlights': [
        '10x more clients',
        'Priority placement',
      ],
      'features': [
        'Up to 100 active listings',
        'Advanced analytics',
        'Priority placement + Lead gen',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
    _loadLivePrices();
    // Handle Stripe/Portal return params from hash fragment
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleReturnParams());
  }

  Future<void> _loadCurrentPlan() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final resp = await _supabase
          .from('profiles')
          .select('active_plan_id, subscription_status')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _activePlanId = (resp?['active_plan_id'] as String?) ?? 'free';
          _subscriptionStatus = resp?['subscription_status'] as String?;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadLivePrices() async {
    try {
      final resp = await _supabase.functions.invoke('getPlanPrices', body: { 'term': _term });
      final data = resp.data as Map?;
      if (data == null) return;
      final prices = (data['prices'] as Map?) ?? {};
      final map = <String, int>{};
      String? currency;
      for (final entry in prices.entries) {
        final planId = entry.key.toString();
        final info = entry.value as Map?;
        final unit = info?['unit_amount'];
        if (unit is int) map[planId] = unit;
        currency ??= (info?['currency'] as String?);
      }
      if (mounted) setState(() { _priceCents = map; _currency = currency; });
    } catch (_) {
      // ignore; UI will fallback
    }
  }

  Future<void> _pollProfileUpdate() async {
    // Poll a few times to allow webhook to update profile
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      await _loadCurrentPlan();
      if (((_activePlanId ?? 'free') != 'free')) break;
    }
  }

  void _handleReturnParams() {
    try {
      final frag = Uri.base.fragment; // e.g. '/billing?success=1'
      if (!frag.contains('?')) return;
      final uri = Uri.parse(frag);
      final qp = uri.queryParameters;
      if (qp.containsKey('success')) {
        _showSnack('Payment successful');
        _loadCurrentPlan();
        _pollProfileUpdate();
      } else if (qp.containsKey('canceled')) {
        _showSnack('Checkout canceled');
      } else if (qp.containsKey('portal')) {
        _showSnack('Returned from billing portal');
        _loadCurrentPlan();
      }
      if (mounted) context.go('/billing');
    } catch (_) {
      // ignore
    }
  }

  double _termPrice(String planId, String term) {
    final base = _monthlyUsd[planId];
    if (base == null) return 0;
    switch (term) {
      case 'monthly':
        return base;
      case 'quarterly':
        return base * 3 * 0.95;
      case 'semiannual':
        return base * 6 * 0.90;
      case 'annual':
        return base * 12 * 0.85;
      default:
        return base;
    }
  }

  String _formatPrice(String planId) {
    final cents = _priceCents?[planId];
    if (cents != null) {
      final value = (cents / 100).toStringAsFixed(2);
      switch ((_currency ?? 'usd').toLowerCase()) {
        case 'usd':
          return '\$' + value;
        case 'gbp':
          return '£' + value;
        case 'eur':
          return '€' + value;
        default:
          return '${(_currency ?? '').toUpperCase()} $value';
      }
    }
    // Fallback using static prices
    return '\$' + _termPrice(planId, _term).toStringAsFixed(2);
  }

  Future<void> _startCheckout(String planId) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _showSnack('On iOS, purchases are managed via RevenueCat.');
      return;
    }
    setState(() => _loadingCheckout = true);
    try {
      final resp = await _supabase.functions.invoke(
        'createCheckoutSession',
        body: {
          'plan_id': planId,
          'term': _term,
        },
      );
      final data = resp.data;
      if (data is Map && data['checkout_url'] is String) {
        final url = Uri.parse(data['checkout_url'] as String);
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } else {
        _showSnack('Failed to start checkout.');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingCheckout = false);
    }
  }

  Future<void> _openPortal() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _showSnack('On iOS, manage subscription in app via RevenueCat.');
      return;
    }
    setState(() => _loadingPortal = true);
    try {
      final resp = await _supabase.functions.invoke('createBillingPortal');
      final data = resp.data;
      if (data is Map && data['portal_url'] is String) {
        final url = Uri.parse(data['portal_url'] as String);
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } else {
        _showSnack('Failed to open customer portal.');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingPortal = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1200 ? 4 : width >= 900 ? 3 : width >= 600 ? 2 : 1;

    final termLabels = const {
      'monthly': '1 month',
      'quarterly': '3 months',
      'semiannual': '6 months',
      'annual': '12 months',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (isIOS) ...[
              Card(
                color: Colors.amber.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'iOS purchases are managed via RevenueCat. This screen is for Web/Android (Stripe).',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/paywall'),
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Open iOS Paywall'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    _activePlanId == null || _activePlanId == 'free'
                        ? 'Current Plan: Free'
                        : 'Current Plan: ${_activePlanId!.toUpperCase()} (${_subscriptionStatus ?? 'active'})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingPortal ? null : _openPortal,
                  icon: _loadingPortal
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.manage_accounts),
                  label: const Text('Manage Billing'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Term toggle
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ['monthly','quarterly','semiannual','annual'])
                  ChoiceChip(
                    label: Text(termLabels[t]!),
                    selected: _term == t,
                    onSelected: (_) { setState(() => _term = t); _loadLivePrices(); },
                    selectedColor: Colors.green.shade100,
                    labelStyle: TextStyle(
                      color: _term == t ? Colors.green.shade900 : null,
                      fontWeight: _term == t ? FontWeight.w600 : FontWeight.normal,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),

            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final plan in _planDefs)
                  _PlanCard(
                    id: plan['id'],
                    name: plan['name'],
                    emoji: plan['emoji'],
                    highlights: List<String>.from(plan['highlights'] as List),
                    features: List<String>.from(plan['features'] as List),
                    priceDisplay: plan['id'] == 'free'
                        ? 'Free'
                        : _formatPrice(plan['id']),
                    termLabel: termLabels[_term]!,
                    isCurrent: (_activePlanId == null || _activePlanId == 'free')
                        ? plan['id'] == 'free'
                        : _activePlanId == plan['id'],
                    onBuy: plan['id'] == 'free'
                        ? () => _showSnack('Free plan is automatic. Cancel any paid plan to return to Free.')
                        : () => _startCheckout(plan['id']),
                    loading: _loadingCheckout,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String id;
  final String name;
  final String emoji;
  final List<String> highlights;
  final List<String> features;
  final String priceDisplay;
  final String termLabel;
  final bool isCurrent;
  final VoidCallback onBuy;
  final bool loading;

  const _PlanCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.highlights,
    required this.features,
    required this.priceDisplay,
    required this.termLabel,
    required this.isCurrent,
    required this.onBuy,
    required this.loading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = id == 'free';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (emoji.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            for (final h in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(h, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (!isFree) ...[
              Text(priceDisplay, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(termLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
            ] else ...[
              Text(priceDisplay, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            const Divider(),
            const Text('Features', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: features.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(features[i], style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isCurrent || loading ? null : onBuy,
                icon: loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isFree ? Icons.check_circle_outline : Icons.shopping_cart_outlined),
                label: Text(isCurrent ? (isFree ? 'Current (Free)' : 'Current Plan') : (isFree ? 'About Free' : 'Buy $name')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
