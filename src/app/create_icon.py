#!/usr/bin/env python3
"""
Create macOS app icon from any PNG image.
Centers the image on a square canvas and generates all required sizes.
"""

import os
import sys
import subprocess
from PIL import Image

def create_square_icon(source_path, output_dir, size=1024):
    """Create a square icon with the source image scaled to fill the entire square."""
    
    # Open source image
    img = Image.open(source_path)
    
    # Convert to RGBA if needed
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get dimensions
    width, height = img.size
    
    # Scale to fill the entire square (crop if needed)
    # Use the smaller dimension so the image fills the square completely
    scale = size / min(width, height)
    new_width = int(width * scale)
    new_height = int(height * scale)
    
    # Resize the image
    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Crop to square from center
    left = (new_width - size) // 2
    top = (new_height - size) // 2
    right = left + size
    bottom = top + size
    
    square = img.crop((left, top, right, bottom))
    
    return square

def generate_iconset(source_path, output_dir):
    """Generate all required icon sizes for macOS."""
    
    iconset_dir = os.path.join(output_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    # Create base square icon
    base_icon = create_square_icon(source_path, output_dir, 1024)
    
    # Required sizes for macOS iconset
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    
    for size, filename in sizes:
        resized = base_icon.resize((size, size), Image.Resampling.LANCZOS)
        output_path = os.path.join(iconset_dir, filename)
        resized.save(output_path, "PNG")
        print(f"  Created {filename}")
    
    return iconset_dir

def create_icns(iconset_dir, output_path):
    """Convert iconset to .icns file."""
    try:
        result = subprocess.run(
            ["iconutil", "-c", "icns", iconset_dir, "-o", output_path],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"✅ Created {output_path}")
            return True
        else:
            print(f"❌ iconutil failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_icon = os.path.join(script_dir, "icon", "app_icon.png")
    
    if not os.path.exists(source_icon):
        print(f"❌ Source icon not found: {source_icon}")
        sys.exit(1)
    
    print(f"🎨 Processing icon: {source_icon}")
    
    # Generate iconset
    iconset_dir = generate_iconset(source_icon, script_dir)
    
    # Create .icns file
    icns_output = os.path.join(script_dir, "Amirror.app", "Contents", "Resources", "AppIcon.icns")
    os.makedirs(os.path.dirname(icns_output), exist_ok=True)
    
    if create_icns(iconset_dir, icns_output):
        # Clean up iconset
        import shutil
        shutil.rmtree(iconset_dir)
        print("✅ Icon created successfully!")
    else:
        print("⚠️  Icon creation failed, keeping iconset for debugging")
        sys.exit(1)

if __name__ == "__main__":
    main()
