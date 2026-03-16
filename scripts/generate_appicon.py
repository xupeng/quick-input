#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "Pillow",
# ]
# ///
"""Generate Notion-style App Icons from new-logo.png.

Style: off-white rounded rectangle background + centered black silhouette,
matching the aesthetic of Notion and similar productivity apps.
"""

from pathlib import Path

from PIL import Image, ImageDraw

# Notion-style background color (warm off-white)
BG_COLOR = (245, 243, 239, 255)  # #F5F3EF
# Icon occupies this fraction of the canvas
ICON_RATIO = 0.58
# Corner radius as fraction of canvas size
CORNER_RATIO = 0.22

# (filename, pixel_size)
SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

# ── Extract logo silhouette ───────────────────────────────────────────────────

src = Image.open(Path(__file__).parent.parent / "resources" / "logo.png").convert("L")

# Dark pixels = icon shape
mask = src.point(lambda p: 255 if p < 128 else 0)

bbox = mask.getbbox()
if bbox is None:
    raise RuntimeError("No icon content found in new-logo.png")
mask = mask.crop(bbox)

# Make square
w, h = mask.size
side = max(w, h)
square_mask = Image.new("L", (side, side), 0)
square_mask.paste(mask, ((side - w) // 2, (side - h) // 2))

# ── Render each size ─────────────────────────────────────────────────────────

out_dir = (
    Path(__file__).parent
    / "QuickInput"
    / "QuickInput"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)

for filename, size in SIZES:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Draw rounded rectangle background
    radius = int(size * CORNER_RATIO)
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bg)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=BG_COLOR)
    canvas.paste(bg, mask=bg)

    # Resize silhouette to fit within canvas
    icon_size = int(size * ICON_RATIO)
    icon_mask = square_mask.resize((icon_size, icon_size), Image.LANCZOS)
    # Re-threshold after LANCZOS to keep crisp edges
    icon_mask = icon_mask.point(lambda p: 255 if p > 80 else 0)

    # Build black RGBA icon from mask
    black = Image.new("RGB", (icon_size, icon_size), (0, 0, 0))
    icon = black.convert("RGBA")
    icon.putalpha(icon_mask)

    # Center on canvas
    offset = (size - icon_size) // 2
    canvas.paste(icon, (offset, offset), icon)

    # Convert to RGB for PNG output (App Icons don't need alpha)
    final = Image.new("RGB", (size, size), (255, 255, 255))
    final.paste(canvas, mask=canvas.split()[3])
    final.save(out_dir / filename)
    print(f"Generated {filename} ({size}×{size})")

print("\nDone! All App Icons updated.")
