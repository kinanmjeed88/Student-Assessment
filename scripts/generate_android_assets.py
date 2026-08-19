from collections import deque
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

def remove_edge_background(source: Image.Image) -> Image.Image:
    """Make only the outer connected background transparent.

    The logo itself contains navy details, so global color replacement would
    destroy the mark. Flood-filling from the image edges preserves those
    internal navy shapes while removing the square artwork background.
    """
    image = source.copy().convert('RGBA')
    width, height = image.size
    pixels = image.load()
    corner = pixels[0, 0][:3]
    visited = bytearray(width * height)
    queue = deque()

    def is_background(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        if alpha == 0:
            return False
        return max(
            abs(red - corner[0]),
            abs(green - corner[1]),
            abs(blue - corner[2]),
        ) <= 24

    def enqueue(x: int, y: int) -> None:
        if 0 <= x < width and 0 <= y < height:
            index = y * width + x
            if not visited[index]:
                visited[index] = 1
                queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if not is_background(x, y):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        enqueue(x - 1, y)
        enqueue(x + 1, y)
        enqueue(x, y - 1)
        enqueue(x, y + 1)

    return image


# Android 8+ uses an adaptive icon. Use a transparent foreground mark and
# keep it within the launcher safe zone so every mask shows the full symbol.
mark = remove_edge_background(image)
bounds = mark.getbbox()
if bounds:
    mark = mark.crop(bounds)
mark.thumbnail((720, 720), Image.Resampling.LANCZOS)
foreground = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
left = (foreground.width - mark.width) // 2
upper = (foreground.height - mark.height) // 2
foreground.alpha_composite(mark, (left, upper))
foreground.save(splash / 'ic_launcher_foreground.png', optimize=True)
