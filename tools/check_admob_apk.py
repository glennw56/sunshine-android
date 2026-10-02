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
# Debug sideloads must use Google's sample app id. The sample rewarded unit
# does not fill when the manifest still has the production app id.
SAMPLE_APP_ID = "ca-app-pub-3940256099942544~3347511713"
PRODUCTION_APP_ID = "ca-app-pub-2788636443838183~1520526800"
AD_ID_PERMISSION = "com.google.android.gms.permission.AD_ID"


def _in_manifest(manifest: bytes, value: str) -> bool:
    return value.encode("utf-16le") in manifest or value.encode("utf-8") in manifest


def _require_ad_id(manifest: bytes, label: str) -> int:
    if not _in_manifest(manifest, AD_ID_PERMISSION):
        print("FAIL", label, "missing", AD_ID_PERMISSION)
        return 1
    print("OK  :", AD_ID_PERMISSION, "in", label)
    return 0


def check_debug_apk(z: zipfile.ZipFile, names: set[str]) -> int:
    missing = [p for p in NEED_ASSETS if p not in names]
    if missing:
        print("FAIL missing APK assets:", missing)
        return 1
    print("OK  : RewardedAdLoader.gdc + Poing API scripts in APK")
    dex = b"".join(z.read(n) for n in names if n.startswith("classes") and n.endswith(".dex"))
    for needle in NEED_DEX_STRINGS:
        if needle not in dex:
            print("FAIL missing native", needle.decode())
            return 1
        print("OK  :", needle.decode())
    manifest = z.read("AndroidManifest.xml")
    if not _in_manifest(manifest, SAMPLE_APP_ID):
        print("FAIL debug manifest missing Google sample APPLICATION_ID", SAMPLE_APP_ID)
        return 1
    if _in_manifest(manifest, PRODUCTION_APP_ID):
        print("FAIL debug manifest still has the production APPLICATION_ID")
        return 1
    print("OK  : Google sample APPLICATION_ID in debug AndroidManifest")
    if _require_ad_id(manifest, "debug AndroidManifest"):
        return 1
    print("OK  : AdMob plugin packaged")
    return 0


def check_release_aab(z: zipfile.ZipFile) -> int:
    manifest = z.read("base/manifest/AndroidManifest.xml")
    if _require_ad_id(manifest, "release AAB manifest"):
        return 1
    if not _in_manifest(manifest, PRODUCTION_APP_ID):
        print("FAIL release AAB missing production APPLICATION_ID", PRODUCTION_APP_ID)
        return 1
    if _in_manifest(manifest, SAMPLE_APP_ID):
        print("FAIL release AAB has the debug sample APPLICATION_ID")
        return 1
    print("OK  : production APPLICATION_ID in release AAB")
    return 0


def main(path: str) -> int:
    z = zipfile.ZipFile(path)
    names = set(z.namelist())
    if "base/manifest/AndroidManifest.xml" in names:
        return check_release_aab(z)
    return check_debug_apk(z, names)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: check_admob_apk.py <apk>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
