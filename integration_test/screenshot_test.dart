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
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // Screenshot 1: Home/Landing page
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await takeScreenshot(binding, '01_home_landing');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Try to navigate to categories by tapping "View More"
      try {
        final viewMore = find.text('View More');
        if (viewMore.evaluate().isNotEmpty) {
          await tester.tap(viewMore.first);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '02_categories_view');
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Could not tap View More: $e');
      }

      // Try to tap first category icon
      try {
        final categoryIcon = find.byType(CircleAvatar).first;
        if (categoryIcon.evaluate().isNotEmpty) {
          await tester.tap(categoryIcon);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '03_category_parts');
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Could not tap category: $e');
      }

      // Try to tap browse button at bottom
      try {
        final browseBtn = find.text('Browse');
        if (browseBtn.evaluate().isNotEmpty) {
          await tester.tap(browseBtn);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '04_browse_view');
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Could not tap Browse: $e');
      }

      // Try to navigate to profile
      try {
        final profileBtn = find.text('Profile');
        if (profileBtn.evaluate().isNotEmpty) {
          await tester.tap(profileBtn);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          await takeScreenshot(binding, '05_profile_page');
        }
      } catch (e) {
        print('Could not tap Profile: $e');
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

  await binding.takeScreenshot(name);
  print('Screenshot saved: $name');
}
