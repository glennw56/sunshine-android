#!/usr/bin/env python3
"""Procedural PNG textures and UI art for the Sunshine's Bakery scaffold.

All pixels are generated here (no photos). See docs/ASSETS.md for swapping
in later storefront / pastry photos.
"""

from __future__ import annotations

import math
import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "generated")


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: str, width: int, height: int, pixel) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b, a = pixel(x, y, width, height)
            raw.extend(
                (
                    int(max(0, min(255, r))),
                    int(max(0, min(255, g))),
                    int(max(0, min(255, b))),
                    int(max(0, min(255, a))),
                )
            )
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)


def _hash(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFFFF) / 16777215.0


def _clamp(v: float) -> int:
    return int(max(0, min(255, round(v))))


def _mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def gen_noise_tex(name: str, c0, c1, size: int = 128, seed: int = 1, grain: float = 18) -> None:
    def px(x, y, w, h):
        n = _hash(x, y, seed)
        n = 0.55 * n + 0.25 * _hash(x // 4, y // 4, seed + 3) + 0.2 * _hash(x // 8, y // 8, seed + 9)
        r, g, b = _mix(c0, c1, n)
        r += (n - 0.5) * grain
        g += (n - 0.5) * grain
        b += (n - 0.5) * grain
        return _clamp(r), _clamp(g), _clamp(b), 255

    write_png(os.path.join(OUT, name), size, size, px)


def gen_brick(name: str = "brick.png") -> None:
    def px(x, y, w, h):
        row = y // 16
        offset = 16 if row % 2 else 0
        bx = (x + offset) % 32
        by = y % 16
        mortar = bx < 2 or by < 2
        n = _hash(x, y, 11)
        if mortar:
            return 214, 196, 176, 255
        r = 196 + n * 30
        g = 108 + n * 20
        b = 78 + n * 16
        return _clamp(r), _clamp(g), _clamp(b), 255

    write_png(os.path.join(OUT, name), 128, 128, px)


def gen_wood(name: str = "wood.png") -> None:
    def px(x, y, w, h):
        grain = 0.5 + 0.5 * math.sin((x + y * 0.15) / 6.0 + _hash(y, 0, 4))
        n = _hash(x, y, 21)
        r = 150 + grain * 50 + n * 12
        g = 96 + grain * 28 + n * 8
        b = 58 + grain * 10
        return _clamp(r), _clamp(g), _clamp(b), 255

    write_png(os.path.join(OUT, name), 128, 128, px)


def gen_checker(name: str, a, b, cell: int = 16, size: int = 128) -> None:
    def px(x, y, w, h):
        on = ((x // cell) + (y // cell)) % 2 == 0
        n = _hash(x, y, 5) * 10
        c = a if on else b
        return _clamp(c[0] + n), _clamp(c[1] + n), _clamp(c[2] + n), 255

    write_png(os.path.join(OUT, name), size, size, px)


def gen_asphalt(name: str = "asphalt.png") -> None:
    def px(x, y, w, h):
        n = _hash(x, y, 33)
        v = 42 + n * 28
        if abs(x - w // 2) < 3 and (y // 10) % 2 == 0:
            return 230, 210, 80, 255
        return _clamp(v), _clamp(v), _clamp(v + 4), 255

    write_png(os.path.join(OUT, name), 128, 128, px)


def gen_sun_logo(name: str = "sun_logo.png", size: int = 256) -> None:
    cx = cy = size / 2
    inner = size * 0.22
    ray_r = size * 0.46

    def px(x, y, w, h):
        dx = x + 0.5 - cx
        dy = y + 0.5 - cy
        dist = math.hypot(dx, dy)
        ang = math.atan2(dy, dx)
        # cream backdrop
        r, g, b = 255, 246, 234
        rays = 12
        sector = (ang + math.pi) / (2 * math.pi) * rays
        in_ray = abs(sector - round(sector)) < 0.18 and dist < ray_r
        if in_ray:
            t = dist / ray_r
            r, g, b = _mix((244, 196, 48), (232, 140, 64), t)
        if dist < inner:
            n = _hash(x, y, 7)
            r = 250 - n * 8
            g = 210 - n * 10
            b = 70 + n * 8
            # smile
            smile_y = cy + inner * 0.28
            smile = abs(dist - inner * 0.55) < 4 and dy > 8 and abs(dx) < inner * 0.45
            eye_l = math.hypot(dx + inner * 0.28, dy + inner * 0.08) < 5
            eye_r = math.hypot(dx - inner * 0.28, dy + inner * 0.08) < 5
            if smile or eye_l or eye_r:
                r, g, b = 74, 44, 42
        # circular crop
        if dist > ray_r + 2:
            return 0, 0, 0, 0
        return _clamp(r), _clamp(g), _clamp(b), 255

    write_png(os.path.join(OUT, name), size, size, px)


def gen_croissant(name: str = "croissant.png", size: int = 128) -> None:
    def px(x, y, w, h):
        cx, cy = w / 2, h / 2
        dx, dy = (x - cx) / (w * 0.42), (y - cy) / (h * 0.28)
        # crescent
        outer = dx * dx + dy * dy
        inner = (dx + 0.35) ** 2 + (dy * 1.05) ** 2
        if outer < 1 and inner > 0.42:
            n = _hash(x, y, 41)
            t = outer
            r, g, b = _mix((232, 176, 96), (168, 92, 40), t)
            r += n * 20
            g += n * 10
            return _clamp(r), _clamp(g), _clamp(b), 255
        return 0, 0, 0, 0

    write_png(os.path.join(OUT, name), size, size, px)


def gen_drink(name: str = "drink.png", size: int = 128) -> None:
    def px(x, y, w, h):
        cx = w / 2
        cup_l, cup_r = w * 0.32, w * 0.68
        top, bot = h * 0.22, h * 0.86
        t = (y - top) / (bot - top) if bot != top else 0
        half = (cup_r - cup_l) / 2 * (1 - 0.18 * max(0, t))
        if top <= y <= bot and abs(x - cx) <= half:
            n = _hash(x, y, 8)
            if y < h * 0.34:
                return 245, 236, 220, 255
            r, g, b = 92 + n * 10, 48, 28
            if y < h * 0.42:
                r, g, b = 250, 248, 240
            return _clamp(r), _clamp(g), _clamp(b), 255
        # straw
        if h * 0.08 < y < h * 0.28 and abs(x - (cx + 10)) < 3:
            return 232, 148, 156, 255
        return 0, 0, 0, 0

    write_png(os.path.join(OUT, name), size, size, px)


def gen_joystick(name: str, fill, size: int = 128, hole: bool = False) -> None:
    def px(x, y, w, h):
        cx = cy = w / 2
        dist = math.hypot(x - cx, y - cy)
        r = w * 0.46
        if dist > r:
            return 0, 0, 0, 0
        if hole and dist < r * 0.55:
            return 0, 0, 0, 0
        edge = 1 - dist / r
        a = 140 + edge * 80
        return fill[0], fill[1], fill[2], _clamp(a)

    write_png(os.path.join(OUT, name), size, size, px)


def gen_icon_png() -> None:
    # 512 app icon: sun on rose circle
    size = 512

    def px(x, y, w, h):
        cx = cy = w / 2
        dx, dy = x - cx, y - cy
        dist = math.hypot(dx, dy)
        if dist > w * 0.49:
            return 0, 0, 0, 0
        # rose plate
        r, g, b = 232, 180, 184
        n = _hash(x // 8, y // 8, 2)
        r -= n * 8
        ang = math.atan2(dy, dx)
        rays = 12
        sector = (ang + math.pi) / (2 * math.pi) * rays
        in_ray = abs(sector - round(sector)) < 0.16 and w * 0.16 < dist < w * 0.38
        if in_ray:
            r, g, b = 244, 196, 48
        if dist < w * 0.16:
            r, g, b = 250, 210, 72
        return _clamp(r), _clamp(g), _clamp(b), 255

    write_png(os.path.join(ROOT, "icon.png"), size, size, px)


def gen_awning(name: str = "awning.png") -> None:
    def px(x, y, w, h):
        stripe = (x // 16) % 2
        if stripe == 0:
            return 232, 148, 156, 255
        return 250, 246, 236, 255

    write_png(os.path.join(OUT, name), 128, 64, px)


def gen_siding(name: str = "siding.png") -> None:
    """White horizontal clapboard like the 2231 storefront."""

    def px(x, y, w, h):
        n = _hash(x, y, 19) * 6
        groove = y % 12
        if groove == 0:
            return 198, 196, 194, 255
        if groove == 1:
            return 228, 226, 222, 255
        return _clamp(250 - n), _clamp(249 - n), _clamp(246 - n), 255

    write_png(os.path.join(OUT, name), 128, 128, px)


def gen_pink_trim(name: str = "pink_trim.png") -> None:
    def px(x, y, w, h):
        n = _hash(x, y, 5) * 10
        return _clamp(244 - n), _clamp(182 - n * 0.4), _clamp(192 - n * 0.3), 255

    write_png(os.path.join(OUT, name), 64, 64, px)


def gen_fence(name: str = "fence.png") -> None:
    def px(x, y, w, h):
        board = x % 16
        n = _hash(x, y, 27) * 14
        if board == 0:
            return 72, 52, 32, 255
        r = 128 + n
        g = 92 + n * 0.6
        b = 52 + n * 0.3
        return _clamp(r), _clamp(g), _clamp(b), 255

    write_png(os.path.join(OUT, name), 128, 128, px)


def gen_lattice(name: str = "lattice.png") -> None:
    def px(x, y, w, h):
        a = (x + y) % 14
        b = (x - y) % 14
        if a < 3 or b < 3:
            return 196, 168, 122, 255
        return 0, 0, 0, 0

    write_png(os.path.join(OUT, name), 128, 128, px)


def gen_cinder(name: str = "cinder.png") -> None:
    def px(x, y, w, h):
        n = _hash(x, y, 8) * 18
        mortar = (x % 32 < 2) or (y % 16 < 2)
        if mortar:
            return 168, 166, 160, 255
        v = 150 + n
        return _clamp(v), _clamp(v - 2), _clamp(v - 6), 255

    write_png(os.path.join(OUT, name), 128, 128, px)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    gen_brick()
    gen_wood()
    gen_asphalt()
    gen_awning()
    gen_siding()
    gen_pink_trim()
    gen_fence()
    gen_lattice()
    gen_cinder()
    gen_sun_logo()
    gen_croissant()
    gen_drink()
    gen_noise_tex("plaster.png", (245, 232, 214), (228, 210, 188), seed=2)
    gen_noise_tex("grass.png", (92, 140, 72), (58, 110, 54), seed=6, grain=12)
    gen_noise_tex("sidewalk.png", (188, 184, 176), (168, 164, 156), seed=12, grain=14)
    gen_checker("tile.png", (248, 240, 228), (220, 196, 176), cell=16)
    gen_joystick("joy_base.png", (74, 44, 42))
    gen_joystick("joy_knob.png", (244, 196, 48), hole=False)
    gen_icon_png()
    print("wrote procedural textures to", OUT)


if __name__ == "__main__":
    main()
