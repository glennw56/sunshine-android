#!/usr/bin/env python3
"""Side-by-side: 4× video still vs Explore capture."""

from __future__ import annotations

import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STILLS = os.path.join(ROOT, "voxel-from-video", "frames_4x_pick")
CAPTURE = os.path.join(ROOT, "export", "review")
OUT = os.environ.get("COMPARE_OUT", "/opt/cursor/artifacts")

PAIRS = (
    ("p_00_f_001.jpg", "still_spawn.png", "spawn"),
    ("p_02_f_016.jpg", "still_2231.png", "front_2231"),
    ("p_02_f_016.jpg", "still_ramp.png", "ramp"),
    ("p_04_f_031.jpg", "still_2229.png", "cottage_2229"),
    ("p_16_f_123.jpg", "still_deck.png", "deck_pavilion"),
)


def _read_png(path: str):
    import subprocess
    tmp = path + ".rgba"
    # Godot/capture PNGs + JPEG stills via ffmpeg if present, else PIL.
    try:
        from PIL import Image
        im = Image.open(path).convert("RGBA")
        return im
    except Exception:
        pass
    raise SystemExit("need Pillow to compose still vs Explore pairs")


def main() -> int:
    from PIL import Image, ImageDraw, ImageFont

    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(OUT, "still_compare"), exist_ok=True)
    made = 0
    for still_name, shot_name, label in PAIRS:
        still_path = os.path.join(STILLS, still_name)
        shot_path = os.path.join(CAPTURE, shot_name)
        if not os.path.isfile(still_path) or not os.path.isfile(shot_path):
            print("skip", label, "missing", still_path if not os.path.isfile(still_path) else shot_path)
            continue
        a = Image.open(still_path).convert("RGB")
        b = Image.open(shot_path).convert("RGB")
        h = 720
        a = a.resize((int(a.width * h / a.height), h), Image.Resampling.LANCZOS)
        b = b.resize((int(b.width * h / b.height), h), Image.Resampling.LANCZOS)
        pad = 16
        canvas = Image.new("RGB", (a.width + b.width + pad * 3, h + 72), (24, 18, 20))
        canvas.paste(a, (pad, 56))
        canvas.paste(b, (pad * 2 + a.width, 56))
        draw = ImageDraw.Draw(canvas)
        draw.text((pad, 16), "STILL  " + still_name, fill=(232, 180, 184))
        draw.text((pad * 2 + a.width, 16), "EXPLORE  " + shot_name, fill=(232, 180, 184))
        dest = os.path.join(OUT, "still_compare", "compare_%s.png" % label)
        canvas.save(dest, "PNG")
        print("wrote", dest)
        made += 1
    print("pairs", made)
    return 0 if made else 1


if __name__ == "__main__":
    raise SystemExit(main())
