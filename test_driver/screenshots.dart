// Simple Flutter Driver script for taking screenshots
// Run with: flutter drive --target=test_driver/screenshots.dart

import 'package:flutter_driver/flutter_driver.dart';
import 'dart:io';

Future<void> main() async {
  final driver = await FlutterDriver.connect();

  // Create screenshots directory
  final screenshotsDir = Directory('screenshots');
  if (!screenshotsDir.existsSync()) {
    screenshotsDir.createSync(recursive: true);
  }

  try {
    print('Taking screenshots...');

    // Wait for app to load
    await Future.delayed(const Duration(seconds: 5));

    // Screenshot 1: Home/Landing screen
    print('Capturing home screen...');
    await driver.waitUntilNoTransientCallbacks();
    await takeScreenshot(driver, 'home_screen');
    await Future.delayed(const Duration(seconds: 2));

    // Screenshot 2: Try to navigate to About
    try {
      print('Navigating to About screen...');
      await driver.tap(find.text('About Us'));
      await driver.waitUntilNoTransientCallbacks();
      await Future.delayed(const Duration(seconds: 2));
      await takeScreenshot(driver, 'about_screen');
    } catch (e) {
      print('Could not navigate to About: $e');
    }

    // Screenshot 3: Try to navigate to Contact
    try {
      print('Navigating to Contact screen...');
      await driver.tap(find.text('Contact Us'));
      await driver.waitUntilNoTransientCallbacks();
      await Future.delayed(const Duration(seconds: 2));
      await takeScreenshot(driver, 'contact_screen');
    } catch (e) {
      print('Could not navigate to Contact: $e');
    }

    print('Screenshots completed!');
  } catch (e) {
    print('Error during screenshot capture: $e');
  } finally {
    await driver.close();
  }
}

Future<void> takeScreenshot(FlutterDriver driver, String name) async {
  final pixels = await driver.screenshot();
  final file = File('screenshots/$name.png');
  await file.writeAsBytes(pixels);
  print('Screenshot saved: ${file.path}');
}
