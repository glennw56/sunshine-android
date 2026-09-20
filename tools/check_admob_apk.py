#!/usr/bin/env python3
"""Verify an exported Sunshine APK actually packages AdMob GDScript + native plugin."""
from __future__ import annotations

import sys
import zipfile

NEED_ASSETS = (
    "assets/addons/admob/gdscript/src/api/RewardedAdLoader.gdc",
    "assets/addons/admob/gdscript/src/api/RewardedAd.gdc",
    "assets/addons/admob/gdscript/src/api/listeners/RewardedAdLoadCallback.gdc",
    "assets/addons/admob/gdscript/src/api/listeners/FullScreenContentCallback.gdc",
    "assets/addons/admob/gdscript/src/api/listeners/OnUserEarnedRewardListener.gdc",
    "assets/addons/admob/gdscript/src/api/core/AdRequest.gdc",
    "assets/addons/admob/plugin.cfg",
)
NEED_DEX_STRINGS = (
    b"PoingGodotAdMob",
    b"PoingGodotAdMobRewardedAd",
)
APP_ID = "ca-app-pub-2788636443838183~1520526800"


def main(path: str) -> int:
    z = zipfile.ZipFile(path)
    names = set(z.namelist())
    missing = [p for p in NEED_ASSETS if p not in names]
    if missing:
        print("FAIL missing APK assets:", missing)
        return 1
    print("OK  : RewardedAdLoader.gdc + Poing API scripts in APK")
    dex = b"".join(z.read(n) for n in z.namelist() if n.startswith("classes") and n.endswith(".dex"))
    for needle in NEED_DEX_STRINGS:
        if needle not in dex:
            print("FAIL missing native", needle.decode())
            return 1
        print("OK  :", needle.decode())
    manifest = z.read("AndroidManifest.xml")
    if APP_ID.encode("utf-16le") not in manifest and APP_ID.encode("utf-8") not in manifest:
        print("FAIL missing production APPLICATION_ID in manifest")
        return 1
    print("OK  : production APPLICATION_ID in AndroidManifest")
    print("OK  : AdMob plugin packaged")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: check_admob_apk.py <apk>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
