#!/usr/bin/env python3
"""Measure local-baker silhouette X vs screen midline. Writes a note + overlay PNG."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


def read_png(path: Path) -> tuple[int, int, list[bytearray]]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    w = h = None
    idat = b""
    while pos < len(data):
        ln = int.from_bytes(data[pos : pos + 4], "big")
        typ = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h = struct.unpack(">II", chunk[:8])
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
    raw = zlib.decompress(idat)
    bpp = 3
    rows: list[bytearray] = []
    stride = w * bpp
    i = 0
    prev = bytearray(stride)

    def paeth(a: int, b: int, c: int) -> int:
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        if pb <= pc:
            return b
        return c

    for _y in range(h):
        f = raw[i]
        i += 1
        row = bytearray(raw[i : i + stride])
        i += stride
        if f == 1:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + left) & 255
        elif f == 2:
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + ((left + prev[x]) // 2)) & 255
        elif f == 4:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + paeth(a, b, c)) & 255
        rows.append(row)
        prev = row
    return w, h, rows


def write_png(path: Path, w: int, h: int, rows: list[bytearray]) -> None:
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    def chunk(typ: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(typ + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", crc)

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    out += chunk(b"IEND", b"")
    path.write_bytes(out)


def measure(path: Path) -> dict:
    w, h, rows = read_png(path)
    hat: list[int] = []
    body: list[int] = []
    y0, y1 = int(h * 0.42), int(h * 0.88)
    x0, x1 = int(w * 0.22), int(w * 0.78)
    for y in range(y0, y1):
        row = rows[y]
        for x in range(x0, x1):
            r, g, b = row[x * 3], row[x * 3 + 1], row[x * 3 + 2]
            is_hat = r > 200 and g > 165 and b < 95 and g > b + 45
            is_dress = r > 220 and 150 < g < 210 and 175 < b < 230 and abs(int(r) - g) < 85
            is_skin = r > 225 and 185 < g < 225 and 165 < b < 210 and r > g
            if is_hat:
                hat.append(x)
            if is_hat or is_dress or is_skin:
                body.append(x)
    mid = w / 2.0
    result = {
        "file": str(path),
        "w": w,
        "h": h,
        "mid": mid,
        "hat_n": len(hat),
        "body_n": len(body),
    }
    if hat:
        result["hat_centroid"] = sum(hat) / len(hat)
        result["hat_bbox_center"] = (min(hat) + max(hat)) / 2.0
        result["hat_off"] = result["hat_centroid"] - mid
        result["hat_bbox_off"] = result["hat_bbox_center"] - mid
    if body:
        result["body_centroid"] = sum(body) / len(body)
        result["body_off"] = result["body_centroid"] - mid
    # Overlay: red midline, green baker centroid.
    if hat:
        cx = int(round(result["hat_centroid"]))
        for y in range(h):
            for dx in range(-1, 2):
                mx = int(mid) + dx
                if 0 <= mx < w:
                    rows[y][mx * 3 : mx * 3 + 3] = bytes((220, 30, 40))
                gx = cx + dx
                if 0 <= gx < w:
                    rows[y][gx * 3 : gx * 3 + 3] = bytes((40, 200, 70))
    art = Path("/opt/cursor/artifacts")
    art.mkdir(parents=True, exist_ok=True)
    overlay = art / (path.stem + "_measured.png")
    write_png(overlay, w, h, rows)
    result["overlay"] = str(overlay)
    return result


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: measure_baker_center.py PNG [PNG...]", file=sys.stderr)
        return 2
    worst = 0.0
    note = Path("/opt/cursor/artifacts/baker_center_measure.txt")
    note.write_text("")
    for arg in sys.argv[1:]:
        r = measure(Path(arg))
        print(r)
        off = abs(float(r.get("hat_off", 999)))
        worst = max(worst, off)
        with note.open("a", encoding="utf-8") as fh:
            fh.write(
                "%s %dx%d midline=%.1f hat_centroid_off_px=%.1f hat_bbox_off_px=%.1f overlay=%s\n"
                % (
                    r["file"],
                    r["w"],
                    r["h"],
                    r["mid"],
                    r.get("hat_off", float("nan")),
                    r.get("hat_bbox_off", float("nan")),
                    r.get("overlay", ""),
                )
            )
    if worst > 24:
        print("FAIL baker silhouette more than 24px from midline (%.1f)" % worst)
        return 1
    print("PASS worst hat offset %.1f px from midline" % worst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
