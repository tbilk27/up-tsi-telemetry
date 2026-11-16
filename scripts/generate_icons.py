import sys
import os
from PIL import Image

def generate_icons(source_path):
    if not os.path.exists(source_path):
        print(f"File not found: {source_path}")
        return False

    img = Image.open(source_path).convert("RGBA")
    
    # Target directories and sizes
    android_res = "mobile/android/app/src/main/res"
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in sizes.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        out_path = os.path.join(folder_path, "ic_launcher.png")
        resized.save(out_path, "PNG")
        print(f"Generated: {out_path} ({size}x{size})")

    # High res for assets
    os.makedirs("mobile/assets/icon", exist_ok=True)
    img.save("mobile/assets/icon/app_icon.png", "PNG")
    
    os.makedirs("assets", exist_ok=True)
    img.save("assets/app_icon.png", "PNG")
    print("Generated master icon in assets/app_icon.png and mobile/assets/icon/app_icon.png")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        generate_icons(sys.argv[1])
    else:
        print("Usage: python3 generate_icons.py <image_path>")
