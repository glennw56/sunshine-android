#!/usr/bin/env python3
"""Fail if an Android APK shipped the stub Explore player instead of TPP."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify_apk_player.py APK", file=sys.stderr)
        return 2
    apk = Path(sys.argv[1])
    with zipfile.ZipFile(apk) as zf:
        names = zf.namelist()
        gdc = "assets/scripts/explore/player.gdc"
        remap = "assets/scripts/explore/player.gd.remap"
        if gdc not in names:
            print("FAIL %s missing %s (stub/main export?)" % (apk, gdc))
            return 1
        data = zf.read(gdc)
        print("player.gdc bytes", len(data))
        if len(data) < 6000:
            print("FAIL player.gdc is too small for the TPP baker (%d bytes)" % len(data))
            return 1
        if b"center_baker_v069" not in data:
            print("FAIL player.gdc missing CAMERA_BUILD center_baker_v069")
            return 1
        if remap in names:
            print(zf.read(remap).decode("utf-8", "replace"))
        print("PASS APK contains TPP player.gdc with SHOULDER.x=0 build mark")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
