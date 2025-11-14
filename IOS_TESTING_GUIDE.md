# 🎯 iOS App Preview on Codemagic (Stellar)

## Overview

The `ios_app_preview` workflow builds your iOS app for simulator and enables **Stellar App Preview** - a browser-based iOS simulator where you can manually test your app. This is perfect for:
- ✅ Testing IAP (In-App Purchases) in a real environment
- ✅ Verifying UI/UX without downloading anything
- ✅ Sharing demo with team members
- ✅ Quick manual testing before App Store submission
- ✅ No need for physical device or local Xcode

## 🚀 How to Launch App Preview

### Method 1: Manually Trigger Build (Recommended)

1. **Go to Codemagic**: https://codemagic.io/apps
2. **Select your app**: Mechanic Part LLC
3. **Click**: "Start new build" button (top right)
4. **Select workflow**: "iOS App Preview"
5. **Select branch**: `main`
6. **Click**: "Start new build"
7. **Wait ~8-10 minutes** for build to complete

### Method 2: Automatic on Push/PR

The workflow triggers automatically when you:
- Push to any branch
- Create a pull request

### After Build Completes

Once the build finishes successfully:

1. **Go to the build page** in Codemagic
2. **Scroll to "Artifacts"** section at the bottom
3. **Find**: `Runner.app` artifact
4. **Click**: **"Quick Launch"** button next to it 🚀
5. **App launches** in your browser with iOS simulator!

![Quick Launch Button Example](https://docs.codemagic.io/uploads/2023/07/quick-launch.png)

## 🎮 Using the App Preview Simulator

### Controls

Once the simulator loads in your browser:
- **Tap**: Click anywhere on the screen
- **Scroll**: Use mouse wheel or drag
- **Change Device**: Click ⋮ menu → "Change device"
- **Rotate**: Device rotation button
- **Screenshot**: Take screenshots of current screen
- **Stop Session**: End preview (saves minutes)

### Testing IAPs in App Preview

**Perfect for verifying your IAP fix!**

1. **Launch the app** (wait for it to load)
2. **Login** with your test account: `folabiyistar@gmail.com`
3. **Navigate** to Profile → **Upgrade Plan**
4. **Verify**: All 16 subscription plans load correctly
5. **Check**: Prices display properly
6. **Test**: Try selecting different tiers (Basic, Premium, VIP, VIP Gold)

### Session Limits

- **Duration**: Max 20 minutes per session
- **Concurrent**: 1 session at a time
- **Cost**: $0.095/min after 100 free trial minutes (Pay-as-you-go plan)

## 🔍 Viewing Build Results

### In Codemagic UI

1. Go to **Builds** in Codemagic
2. Click on your build
3. View each step:
   - ✅ Green = Success
   - ❌ Red = Failed
   - ⏳ Blue = Running

### Check Logs

Click on any step to see detailed logs:
- **Install dependencies** - Flutter pub get output
- **Create .env file** - Environment variables setup
- **Build iOS app for simulator** - Main build process with RevenueCat initialization

### Find the Quick Launch Button

After successful build:
1. **Scroll down** to "Artifacts" section
2. Look for **`Runner.app`**
3. **"Quick Launch"** button will appear next to it

## 🐛 Common Issues

### Issue 1: "No Quick Launch button visible"

**Cause**: Build failed or still running

**Fix**: 
1. Wait for build to complete (check status)
2. Verify build succeeded (all steps green ✅)
3. Refresh the page
4. Make sure you're looking at the `Runner.app` artifact, not other files

### Issue 2: "App crashes on launch in simulator"

**Cause**: Missing environment variables or configuration error

**Fix**: 
1. Check build logs for errors during "Build iOS app for simulator" step
2. Verify environment variables are set in Codemagic:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `REVENUECAT_IOS_PUBLIC_SDK_KEY`
3. Re-run the build

### Issue 3: "IAPs don't load in App Preview"

**Cause**: App Preview doesn't connect to real App Store (sandbox only)

**Important**: App Preview uses simulator, not real device, so:
- ✅ You CAN verify UI loads correctly
- ✅ You CAN see if offerings are fetched
- ❌ You CANNOT complete actual purchases (need TestFlight for that)

**What to check**:
1. Does the Upgrade Plan page load?
2. Do you see all 16 subscription options?
3. Are prices displayed (even if placeholder)?
4. Check console logs for RevenueCat errors

### Issue 4: "Build takes too long"

**Cause**: Cold start or large dependencies

**Normal**: First build takes 10-15 minutes
**Expected**: Subsequent builds ~5-8 minutes

**Fix**: Be patient, it's normal!

## 📈 Best Practices for App Preview

### 1. **Enable App Preview Feature First**

If you don't see the App Preview option:
1. Go to Codemagic → **App Preview** (left sidebar)
2. Enable the feature
3. Get 100 free trial minutes
4. After that: $0.095/min

### 2. **Test Before App Store Submission**

Always preview after:
- ✅ Fixing IAP configuration
- ✅ Adding new features
- ✅ UI/UX changes
- ✅ Updating dependencies

### 3. **Stop Sessions When Done**

Save minutes by:
- Clicking "Stop session" when finished testing
- Don't leave simulator running idle
- Each session max 20 minutes

### 4. **Use for Quick Verification**

App Preview is perfect for:
- ✅ Checking if IAP screen loads
- ✅ Verifying UI looks correct
- ✅ Testing navigation
- ✅ Sharing with team for review

Not for:
- ❌ Actual purchase testing (use TestFlight)
- ❌ Performance testing
- ❌ Long testing sessions

## 🎯 Next Steps - START HERE!

### Step 1: Push Changes
```bash
git add .
git commit -m "Enable iOS App Preview (Stellar) workflow"
git push origin main
```

### Step 2: Enable App Preview in Codemagic
1. Go to https://codemagic.io/apps
2. Click **"App Preview"** in left sidebar
3. Click **"Enable App Preview"**
4. You get 100 free trial minutes!

### Step 3: Start Your First Build
1. Go to your app in Codemagic
2. Click **"Start new build"**
3. Select workflow: **"iOS App Preview"**
4. Select branch: **main**
5. Click **"Start new build"**
6. Wait ~8-10 minutes

### Step 4: Launch App in Browser
1. Once build completes, scroll to **"Artifacts"**
2. Find **`Runner.app`**
3. Click **"Quick Launch"** 🚀
4. iOS simulator loads in your browser!

### Step 5: Test Your IAP Fix
1. Login: `folabiyistar@gmail.com` / `Test123`
2. Go to Profile → **Upgrade Plan**
3. Verify all 16 subscription plans appear
4. Check prices display correctly
5. Try selecting different tiers

## 🎉 Success Criteria

Your IAP fix is working if you see:
- ✅ Upgrade Plan page loads without errors
- ✅ All 4 tiers visible (Basic, Premium, VIP, VIP Gold)
- ✅ Each tier shows its subscription options
- ✅ Prices are displayed (even if simulator placeholders)
- ✅ No "No packages available" message

## 🆘 Need Help?

**Can't find Quick Launch button?**
- Make sure build completed successfully (all steps green ✅)
- Refresh the page
- Check you're looking at `Runner.app`, not other artifacts

**App crashes in simulator?**
- Check build logs for errors
- Verify environment variables are set in Codemagic

**IAPs not loading?**
- This is normal in simulator - it won't connect to real App Store
- Check if UI loads and offerings are fetched
- For real purchase testing, use TestFlight

---

**Ready to test your IAP fix!** 🚀 Follow the steps above to launch your app in the browser.
