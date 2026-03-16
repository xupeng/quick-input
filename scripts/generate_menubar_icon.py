#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "Pillow",
# ]
# ///
"""Generate menu bar template images from new-logo.png.

The PNG has no real alpha — the checkerboard "transparency" is baked into RGB.
Background pixels are light gray (~210-255), icon pixels are dark (~0-80).
We extract by luminance thresholding.
"""

from pathlib import Path

from PIL import Image

PADDING = 1
THRESHOLD = 128  # below this = icon, above = background
SIZES = {"MenuBarIcon.png": 16, "MenuBarIcon@2x.png": 32}

src = Image.open(Path(__file__).parent.parent / "resources" / "logo.png").convert("L")

# Dark pixels = icon shape, light pixels = background
mask = src.point(lambda p: 255 if p < THRESHOLD else 0)

# Crop to bounding box
bbox = mask.getbbox()
if bbox is None:
    raise RuntimeError("No icon content found")
mask = mask.crop(bbox)

# Make square
w, h = mask.size
side = max(w, h)
square = Image.new("L", (side, side), 0)
square.paste(mask, ((side - w) // 2, (side - h) // 2))

# Output
out_dir = (
    Path(__file__).parent
    / "QuickInput"
    / "QuickInput"
    / "Assets.xcassets"
    / "MenuBarIcon.imageset"
)
out_dir.mkdir(parents=True, exist_ok=True)

for filename, size in SIZES.items():
    icon_size = size - 2 * PADDING
    resized = square.resize((icon_size, icon_size), Image.LANCZOS)

    # Build RGBA: solid black RGB + alpha from mask
    black = Image.new("RGB", resized.size, (0, 0, 0))
    icon = black.convert("RGBA")
    icon.putalpha(resized)

    final = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final.paste(icon, (PADDING, PADDING), icon)
    final.save(out_dir / filename)
    print(f"Generated {out_dir / filename} ({size}x{size})")

print("Done!")
