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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        setState(() { _error = 'RevenueCat purchases are iOS-only in this build.'; });
        return;
      }
      final offerings = await RevenueCatService.instance.getOfferings();
      final customer = await RevenueCatService.instance.getCustomerInfo();
      setState(() {
        _offerings = offerings;
        _customerInfo = customer;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load offerings: $e'; });
    } finally {
      setState(() { _loading = false; });
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
    setState(() { _loading = true; _error = null; });
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      setState(() { _customerInfo = info; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored purchases')));
      }
    } catch (e) {
      setState(() { _error = 'Restore failed: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEntitlements = _customerInfo?.entitlements.active.keys.toList() ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Plan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const Text('Choose a plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_offerings?.current == null || (_offerings?.current?.availablePackages.isEmpty ?? true))
                    const Text('No packages available yet.')
                  else
                    ..._offerings!.current!.availablePackages.map((pkg) {
                      final product = pkg.storeProduct;
                      final title = product.title;
                      final price = product.priceString;
                      final id = pkg.identifier; // rc package id (e.g., monthly, annual)
                      final isActive = activeEntitlements.isNotEmpty; // any entitlement active
                      return Card(
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text('$id  •  $price'),
                          trailing: ElevatedButton(
                            onPressed: isActive ? null : () => _purchase(pkg),
                            child: Text(isActive ? 'Active' : 'Buy'),
                          ),
                        ),
                      );
                    }).toList(),
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
