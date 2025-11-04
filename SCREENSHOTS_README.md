# iPad Screenshot Generation for App Store

This project is configured to automatically generate iPad screenshots for App Store submission using Codemagic **Personal Plan** (no VNC access required).

## 📱 What Gets Generated

- iPad Pro 12.9" (6th generation) screenshots - 2048 x 2732px
- Automatically captured screenshots from your app
- Multiple views captured at timed intervals

## 🚀 How to Generate Screenshots

### Via Codemagic Personal Plan (Automated - No VNC Needed)

1. **Create and push a tag to trigger the workflow:**
   ```bash
   git tag screenshots-v1
   git push origin screenshots-v1
   ```

2. **Codemagic will automatically**:
   - Boot iPad Pro 12.9" simulator
   - Build and install your app
   - Launch the app on the simulator
   - Capture screenshots at timed intervals (3 screenshots automatically)
   - Save them as build artifacts

3. **Download screenshots**:
   - Go to Codemagic → Your Build → **Artifacts** tab
   - Download the `.png` files from the `screenshots/` folder
   - Screenshots are already sized correctly: **2048 x 2732px**

### Option 2: Local Generation (Manual)

1. **Install the screenshots package**:
   ```bash
   flutter pub get
   flutter pub global activate screenshots
   ```

2. **Run screenshot generation**:
   ```bash
   screenshots
   ```

3. **Find screenshots** in:
   - `screenshots/` folder (organized by device)

## 📤 Upload to App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → **App Store** → **Screenshots and Previews**
3. Under **iPad Pro (12.9-inch)** section:
   - Click **+** to add screenshots
   - Upload the `.png` files from Codemagic artifacts
4. Arrange in your preferred order
5. Save changes

## ⚙️ Configuration Files

- `screenshots.yaml` - Screenshot generation settings
- `test_driver/screenshots.dart` - Test script that navigates and captures screens
- `codemagic.yaml` (workflow: `ipad_screenshots`) - CI/CD automation

## 🔧 Customization

### Add More Screens

Edit `test_driver/screenshots.dart` and add new test cases:

```dart
testWidgets('My New Screen', (WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Navigate to your screen
  final myButton = find.text('My Button');
  await tester.tap(myButton);
  await tester.pumpAndSettle();
  
  // Take screenshot
  await screenshot(tester, config, 'my_new_screen');
});
```

### Change Device Types

Edit `screenshots.yaml` to add more iPad sizes:

```yaml
devices:
  ios:
    iPad Pro (11-inch) (4th generation):
      frame: false
      orientation: portrait
```

## 📋 Apple's Screenshot Requirements

| Device | Resolution | Aspect Ratio |
|--------|-----------|--------------|
| iPad Pro 12.9" (6th gen) | 2048 x 2732 | Portrait |
| iPad Pro 12.9" (2nd gen) | 2048 x 2732 | Portrait |

Apple requires **at least one set** of iPad screenshots (3-10 images).

## 🐛 Troubleshooting

**Simulators not found?**
- Codemagic uses latest Xcode - simulators should be available
- Check build logs for available devices: `xcrun simctl list devices`

**Screenshots empty/black?**
- Increase `pumpAndSettle` wait times in test script
- Check that `.env` variables are set in Codemagic

**Can't navigate to screens?**
- Update the `find.text()` or `find.byIcon()` selectors to match your actual UI

## 📚 Resources

- [screenshots package](https://pub.dev/packages/screenshots)
- [Apple Screenshot Specs](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Codemagic Documentation](https://docs.codemagic.io/)
