#!/usr/bin/env python3
"""Side-by-side: storefront photo vs Explore hero capture."""

from __future__ import annotations

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PHOTO = os.path.join(ROOT, "assets", "reference", "storefront-hero.jpg")
CAPTURE = os.path.join(ROOT, "export", "review")
OUT = os.environ.get("COMPARE_OUT", "/opt/cursor/artifacts")

PAIRS = (
    ("storefront-hero.jpg", "photo_hero.png", "hero"),
    ("storefront-hero.jpg", "shop_spawn.png", "spawn"),
    ("storefront-hero.jpg", "Entrance.png", "entrance"),
)


def main() -> int:
    from PIL import Image, ImageDraw

    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(OUT, "still_compare"), exist_ok=True)
    if not os.path.isfile(PHOTO):
        print("missing reference photo", PHOTO)
        return 1
    made = 0
    for _still_name, shot_name, label in PAIRS:
        shot_path = os.path.join(CAPTURE, shot_name)
        if not os.path.isfile(shot_path):
            print("skip", label, "missing", shot_path)
            continue
        a = Image.open(PHOTO).convert("RGB")
        b = Image.open(shot_path).convert("RGB")
        h = 720
        a = a.resize((int(a.width * h / a.height), h), Image.Resampling.LANCZOS)
        b = b.resize((int(b.width * h / b.height), h), Image.Resampling.LANCZOS)
        pad = 16
        canvas = Image.new("RGB", (a.width + b.width + pad * 3, h + 72), (24, 18, 20))
        canvas.paste(a, (pad, 56))
        canvas.paste(b, (pad * 2 + a.width, 56))
        draw = ImageDraw.Draw(canvas)
        draw.text((pad, 16), "PHOTO  storefront-hero.jpg", fill=(232, 180, 184))
        draw.text((pad * 2 + a.width, 16), "EXPLORE  " + shot_name, fill=(232, 180, 184))
        dest = os.path.join(OUT, "still_compare", "compare_%s.png" % label)
        canvas.save(dest, "PNG")
        print("wrote", dest)
        made += 1
    print("pairs", made)
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main())
