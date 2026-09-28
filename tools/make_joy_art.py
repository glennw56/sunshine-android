#!/usr/bin/env python3
"""Blush/wine joystick plates — bakery art, not a combat HUD."""

from __future__ import annotations

import math
import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets/generated")


def _png(path: str, w: int, h: int, rgba: bytes) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b""
    row = w * 4
    for y in range(h):
        raw += b"\x00" + rgba[y * row : (y + 1) * row]
    body = b"\x89PNG\r\n\x1a\n"
    body += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    body += chunk(b"IDAT", zlib.compress(raw, 9))
    body += chunk(b"IEND", b"")
    with open(path, "wb") as fh:
        fh.write(body)


def _px(fill, ring, ring_w, rings, size: int) -> bytes:
    out = bytearray(size * size * 4)
    c = (size - 1) * 0.5
    r = size * 0.5 - 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            i = (y * size + x) * 4
            if d > r:
                continue
            col = fill
            if d >= r - ring_w:
                col = ring
            else:
                for rr, rw, rc in rings:
                    if abs(d - rr) <= rw:
                        col = rc
                        break
            out[i : i + 4] = bytes(col)
    return bytes(out)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    wine = (74, 28, 41, 230)
    blush = (232, 180, 184, 108)
    cream = (255, 246, 234, 140)
    walk = (255, 246, 234, 70)
    jog = (232, 180, 184, 90)
    base = _px((74, 28, 41, 96), cream, 10.0, [(78.0, 3.5, walk), (108.0, 3.5, jog)], 256)
    knob = _px((232, 168, 178, 235), wine, 8.0, [], 160)
    _png(os.path.join(OUT, "joy_base.png"), 256, 256, base)
    _png(os.path.join(OUT, "joy_knob.png"), 160, 160, knob)
    print("wrote", os.path.join(OUT, "joy_base.png"), os.path.join(OUT, "joy_knob.png"))


if __name__ == "__main__":
    main()
