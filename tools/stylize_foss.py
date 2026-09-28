#!/usr/bin/env python3
"""Minecraft-clean tiles derived from the CC0 ambientCG maps in assets/foss.

No photogrammetry import. Pixel-block grass/leaves + painted clapboard so the
Explore lawn does not read as a noisy texture dump.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FOSS = os.path.join(ROOT, "assets", "foss")
BRAND = os.path.join(ROOT, "assets", "branding")


def _pixel_block(src: str, dest: str, cells: int, bright: float, color: float, tint: tuple[int, int, int] | None = None) -> None:
    im = Image.open(src).convert("RGB")
    im = im.resize((cells, cells), Image.Resampling.BOX)
    im = ImageEnhance.Brightness(im).enhance(bright)
    im = ImageEnhance.Color(im).enhance(color)
    im = ImageEnhance.Contrast(im).enhance(1.08)
    if tint is not None:
        overlay = Image.new("RGB", im.size, tint)
        im = Image.blend(im, overlay, 0.22)
    im = im.resize((256, 256), Image.Resampling.NEAREST)
    im.save(dest, "PNG")
    print("wrote", dest)


def _clapboard(dest: str) -> None:
    w = h = 256
    im = Image.new("RGB", (w, h), (250, 247, 241))
    draw = ImageDraw.Draw(im)
    boards = 5
    bh = h // boards
    for i in range(boards):
        y = i * bh
        shade = 252 - (i % 2) * 6
        draw.rectangle((0, y, w, y + bh - 10), fill=(shade, shade - 2, shade - 6))
        draw.rectangle((0, y + bh - 10, w, y + bh - 3), fill=(176, 166, 158))
        draw.rectangle((0, y + bh - 3, w, y + bh), fill=(132, 122, 116))
    im.save(dest, "PNG")
    print("wrote", dest)


def _logo_disc(dest: str) -> None:
    src = os.path.join(BRAND, "sunshine-logo-girl.jpg")
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    # Knock out the white page so the mark reads as a circle on the facade.
    pix = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            if r > 245 and g > 245 and b > 245:
                pix[x, y] = (r, g, b, 0)
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    inset = int(w * 0.012)
    d.ellipse((inset, inset, w - 1 - inset, h - 1 - inset), fill=255)
    mask = mask.filter(ImageFilter.SMOOTH)
    im.putalpha(mask)
    im = im.resize((1024, 1024), Image.Resampling.LANCZOS)
    im.save(dest, "PNG")
    print("wrote", dest)


def main() -> None:
    grass = os.path.join(FOSS, "grass.jpg")
    _pixel_block(grass, os.path.join(FOSS, "grass_block.png"), 20, 1.28, 1.18, (92, 158, 58))
    _pixel_block(grass, os.path.join(FOSS, "leaf_block.png"), 16, 0.92, 1.25, (36, 96, 40))
    _clapboard(os.path.join(FOSS, "clapboard.png"))
    _logo_disc(os.path.join(BRAND, "sunshine-logo-disc.png"))


if __name__ == "__main__":
    main()
