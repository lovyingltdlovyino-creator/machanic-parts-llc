import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  Offerings? _offerings;
  bool _loading = true;
  String? _error;
  CustomerInfo? _customerInfo;

  // Maps productId prefixes to human-readable tier names
  String _tierForProductId(String id) {
    final lower = id.toLowerCase();
    if (lower.startsWith('basic')) return 'Basic';
    if (lower.startsWith('premium')) return 'Premium';
    if (lower.startsWith('vipgold')) return 'VIP Gold';
    if (lower.startsWith('vip')) return 'VIP';
    return 'Other';
  }

  // Entitlement id per tier based on your dashboard screenshot
  String? _entitlementForTier(String tier) {
    switch (tier) {
      case 'Basic':
        return 'basic_access';
      case 'Premium':
        return 'premium_access';
      case 'VIP':
        return 'vip_access';
      case 'VIP Gold':
        return 'vipgold_access';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        setState(() { 
          _error = 'RevenueCat purchases are iOS-only in this build.';
          _loading = false;
        });
        return;
      }
      
      // Log attempt
      debugPrint('[PaywallPage] Fetching offerings...');
      final offerings = await RevenueCatService.instance.getOfferings();
      debugPrint('[PaywallPage] Offerings fetched: ${offerings?.current?.identifier}');
      
      final customer = await RevenueCatService.instance.getCustomerInfo();
      debugPrint('[PaywallPage] Customer info fetched');
      
      if (offerings == null || offerings.current == null) {
        debugPrint('[PaywallPage] No current offering available');
        setState(() {
          _error = 'Unable to load subscription plans. Please restart the app.';
          _loading = false;
        });
        return;
      }
      
      debugPrint('[PaywallPage] Available packages: ${offerings.current!.availablePackages.length}');
      
      setState(() {
        _offerings = offerings;
        _customerInfo = customer;
        _loading = false;
      });
    } catch (e, stack) {
      // Detailed error logging
      debugPrint('[PaywallPage] Error loading offerings: $e');
      debugPrint('[PaywallPage] Stack trace: $stack');
      
      // Simplify RevenueCat configuration errors for better user experience
      String errorMsg = 'Unable to load subscription plans at this time.';
      final errStr = e.toString().toLowerCase();
      
      if (errStr.contains('configuration') || errStr.contains('products') || errStr.contains('dashboard')) {
        errorMsg = 'Subscription plans are being set up. Please try again in a few minutes or contact support.';
      } else if (errStr.contains('network') || errStr.contains('connection')) {
        errorMsg = 'Network error. Please check your internet connection and try again.';
      } else if (errStr.contains('not initialized')) {
        errorMsg = 'App is initializing. Please try again in a moment.';
      }
      
      setState(() { 
        _error = errorMsg;
        _loading = false;
      });
    }
  }

  Future<void> _purchase(Package pkg) async {
    setState(() { _loading = true; _error = null; });
    try {
      final info = await RevenueCatService.instance.purchasePackage(pkg);
      setState(() { _customerInfo = info; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase successful')));
      }
    } catch (e) {
      setState(() { _error = 'Purchase failed: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _restore() async {
    // Show dialog explaining what will happen
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Purchases'),
        content: const Text(
          'This will restore any previous purchases you made with your Apple ID. You may be asked to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    
    if (shouldContinue != true) return;
    
    setState(() { _loading = true; _error = null; });
    try {
      debugPrint('[PaywallPage] Starting restore purchases...');
      final info = await RevenueCatService.instance.restorePurchases();
      debugPrint('[PaywallPage] Restore complete. Active entitlements: ${info?.entitlements.active.keys ?? "none"}');
      
      setState(() { _customerInfo = info; });
      
      if (mounted && info != null) {
        if (info.entitlements.active.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No previous purchases found.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restored ${info.entitlements.active.length} subscription(s)!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PaywallPage] Restore failed: $e');
      
      String errorMsg = 'Restore failed. Please try again.';
      final errStr = e.toString().toLowerCase();
      
      if (errStr.contains('cancelled') || errStr.contains('cancel')) {
        errorMsg = 'Restore cancelled.';
      } else if (errStr.contains('network')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      }
      
      setState(() { _error = errorMsg; });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEntitlements = _customerInfo?.entitlements.active.keys.toList() ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Plan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            debugPrint('[PaywallPage] Back button pressed');
            // Try to pop, if it fails, nothing happens (we're at root)
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Choose a plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_offerings?.current == null || (_offerings?.current?.availablePackages.isEmpty ?? true)) ...[
                    const Text('No packages available yet.'),
                    const SizedBox(height: 8),
                    const Text(
                      'Tip: In RevenueCat, set a Current offering and add Packages pointing to your iOS products.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ] else ...[
                    // Group packages by productId prefix (basic/premium/vip/vipgold)
                    ...(() {
                      final Map<String, List<Package>> groups = {};
                      for (final pkg in _offerings!.current!.availablePackages) {
                        final dynamic p = pkg.storeProduct;
                        final String pid = (p.identifier ?? p.productIdentifier ?? '').toString();
                        final tier = _tierForProductId(pid);
                        (groups[tier] ??= <Package>[]).add(pkg);
                      }
                      // Preferred tier order
                      const order = ['Basic', 'Premium', 'VIP', 'VIP Gold', 'Other'];
                      final sortedTiers = groups.keys.toList()
                        ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

                      // Helper to sort plans by duration keyword
                      int _rank(String s) {
                        final l = s.toLowerCase();
                        if (l.contains('month') && l.contains('6')) return 30;
                        if (l.contains('quarter')) return 20;
                        if (l.contains('month')) return 10; // monthly
                        if (l.contains('year')) return 40;   // yearly
                        return 99;
                      }

                      final widgets = <Widget>[];
                      for (final tier in sortedTiers) {
                        final ent = _entitlementForTier(tier);
                        final hasActive = ent != null && activeEntitlements.contains(ent);

                        widgets.add(Row(
                          children: [
                            Text(tier, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            if (hasActive) ...[
                              const SizedBox(width: 8),
                              Chip(label: const Text('Active'), backgroundColor: Colors.green.shade100),
                            ],
                          ],
                        ));
                        widgets.add(const SizedBox(height: 8));

                        final pkgs = groups[tier]!..sort((a, b) {
                          final dynamic pa = a.storeProduct;
                          final dynamic pb = b.storeProduct;
                          final String ida = (pa.identifier ?? pa.productIdentifier ?? '').toString();
                          final String idb = (pb.identifier ?? pb.productIdentifier ?? '').toString();
                          return _rank(ida).compareTo(_rank(idb));
                        });

                        widgets.addAll(pkgs.map((pkg) {
                          final dynamic product = pkg.storeProduct;
                          final String title = (product.title ?? '').toString();
                          final String price = (product.priceString ?? '').toString();
                          final String pid = (product.identifier ?? product.productIdentifier ?? '').toString();
                          return Card(
                            child: ListTile(
                              title: Text(title.isNotEmpty ? title : pid),
                              subtitle: Text('$pid  •  $price'),
                              trailing: ElevatedButton(
                                onPressed: hasActive ? null : () => _purchase(pkg),
                                child: Text(hasActive ? 'Active' : 'Buy'),
                              ),
                            ),
                          );
                        }));

                        widgets.add(const SizedBox(height: 16));
                      }
                      return widgets;
                    }()),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Purchases'),
                  ),
                  if (activeEntitlements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Active entitlements:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Wrap(spacing: 8, children: activeEntitlements.map((e) => Chip(label: Text(e))).toList()),
                  ],
                ],
              ),
            ),
    );
  }
}
