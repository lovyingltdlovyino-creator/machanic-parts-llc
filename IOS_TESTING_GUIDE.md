# 🧪 iOS Testing on Codemagic

## Overview

The `ios_tests` workflow runs automated integration tests on an iPad Pro simulator. This helps verify:
- ✅ App builds correctly
- ✅ Integration tests pass
- ✅ RevenueCat IAP configuration is valid
- ✅ Screenshots can be generated
- ✅ No critical errors in the app

## 🚀 How to Run Tests

### Method 1: Automatically on Pull Requests

Tests run automatically when you create a pull request:

```bash
# Create a feature branch
git checkout -b test-iap-fix

# Make changes
git add .
git commit -m "Test IAP configuration"
git push origin test-iap-fix

# Create PR on GitHub
# Tests will run automatically
```

### Method 2: Manually Trigger from Codemagic UI

1. Go to https://codemagic.io/apps
2. Select your app: **Mechanic Part LLC**
3. Click **Start new build**
4. Select workflow: **iOS Integration Tests**
5. Select branch: `main` (or any branch)
6. Click **Start new build**

### Method 3: Push a Test Tag

Trigger tests by pushing a tag:

```bash
git tag test-ios-v1
git push origin test-ios-v1
```

Then manually select the `ios_tests` workflow in Codemagic UI.

## 📊 What Gets Tested

### 1. **Flutter Unit Tests**
Runs all unit tests in the `test/` directory.

### 2. **Integration Tests**
Runs `integration_test/screenshot_test.dart`:
- Boots iPad Pro simulator
- Launches app with test configuration
- Attempts to login (if needed)
- Takes screenshots of different screens
- Validates navigation works

### 3. **IAP Configuration Test**
Builds the app for simulator to verify:
- RevenueCat SDK initializes correctly
- StoreKit configuration is valid
- No compilation errors in IAP code

## 🔍 Viewing Test Results

### In Codemagic UI

1. Go to **Builds** in Codemagic
2. Click on the build
3. View each step:
   - ✅ Green = Passed
   - ❌ Red = Failed
   - ⚠️ Yellow = Warning

### Check Logs

Click on any step to see detailed logs:
- **Run Integration Tests** - See test output and errors
- **Test IAP Configuration** - See RevenueCat initialization logs
- **Boot iOS Simulator** - Verify simulator setup

### Download Artifacts

After build completes, download:
- **Screenshots** - From integration tests
- **flutter_drive.log** - Detailed test logs

## 🐛 Common Issues

### Issue 1: "No devices available"

**Cause**: Simulator not booted correctly

**Fix**: Already handled in the workflow (creates simulator if needed)

### Issue 2: "Tests timeout"

**Cause**: App takes too long to load

**Fix**: Increase timeout in `screenshot_test.dart`:
```dart
await tester.pumpAndSettle(const Duration(seconds: 15)); // Increase from 10
```

### Issue 3: "RevenueCat initialization failed"

**Cause**: Missing environment variables

**Fix**: Ensure `REVENUECAT_IOS_PUBLIC_SDK_KEY` is set in Codemagic:
1. Go to Codemagic → Your app → Environment variables
2. Add to `revenuecat_env` group
3. Re-run build

### Issue 4: "Integration test not found"

**Cause**: Test file missing

**Fix**: Ensure `integration_test/screenshot_test.dart` exists:
```bash
ls -la integration_test/screenshot_test.dart
```

## ⚙️ Customizing Tests

### Add More Tests

Create new test files in `integration_test/`:

```dart
// integration_test/iap_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanic_part/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IAP loads correctly', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    
    // Add your test logic
    expect(find.text('Upgrade Plan'), findsOneWidget);
  });
}
```

Then update `codemagic.yaml` to run it:

```yaml
- name: Run Integration Tests
  script: |
    flutter test integration_test/screenshot_test.dart -d "$DEVICE_ID"
    flutter test integration_test/iap_test.dart -d "$DEVICE_ID"
```

### Change Simulator Device

To test on iPhone instead of iPad:

```yaml
- name: Boot iOS Simulator
  script: |
    DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 15 Pro" | head -n 1 | grep -o '[A-F0-9-]\{36\}')
```

### Add Test Notifications

Get notified when tests complete:

In Codemagic UI:
1. Go to your app → **Publishing**
2. Add **Email** or **Slack** notification
3. Select **iOS Integration Tests** workflow
4. Check "Notify on build success" and "Notify on build failure"

## 📈 Best Practices

### 1. Run Tests Before Submitting to App Store

Always run tests after:
- Adding new features
- Fixing bugs
- Updating dependencies
- Changing IAP configuration

### 2. Keep Tests Fast

Integration tests should complete in < 5 minutes:
- Use minimal wait times
- Skip unnecessary screens
- Disable animations if possible

### 3. Use Meaningful Test Names

```dart
// ❌ Bad
testWidgets('test 1', (tester) async { ... });

// ✅ Good
testWidgets('Verify IAP offerings load on Upgrade Plan page', (tester) async { ... });
```

### 4. Check Test Coverage

Add unit tests for critical code:
- RevenueCat service methods
- Payment logic
- User authentication
- Data validation

## 🎯 Next Steps

1. **Push changes** to trigger first test run:
   ```bash
   git add .
   git commit -m "Add iOS integration tests"
   git push origin main
   ```

2. **Manually trigger** a test build in Codemagic UI

3. **Review results** and fix any failing tests

4. **Set up notifications** to stay informed

## 🆘 Troubleshooting

### Build Stuck on "Boot iOS Simulator"

Check Codemagic logs for:
```
Error: Unable to boot device
```

**Solution**: The workflow will create a new simulator automatically

### Tests Pass Locally but Fail on Codemagic

**Possible causes**:
- Missing environment variables
- Different iOS version on Codemagic
- Timing issues (network delays)

**Solution**: Add more detailed logging:
```dart
print('DEBUG: Current screen: ${find.byType(Scaffold)}');
```

### Need Help?

1. Check Codemagic logs (very detailed)
2. Review test output in artifacts
3. Compare with local test run: `flutter test integration_test/screenshot_test.dart`

---

**Happy Testing!** 🚀
