from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / 'assets' / 'images' / 'app_icon.png'
image = Image.open(source).convert('RGBA')

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, size in sizes.items():
    target = root / 'android' / 'app' / 'src' / 'main' / 'res' / folder
    target.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(target / 'ic_launcher.png', optimize=True)

splash = root / 'android' / 'app' / 'src' / 'main' / 'res' / 'drawable-nodpi'
splash.mkdir(parents=True, exist_ok=True)
image.thumbnail((384, 384), Image.Resampling.LANCZOS)
image.save(splash / 'launch_image.png', optimize=True)
