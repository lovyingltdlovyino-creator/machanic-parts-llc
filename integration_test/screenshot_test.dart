import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanic_part/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('iPad Screenshots', () {
    testWidgets('Capture home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Take screenshot
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      
      // Save with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await takeScreenshot(binding, 'home_screen_$timestamp');
      
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('Capture about page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try to find and tap About Us
      final aboutFinder = find.text('About Us');
      if (aboutFinder.evaluate().isNotEmpty) {
        await tester.tap(aboutFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await takeScreenshot(binding, 'about_screen_$timestamp');
      }
    });

    testWidgets('Capture contact page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try to find and tap Contact Us
      final contactFinder = find.text('Contact Us');
      if (contactFinder.evaluate().isNotEmpty) {
        await tester.tap(contactFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await takeScreenshot(binding, 'contact_screen_$timestamp');
      }
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

  // Take screenshot
  await binding.takeScreenshot(name);
  print('Screenshot saved: $name');
}
