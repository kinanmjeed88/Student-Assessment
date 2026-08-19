from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
SOURCE = ROOT / "assets" / "images" / "app_icon.png"
MANIFEST = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
ADAPTIVE = RES / "mipmap-anydpi-v26" / "ic_launcher.xml"
FOREGROUND = RES / "drawable-nodpi" / "ic_launcher_foreground.png"


def fail(message: str) -> None:
    print(f"Icon verification failed: {message}", file=sys.stderr)
    raise SystemExit(1)


if not SOURCE.is_file():
    fail(f"missing source image: {SOURCE}")
if not MANIFEST.is_file():
    fail(f"missing manifest: {MANIFEST}")
if '@mipmap/ic_launcher' not in MANIFEST.read_text(encoding='utf-8'):
    fail('AndroidManifest does not reference @mipmap/ic_launcher')
if not ADAPTIVE.is_file():
    fail(f"missing adaptive icon: {ADAPTIVE}")
adaptive_text = ADAPTIVE.read_text(encoding='utf-8')
if '@color/app_icon_background' not in adaptive_text:
    fail('adaptive icon has no app_icon_background')
if '@drawable/ic_launcher_foreground' not in adaptive_text:
    fail('adaptive icon has no ic_launcher_foreground')

source_image = Image.open(SOURCE).convert('RGBA')
if source_image.width != source_image.height:
    fail('source icon must be square')

foreground = Image.open(FOREGROUND).convert('RGBA')
if (foreground.width, foreground.height) != (1024, 1024):
    fail('adaptive foreground must be 1024x1024')
for point in ((0, 0), (1023, 0), (0, 1023), (1023, 1023)):
    if foreground.getpixel(point)[3] != 0:
        fail('adaptive foreground corners must be transparent')
if foreground.getbbox() is None:
    fail('adaptive foreground is empty')

expected_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, size in expected_sizes.items():
    icon = RES / folder / 'ic_launcher.png'
    if not icon.is_file():
        fail(f'missing legacy launcher icon: {icon}')
    image = Image.open(icon)
    if image.size != (size, size):
        fail(f'{icon} has size {image.size}, expected {(size, size)}')

print('Android icon verification passed: source, manifest, adaptive icon, transparency, and density resources are valid.')
