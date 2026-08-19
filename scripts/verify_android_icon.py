from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
SOURCE = ROOT / "assets" / "images" / "favicon.png"
MANIFEST = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
ADAPTIVE = RES / "mipmap-anydpi-v26" / "ic_launcher.xml"
FOREGROUND = RES / "drawable-nodpi" / "ic_launcher_foreground.png"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def fail(message: str) -> None:
    print(f"Icon verification failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def png_info(path: Path) -> tuple[int, int, int, int]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE) or len(data) < 29:
        fail(f"invalid PNG: {path}")
    if data[12:16] != b"IHDR":
        fail(f"PNG has no IHDR: {path}")
    width, height, bit_depth, color_type, _, _, _ = struct.unpack(
        ">IIBBBBB", data[16:29]
    )
    return width, height, bit_depth, color_type


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

source_width, source_height, _, _ = png_info(SOURCE)
if source_width != source_height:
    fail('source icon must be square')

foreground_width, foreground_height, bit_depth, color_type = png_info(FOREGROUND)
if (foreground_width, foreground_height) != (1024, 1024):
    fail('adaptive foreground must be 1024x1024')
if bit_depth != 8 or color_type != 6:
    fail('adaptive foreground must be an 8-bit RGBA PNG with transparency')
if FOREGROUND.stat().st_size < 1024:
    fail('adaptive foreground is unexpectedly empty')

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
    width, height, _, _ = png_info(icon)
    if (width, height) != (size, size):
        fail(f'{icon} has size {(width, height)}, expected {(size, size)}')

print('Android icon verification passed: source, manifest, adaptive icon, RGBA foreground, and density resources are valid.')
