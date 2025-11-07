# 📸 Creating App Store Screenshot Variations

This guide will help you create 5 unique iPad Pro screenshots from your single home page screenshot.

## 🎯 What You'll Get

From your one home page screenshot, the script creates:

1. **Full Home Page** - Original with text overlay at bottom
2. **Category Focus** - Zoomed view of the categories section
3. **Featured Products** - Highlighted promoted items
4. **Overview** - Top section sharp, bottom blurred with overlay text
5. **Clean Branded** - Minimal design with app name

All screenshots will be **2048 x 2732px** (perfect for iPad Pro 12.9").

## 📋 Prerequisites

You need Python installed on Windows. If you don't have it:

1. Download Python from: https://www.python.org/downloads/
2. During installation, check "Add Python to PATH"
3. Click "Install Now"

## 🚀 Quick Start

### Step 1: Install Dependencies

Open PowerShell in this directory and run:

```powershell
pip install -r requirements_screenshots.txt
```

### Step 2: Prepare Your Screenshot

Make sure you have your base screenshot in the `screenshots` folder:
- The script will automatically find the first `.png` file
- Recommended: Use `01_home_landing.png`

### Step 3: Run the Script

```powershell
python create_screenshot_variations.py
```

### Step 4: Check Results

Look in the newly created `app_store_screenshots` folder. You'll find:
- `01_home_full.png`
- `02_categories.png`
- `03_products.png`
- `04_overview.png`
- `05_branding.png`

## 📤 Upload to App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → **App Store** tab
3. Scroll to **iPad Screenshots**
4. Under **iPad Pro (12.9-inch) (6th generation)**:
   - Click the **+** button
   - Upload all 5 screenshots from `app_store_screenshots` folder
   - Drag to reorder if needed
5. Click **Save**

## 🎨 Customization

### Change Text

Edit the `create_screenshot_variations.py` file and modify the text strings:

```python
# Example: Line ~50
text = "Find Quality Auto Parts Faster"  # Change this text
```

### Change Colors

Modify the RGB values:

```python
# Blue background: (30, 58, 138)
# Change to: (red, green, blue)
```

### Different Crops

Adjust the crop_box coordinates:

```python
# Example: Variation 2, Line ~70
crop_box = (0, 400, TARGET_WIDTH, 1400)
# Format: (left, top, right, bottom)
```

## ❓ Troubleshooting

### "No screenshot found"
- Make sure you have a `.png` file in the `screenshots` folder
- The file should be from your Codemagic artifacts

### "Module not found: PIL"
- Run: `pip install Pillow`

### "Python not recognized"
- Reinstall Python and check "Add to PATH" during installation
- Or use full path: `C:\Users\USER\AppData\Local\Programs\Python\Python3X\python.exe`

### Font Issues
- Script uses Arial (built into Windows)
- If text doesn't appear, the script falls back to default font automatically

## 💡 Tips

- **Preview before upload**: Open each screenshot to ensure quality
- **App Store guidelines**: Use images that accurately represent your app
- **Text overlays**: Keep text brief and readable
- **Order matters**: Put your best screenshot first (users see it in search results)

## 📚 App Store Screenshot Requirements

✅ **Size**: 2048 x 2732 pixels (iPad Pro 12.9")
✅ **Format**: PNG or JPEG
✅ **Quantity**: 3-10 screenshots required
✅ **Orientation**: Portrait
✅ **No alpha**: Screenshots must be opaque (no transparency)

## 🆘 Need Help?

If the automated script doesn't work, you can manually edit screenshots:

**Using Paint (Windows)**:
1. Open screenshot in Paint
2. Use crop tool to focus on different sections
3. Resize to 2048 x 2732px
4. Add text using text tool
5. Save as PNG

**Using PowerPoint**:
1. Set slide size to 2048 x 2732px
2. Insert your screenshot
3. Add text boxes with your messaging
4. Export as PNG

---

**Good luck with your App Store submission!** 🚀
