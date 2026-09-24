#!/usr/bin/env python3
"""Build opaque iOS app icons and a portrait launch screen from brand art.

Source: assets/branding/sunshine-logo-girl.jpg (official circular mark, RGB)
and assets/branding/sunshine-logo-disc.png (same mark, transparent outside
the circle) composited on the bakery blush used by the Android preset.
The 1024 marketing icon is RGB with no alpha channel.
"""

from __future__ import annotations

import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BRAND = os.path.join(ROOT, "assets", "branding")
OUT = os.path.join(BRAND, "apple")
LOGO = os.path.join(BRAND, "sunshine-logo-girl.jpg")
DISC = os.path.join(BRAND, "sunshine-logo-disc.png")
# Android preset screen/background_color Color(0.91, 0.71, 0.72, 1)
BLUSH = (232, 181, 184)

# Every unique size the Godot 4.3 iOS exporter asks for.
ICON_SIZES = (1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40)


def _square_icon(logo: Image.Image, side: int) -> Image.Image:
    """Official mark, scaled, on opaque white (the logo file's own ground)."""
    src = logo.convert("RGB")
    return src.resize((side, side), Image.Resampling.LANCZOS)


def _launch(disc: Image.Image, size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGB", size, BLUSH)
    mark = disc.convert("RGBA")
    target = int(min(size) * 0.62)
    mark = mark.resize((target, target), Image.Resampling.LANCZOS)
    # Flatten any translucent pixels onto blush so the PNG stays opaque.
    flat = Image.new("RGB", mark.size, BLUSH)
    flat.paste(mark, mask=mark.getchannel("A"))
    x = (size[0] - target) // 2
    y = int(size[1] * 0.36) - target // 2
    canvas.paste(flat, (x, y))
    return canvas


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    logo = Image.open(LOGO)
    disc = Image.open(DISC)
    for side in ICON_SIZES:
        image = _square_icon(logo, side)
        if image.mode != "RGB":
            raise SystemExit("icon %d is %s, expected RGB" % (side, image.mode))
        path = os.path.join(OUT, "icon-%d.png" % side)
        image.save(path, format="PNG", optimize=True)
        check = Image.open(path)
        if check.mode != "RGB":
            raise SystemExit("wrote alpha into %s (%s)" % (path, check.mode))
        print("icon", side, check.mode, os.path.getsize(path))
    launches = {
        "launch-2x.png": (750, 1334),
        "launch-3x.png": (1125, 2436),
    }
    for name, size in launches.items():
        image = _launch(disc, size)
        path = os.path.join(OUT, name)
        image.save(path, format="PNG", optimize=True)
        check = Image.open(path)
        if check.mode != "RGB" or check.size != size:
            raise SystemExit("bad launch image %s %s %s" % (name, check.mode, check.size))
        print("launch", name, check.size, os.path.getsize(path))


if __name__ == "__main__":
    main()
