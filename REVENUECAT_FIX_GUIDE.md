# 🔧 RevenueCat Configuration Fix Guide

## ❌ The Problem

Apple rejected the app because **in-app purchases don't load**. The issue:
- Screenshot shows: "No packages available yet"
- RevenueCat products exist but aren't in an **Offering**
- App can't fetch packages without a configured offering

## ✅ The Solution: Configure RevenueCat Offerings

### Step 1: Go to RevenueCat Dashboard

1. Visit: https://app.revenuecat.com
2. Select your project: **Mechanic part LLC (App Store)**
3. Click **Offerings** in the left sidebar

### Step 2: Create Default Offering

1. Click **+ New Offering** button
2. Fill in the form:
   - **Identifier**: `default` (must be exactly this!)
   - **Description**: "Default subscription plans"
   - **Set as current offering**: ✅ Check this box
3. Click **Create Offering**

### Step 3: Add Packages

Now add packages for each product. Click **+ Add Package** for each:

#### Basic Plans

**Package 1: Monthly**
- **Identifier**: `$rc_monthly`
- **Product**: `1 month (basic_monthly)`
- Click **Add**

**Package 2: Quarterly**  
- **Identifier**: `$rc_three_month`
- **Product**: `3 months (basic_quarterly)`
- Click **Add**

**Package 3: Six Month**
- **Identifier**: `$rc_six_month`
- **Product**: `6 months (basic_6month)`
- Click **Add**

**Package 4: Annual**
- **Identifier**: `$rc_annual`
- **Product**: `12 months (basic_yearly)`
- Click **Add**

#### Premium Plans

**Package 5: Premium 6-Month**
- **Identifier**: `premium_six_month`
- **Product**: `Premium 6-Month (premium_6month1)`
- Click **Add**

**Package 6: Premium Monthly**
- **Identifier**: `premium_monthly`
- **Product**: `Premium Monthly (premium_monthly1)`
- Click **Add**

### Step 4: Verify Configuration

After adding all packages:

1. Go to **Offerings** page
2. Confirm `default` offering shows as **Current** (green checkmark)
3. Click on `default` to see all 6 packages listed
4. Each package should show the mapped iOS product

### Step 5: Test in TestFlight

After configuration:

1. Build a new version (no code changes needed)
2. Submit to TestFlight
3. Install on device
4. Navigate to **Upgrade Plan**
5. You should now see all subscription plans

## 📱 Product IDs Reference

Your iOS products in App Store Connect:

| Product Name | Product ID | Duration |
|--------------|------------|----------|
| 1 month | `basic_monthly` | Monthly |
| 3 months | `basic_quarterly` | Quarterly |
| 6 months | `basic_6month` | 6 months |
| 12 months | `basic_yearly` | Yearly |
| Premium 6-Month | `premium_6month1` | 6 months |
| Premium Monthly | `premium_monthly1` | Monthly |

## 🔍 How to Verify It's Working

### In RevenueCat Dashboard

1. Go to **Offerings**
2. Click on `default`
3. You should see:
   ```
   default (Current Offering)
   
   Packages:
   - $rc_monthly → basic_monthly
   - $rc_three_month → basic_quarterly
   - $rc_six_month → basic_6month
   - $rc_annual → basic_yearly
   - premium_six_month → premium_6month1
   - premium_monthly → premium_monthly1
   ```

### In Xcode Logs (Debug Build)

When you run the app, check console for:
```
[RevenueCat] Successfully initialized
[RevenueCat] Fetching offerings...
[RevenueCat] Current offering has 6 packages
[RevenueCat] Package: $rc_monthly, Product: basic_monthly
[RevenueCat] Package: $rc_three_month, Product: basic_quarterly
...
```

### In the App

1. Open app
2. Go to Profile → Upgrade Plan
3. You should see:
   - **Basic** section with 4 plans
   - **Premium** section with 2 plans
   - Each plan shows price and duration
   - No error messages

## 🚨 Common Issues

### Issue 1: "No current offering found"

**Cause**: Offering not set as Current
**Fix**: 
1. Go to Offerings
2. Find `default`
3. Click the 3-dot menu → "Set as Current"

### Issue 2: "No packages available yet"

**Cause**: No packages added to offering
**Fix**: Follow Step 3 above to add all 6 packages

### Issue 3: Products show "Waiting for Review"

**Status**: This is NORMAL
**Note**: Products don't need to be approved to work in TestFlight and for reviewers. The "Waiting for Review" status doesn't block functionality.

### Issue 4: Prices don't load

**Cause**: Product IDs mismatch between App Store Connect and RevenueCat
**Fix**: 
1. Check product IDs in App Store Connect
2. Ensure they match exactly in RevenueCat packages
3. IDs are case-sensitive: `basic_monthly` ≠ `Basic_Monthly`

## 📤 Re-submit to Apple

After configuring offerings:

1. **Build new version**: Increment build number in `pubspec.yaml`
   ```yaml
   version: 1.2.7+4  # Increment the +4 part
   ```

2. **Commit changes**:
   ```bash
   git add .
   git commit -m "Add RevenueCat logging and fix offerings configuration"
   git push origin main
   ```

3. **Build for App Store**:
   - Push a new tag or trigger Codemagic build
   - Upload new build to App Store Connect

4. **In App Store Connect**:
   - Go to your app → TestFlight
   - Wait for processing
   - Add new build to App Review
   - Respond to rejection with: "RevenueCat offerings have been configured. IAPs now load correctly."

5. **Submit for review**

## 💡 Important Notes

- **No code changes needed** - this is purely a dashboard configuration
- **TestFlight testing**: Test the new build yourself before resubmitting
- **Sandbox testing**: Use a sandbox tester account to verify purchases work
- **Reviewer access**: Apple reviewers can see all products even if "Waiting for Review"

## 🆘 Still Not Working?

### Check RevenueCat API Key

Ensure your iOS API key is correct in App Store Connect:

1. RevenueCat Dashboard → **API Keys** → Copy iOS key
2. Should start with `appl_`
3. Verify it's the same key in your code/environment variables

### Check Entitlements

1. In RevenueCat → **Entitlements**
2. Ensure these exist:
   - `basic_access` (for Basic plans)
   - `premium_access` (for Premium plans)
3. Each product should be attached to its entitlement

### Contact RevenueCat Support

If still having issues:
1. Go to RevenueCat Dashboard
2. Click chat icon (bottom right)
3. Describe: "Offerings not loading for App Store reviewer"
4. Provide: Your app bundle ID and project name

---

## ✅ Checklist Before Resubmission

- [ ] Created `default` offering in RevenueCat
- [ ] Set `default` as Current Offering
- [ ] Added all 6 packages to offering
- [ ] Verified packages map to correct iOS product IDs
- [ ] Incremented build number in `pubspec.yaml`
- [ ] Built and uploaded new version to App Store Connect
- [ ] Tested in TestFlight (IAPs load and show prices)
- [ ] Submitted new build for App Review
- [ ] Responded to rejection explaining the fix

---

**Good luck with your resubmission!** 🚀
