import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanic_part/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('iPad Screenshots', () {
    testWidgets('Navigate and capture screenshots', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      print('=== APP LOADED ===');
      
      // Try to login first if on login page
      try {
        final emailField = find.byType(TextField).first;
        if (emailField.evaluate().isNotEmpty) {
          print('Found login page, attempting login...');
          await tester.enterText(emailField, 'folabiyistar@gmail.com');
          await tester.pumpAndSettle(const Duration(seconds: 1));
          
          final passwordField = find.byType(TextField).at(1);
          await tester.enterText(passwordField, 'Test123');
          await tester.pumpAndSettle(const Duration(seconds: 1));
          
          // Find and tap login button
          final loginBtn = find.text('Login').last;
          await tester.tap(loginBtn);
          await tester.pumpAndSettle(const Duration(seconds: 5));
          print('Login attempted, waiting for home page...');
        }
      } catch (e) {
        print('No login needed or login failed: $e');
      }

      // Screenshot 1: Home/Landing page
      print('Taking screenshot 1: Home');
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await takeScreenshot(binding, '01_home_landing');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Screenshot 2: Scroll down to show more content
      print('Taking screenshot 2: Home scrolled');
      try {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await takeScreenshot(binding, '02_home_scrolled');
      } catch (e) {
        print('Could not scroll: $e');
        await takeScreenshot(binding, '02_home_alternate');
      }

      // Screenshot 3: Tap first product to see details
      print('Taking screenshot 3: Product detail');
      try {
        final firstProduct = find.text('Toyota Camry');
        if (firstProduct.evaluate().isNotEmpty) {
          await tester.tap(firstProduct.first);
          await tester.pumpAndSettle(const Duration(seconds: 4));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '03_product_detail');
          
          // Go back
          final backBtn = find.byType(BackButton);
          if (backBtn.evaluate().isNotEmpty) {
            await tester.tap(backBtn.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }
        } else {
          print('Product not found, using alternate');
          await takeScreenshot(binding, '03_alternate');
        }
      } catch (e) {
        print('Could not navigate to product: $e');
        await takeScreenshot(binding, '03_error');
      }

      // Screenshot 4: Browse tab
      print('Taking screenshot 4: Browse');
      try {
        final browseBtn = find.text('Browse');
        if (browseBtn.evaluate().isNotEmpty) {
          await tester.tap(browseBtn);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '04_browse_tab');
        } else {
          print('Browse button not found');
          await takeScreenshot(binding, '04_alternate');
        }
      } catch (e) {
        print('Could not navigate to Browse: $e');
        await takeScreenshot(binding, '04_error');
      }

      // Screenshot 5: Profile tab
      print('Taking screenshot 5: Profile');
      try {
        final profileBtn = find.text('Profile');
        if (profileBtn.evaluate().isNotEmpty) {
          await tester.tap(profileBtn);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '05_profile_tab');
        } else {
          print('Profile button not found');
          await takeScreenshot(binding, '05_alternate');
        }
      } catch (e) {
        print('Could not navigate to Profile: $e');
        await takeScreenshot(binding, '05_error');
      }
      
      print('=== ALL SCREENSHOTS COMPLETED ===');
    });
  });
}

Future<void> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final screenshotsDir = Directory('screenshots');
  if (!screenshotsDir.existsSync()) {
    screenshotsDir.createSync(recursive: true);
  }

  await binding.takeScreenshot(name);
  print('Screenshot saved: $name');
}
