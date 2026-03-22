import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class IAPDiagnosticPage extends StatefulWidget {
  const IAPDiagnosticPage({super.key});

  @override
  State<IAPDiagnosticPage> createState() => _IAPDiagnosticPageState();
}

class _IAPDiagnosticPageState extends State<IAPDiagnosticPage> {
  final List<String> _logs = [];
  bool _testing = false;

  void _log(String message) {
    setState(() {
      _logs.add(
          '[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    });
    debugPrint('[IAP Diagnostic] $message');
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _logs.clear();
      _testing = true;
    });

    try {
      // 1. Check platform
      _log('Platform: ${defaultTargetPlatform.toString()}');
      _log('Is Web: $kIsWeb');

      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        _log('❌ ERROR: Not on iOS platform');
        return;
      }
      _log('✅ Running on iOS');

      // 2. Check if API key is set (from environment)
      const apiKey = String.fromEnvironment('REVENUECAT_IOS_PUBLIC_SDK_KEY',
          defaultValue: '');
      if (apiKey.isEmpty) {
        _log('❌ ERROR: REVENUECAT_IOS_PUBLIC_SDK_KEY not set');
        _log('   This should be set via --dart-define during build');
      } else {
        _log('✅ API Key is set: ${apiKey.substring(0, 10)}...');
      }

      // 3. Try to get isConfigured status
      _log('Checking if RevenueCat is configured...');
      try {
        final isConfigured = await Purchases.isConfigured;
        _log('RevenueCat isConfigured: $isConfigured');
        if (!isConfigured) {
          _log('❌ ERROR: RevenueCat is NOT configured');
          _log('   Check if initialize() was called in main.dart');
          return;
        }
        _log('✅ RevenueCat is configured');
      } catch (e) {
        _log('⚠️ Could not check configuration status: $e');
      }

      // 4. Try to get app user ID
      try {
        final appUserId = await Purchases.appUserID;
        _log('App User ID: $appUserId');
      } catch (e) {
        _log('⚠️ Could not get app user ID: $e');
      }

      // 5. Try to get offerings
      _log('');
      _log('=== FETCHING OFFERINGS ===');
      try {
        final offerings = await Purchases.getOfferings();
        _log('Offerings fetched successfully');
        _log('All offerings: ${offerings.all.keys.toList()}');
        _log('Current offering ID: ${offerings.current?.identifier ?? "NONE"}');

        if (offerings.current == null) {
          _log('❌ ERROR: No current offering set');
          _log('   Go to RevenueCat dashboard and set a "Current" offering');
          return;
        }

        _log('✅ Current offering: ${offerings.current!.identifier}');
        _log(
            'Available packages: ${offerings.current!.availablePackages.length}');

        if (offerings.current!.availablePackages.isEmpty) {
          _log('❌ ERROR: Current offering has NO packages');
          _log('   Add packages to the "default" offering in RevenueCat');
          return;
        }

        _log('');
        _log('=== PACKAGES ===');
        for (var pkg in offerings.current!.availablePackages) {
          final product = pkg.storeProduct;
          _log('Package: ${pkg.identifier}');
          _log('  Product ID: ${product.identifier}');
          _log('  Title: ${product.title}');
          _log('  Price: ${product.priceString}');
          _log('  Description: ${product.description}');
          _log('---');
        }

        _log('');
        _log('✅✅✅ DIAGNOSTICS PASSED! ✅✅✅');
        _log('RevenueCat is working correctly!');
      } catch (e, stack) {
        _log('❌❌❌ FATAL ERROR FETCHING OFFERINGS ❌❌❌');
        _log('Error: $e');
        _log('Stack trace:');
        _log(stack.toString());

        final errStr = e.toString().toLowerCase();
        if (errStr.contains('not initialized') ||
            errStr.contains('configure')) {
          _log('');
          _log('💡 FIX: RevenueCat not initialized properly');
          _log(
              '   Check main.dart: await RevenueCatService.instance.initialize(apiKey)');
        } else if (errStr.contains('api key') ||
            errStr.contains('invalid') ||
            errStr.contains('401')) {
          _log('');
          _log('💡 FIX: Invalid API Key');
          _log('   1. Check RevenueCat dashboard for correct iOS API key');
          _log('   2. Set REVENUECAT_IOS_PUBLIC_SDK_KEY in Codemagic env vars');
        } else if (errStr.contains('network') ||
            errStr.contains('connection')) {
          _log('');
          _log('💡 FIX: Network issue');
          _log('   Check internet connection');
        } else if (errStr.contains('product') || errStr.contains('store')) {
          _log('');
          _log('💡 FIX: Product configuration issue');
          _log(
              '   1. Check all product IDs in RevenueCat match App Store Connect');
          _log(
              '   2. Ensure Paid Apps Agreement is signed in App Store Connect');
        }
      }

      // 6. Try to get customer info
      _log('');
      _log('=== CUSTOMER INFO ===');
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        _log(
            'Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
        _log(
            'All entitlements: ${customerInfo.entitlements.all.keys.toList()}');
      } catch (e) {
        _log('⚠️ Could not get customer info: $e');
      }
    } catch (e, stack) {
      _log('❌ Unexpected error: $e');
      _log('Stack: $stack');
    } finally {
      setState(() {
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IAP Diagnostics'),
        actions: [
          if (!_testing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _runDiagnostics,
              tooltip: 'Run Diagnostics',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_logs.isEmpty && !_testing)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bug_report, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'IAP Diagnostics',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Run diagnostics to check RevenueCat configuration',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _runDiagnostics,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run Diagnostics'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color? color;
                  if (log.contains('✅')) {
                    color = Colors.green[700];
                  } else if (log.contains('❌')) {
                    color = Colors.red[700];
                  } else if (log.contains('⚠️')) {
                    color = Colors.orange[700];
                  } else if (log.contains('💡')) {
                    color = Colors.blue[700];
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_testing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          if (_logs.isNotEmpty && !_testing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _runDiagnostics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Run Again'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
