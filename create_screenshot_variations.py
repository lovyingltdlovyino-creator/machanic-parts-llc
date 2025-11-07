"""
Create App Store Screenshot Variations
Generates 5 different iPad Pro 12.9" screenshots from a single base image
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

# iPad Pro 12.9" (6th gen) dimensions
TARGET_WIDTH = 2048
TARGET_HEIGHT = 2732

def create_variation_1(base_img):
    """Original - Full home page"""
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    
    # Add text overlay at bottom
    try:
        font = ImageFont.truetype("arial.ttf", 80)
    except:
        font = ImageFont.load_default()
    
    # Add semi-transparent overlay
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    overlay_draw.rectangle([(0, TARGET_HEIGHT-300), (TARGET_WIDTH, TARGET_HEIGHT)], 
                          fill=(0, 0, 0, 180))
    
    img = Image.alpha_composite(img.convert('RGBA'), overlay)
    draw = ImageDraw.Draw(img)
    
    text = "Find Quality Auto Parts Faster"
    draw.text((TARGET_WIDTH//2, TARGET_HEIGHT-150), text, 
             fill=(255, 255, 255), anchor="mm", font=font)
    
    return img.convert('RGB')

def create_variation_2(base_img):
    """Zoomed to categories section"""
    img = base_img.copy()
    
    # Crop to focus on categories (adjust coordinates based on your image)
    # This focuses on the "Categories" section
    crop_box = (0, 400, TARGET_WIDTH, 1400)
    cropped = img.crop(crop_box)
    
    # Resize back to target dimensions
    result = Image.new('RGB', (TARGET_WIDTH, TARGET_HEIGHT), (30, 58, 138))  # Blue background
    
    # Scale cropped section
    cropped_resized = cropped.resize((TARGET_WIDTH, int(cropped.height * 1.5)))
    
    # Center it
    y_offset = (TARGET_HEIGHT - cropped_resized.height) // 2
    result.paste(cropped_resized, (0, y_offset))
    
    # Add text
    draw = ImageDraw.Draw(result)
    try:
        font_large = ImageFont.truetype("arial.ttf", 100)
        font_small = ImageFont.truetype("arial.ttf", 60)
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    draw.text((TARGET_WIDTH//2, 200), "Browse by Category", 
             fill=(255, 255, 255), anchor="mm", font=font_large)
    draw.text((TARGET_WIDTH//2, 2500), "Organized for easy searching", 
             fill=(255, 255, 255), anchor="mm", font=font_small)
    
    return result

def create_variation_3(base_img):
    """Focus on promoted products"""
    img = base_img.copy()
    
    # Crop to promoted section
    crop_box = (0, 1000, TARGET_WIDTH, 2400)
    cropped = img.crop(crop_box)
    
    # Create result
    result = Image.new('RGB', (TARGET_WIDTH, TARGET_HEIGHT), (30, 58, 138))
    
    # Scale and center
    cropped_resized = cropped.resize((TARGET_WIDTH, int(cropped.height * 1.3)))
    y_offset = (TARGET_HEIGHT - cropped_resized.height) // 2
    result.paste(cropped_resized, (0, y_offset))
    
    # Add text overlays
    draw = ImageDraw.Draw(result)
    try:
        font_large = ImageFont.truetype("arial.ttf", 100)
        font_small = ImageFont.truetype("arial.ttf", 60)
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    draw.text((TARGET_WIDTH//2, 200), "Featured Products", 
             fill=(255, 255, 255), anchor="mm", font=font_large)
    draw.text((TARGET_WIDTH//2, 2500), "From verified sellers", 
             fill=(255, 255, 255), anchor="mm", font=font_small)
    
    return result

def create_variation_4(base_img):
    """Top section with blur effect on bottom"""
    img = base_img.copy()
    
    # Split image
    top_half = img.crop((0, 0, TARGET_WIDTH, TARGET_HEIGHT//2))
    bottom_half = img.crop((0, TARGET_HEIGHT//2, TARGET_WIDTH, TARGET_HEIGHT))
    
    # Blur bottom half
    bottom_blurred = bottom_half.filter(ImageFilter.GaussianBlur(radius=15))
    
    # Combine
    result = Image.new('RGB', (TARGET_WIDTH, TARGET_HEIGHT))
    result.paste(top_half, (0, 0))
    result.paste(bottom_blurred, (0, TARGET_HEIGHT//2))
    
    # Add text overlay
    overlay = Image.new('RGBA', result.size, (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    overlay_draw.rectangle([(200, TARGET_HEIGHT//2 + 200), (TARGET_WIDTH-200, TARGET_HEIGHT//2 + 800)], 
                          fill=(30, 58, 138, 220))
    
    result = Image.alpha_composite(result.convert('RGBA'), overlay)
    draw = ImageDraw.Draw(result)
    
    try:
        font_large = ImageFont.truetype("arial.ttf", 90)
        font_small = ImageFont.truetype("arial.ttf", 50)
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    draw.text((TARGET_WIDTH//2, TARGET_HEIGHT//2 + 350), "Thousands of Parts", 
             fill=(255, 255, 255), anchor="mm", font=font_large)
    draw.text((TARGET_WIDTH//2, TARGET_HEIGHT//2 + 500), "Available nationwide", 
             fill=(255, 255, 255), anchor="mm", font=font_small)
    
    return result.convert('RGB')

def create_variation_5(base_img):
    """Clean version with minimal text"""
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    
    # Add simple top banner
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    overlay_draw.rectangle([(0, 0), (TARGET_WIDTH, 400)], 
                          fill=(0, 0, 0, 160))
    
    img = Image.alpha_composite(img.convert('RGBA'), overlay)
    draw = ImageDraw.Draw(img)
    
    try:
        font_large = ImageFont.truetype("arial.ttf", 120)
        font_small = ImageFont.truetype("arial.ttf", 60)
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    draw.text((TARGET_WIDTH//2, 150), "Mechanic Part", 
             fill=(255, 255, 255), anchor="mm", font=font_large)
    draw.text((TARGET_WIDTH//2, 280), "Your trusted auto parts marketplace", 
             fill=(200, 200, 200), anchor="mm", font=font_small)
    
    return img.convert('RGB')

def main():
    print("🎨 Creating App Store Screenshot Variations...")
    print(f"Target size: {TARGET_WIDTH}x{TARGET_HEIGHT}px (iPad Pro 12.9\")")
    print()
    
    # Find the base screenshot
    screenshot_dir = "screenshots"
    base_file = None
    
    if os.path.exists(screenshot_dir):
        files = [f for f in os.listdir(screenshot_dir) if f.endswith('.png')]
        if files:
            base_file = os.path.join(screenshot_dir, files[0])
            print(f"📸 Using base screenshot: {base_file}")
    
    if not base_file or not os.path.exists(base_file):
        print("❌ Error: No screenshot found in 'screenshots' folder")
        print("Please ensure you have a screenshot file in the screenshots directory")
        return
    
    # Load base image
    base_img = Image.open(base_file)
    
    # Resize to target dimensions if needed
    if base_img.size != (TARGET_WIDTH, TARGET_HEIGHT):
        print(f"Resizing from {base_img.size} to {TARGET_WIDTH}x{TARGET_HEIGHT}")
        base_img = base_img.resize((TARGET_WIDTH, TARGET_HEIGHT), Image.Resampling.LANCZOS)
    
    # Create output directory
    output_dir = "app_store_screenshots"
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate variations
    variations = [
        ("01_home_full.png", create_variation_1, "Full home page with text overlay"),
        ("02_categories.png", create_variation_2, "Category browsing focus"),
        ("03_products.png", create_variation_3, "Featured products"),
        ("04_overview.png", create_variation_4, "Overview with focus"),
        ("05_branding.png", create_variation_5, "Clean branded version"),
    ]
    
    for filename, create_func, description in variations:
        print(f"✨ Creating: {description}...")
        img = create_func(base_img)
        output_path = os.path.join(output_dir, filename)
        img.save(output_path, 'PNG', quality=95)
        print(f"   ✅ Saved: {output_path}")
    
    print()
    print("🎉 SUCCESS! 5 screenshot variations created!")
    print(f"📁 Location: {os.path.abspath(output_dir)}")
    print()
    print("📤 Next steps:")
    print("1. Review the screenshots in the 'app_store_screenshots' folder")
    print("2. Upload them to App Store Connect (iPad Pro 12.9-inch section)")
    print("3. Arrange them in your preferred order")

if __name__ == "__main__":
    main()
