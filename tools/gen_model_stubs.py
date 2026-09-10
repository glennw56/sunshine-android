#!/usr/bin/env python3
"""Write tiny glTF-binary locators so res://assets/models/*.glb paths exist.

Root node names start with PLACEHOLDER_ — Explore 3D ignores them and keeps
the procedural shop until you overwrite a file with a real mesh export.
"""

from __future__ import annotations

import json
import os
import struct

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "models")

FILES = {
    "sunshine_logo_girl.glb": "PLACEHOLDER_sunshine_logo_girl",
    "sunshine_shop_exterior.glb": "PLACEHOLDER_sunshine_shop_exterior",
    "sunshine_backyard.glb": "PLACEHOLDER_sunshine_backyard",
    "sunshine_interior.glb": "PLACEHOLDER_sunshine_interior",
}


def write_glb(path: str, node_name: str) -> None:
    payload = {
        "asset": {"version": "2.0", "generator": "sunshine-android placeholder"},
        "scene": 0,
        "scenes": [{"name": node_name, "nodes": [0]}],
        "nodes": [{"name": node_name}],
    }
    js = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    json_chunk = struct.pack("<I", len(js)) + b"JSON" + js
    header = b"glTF" + struct.pack("<II", 2, 12 + len(json_chunk))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(header + json_chunk)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, node in FILES.items():
        path = os.path.join(OUT, name)
        write_glb(path, node)
        print("wrote %s (%d bytes) node=%s" % (path, os.path.getsize(path), node))


if __name__ == "__main__":
    main()
