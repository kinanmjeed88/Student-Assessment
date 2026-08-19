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
    legacy_icon = image.resize((size, size), Image.Resampling.LANCZOS)
    legacy_icon.save(target / 'ic_launcher.png', optimize=True)

splash = root / 'android' / 'app' / 'src' / 'main' / 'res' / 'drawable-nodpi'
splash.mkdir(parents=True, exist_ok=True)
launch_image = image.copy()
launch_image.thumbnail((384, 384), Image.Resampling.LANCZOS)
launch_image.save(splash / 'launch_image.png', optimize=True)

# Android 8+ uses an adaptive icon. Keep the generated mark inside a safe
# foreground area so the launcher mask cannot crop the academic symbol.
foreground = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
mark = image.copy()
mark.thumbnail((800, 800), Image.Resampling.LANCZOS)
left = (foreground.width - mark.width) // 2
upper = (foreground.height - mark.height) // 2
foreground.alpha_composite(mark, (left, upper))
foreground.save(splash / 'ic_launcher_foreground.png', optimize=True)
