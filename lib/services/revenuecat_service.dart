import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TargetPlatform; 
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  bool _initialized = false;

  Future<void> initialize(String iosPublicSdkKey) async {
    if (kIsWeb) return; // not supported on web
    // Only configure on iOS for now
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (iosPublicSdkKey.isEmpty) return;

    await Purchases.setLogLevel(LogLevel.warn);
    final configuration = PurchasesConfiguration(iosPublicSdkKey);
    await Purchases.configure(configuration);
    _initialized = true;
  }

  Future<void> identify(String appUserId) async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (appUserId.isEmpty) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (_) {}
  }

  Future<void> logout() async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  Future<Offerings?> getOfferings() async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  Future<CustomerInfo?> purchasePackage(Package pkg) async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      // Use dynamic to support multiple SDK shapes
      final dynamic result = await Purchases.purchasePackage(pkg);
      // Newer SDKs return PurchaseResult with .customerInfo
      try {
        final CustomerInfo info = result.customerInfo as CustomerInfo;
        return info;
      } catch (_) {
        // Older SDKs returned CustomerInfo directly
        if (result is CustomerInfo) return result as CustomerInfo;
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<CustomerInfo?> restorePurchases() async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await Purchases.restorePurchases();
    } catch (_) {
      return null;
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }
}
