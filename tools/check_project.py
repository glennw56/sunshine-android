#!/usr/bin/env python3
"""Scaffold sanity: res:// paths exist, branding logo present, live catalog reachable."""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = re.compile(r'res://[A-Za-z0-9_./-]+')
FAILS: list[str] = []


def fail(msg: str) -> None:
    FAILS.append(msg)
    print("FAIL:", msg)


def ok(msg: str) -> None:
    print("OK  :", msg)


def check_paths() -> None:
    logo = os.path.join(ROOT, "assets/branding/sunshine-logo-girl.jpg")
    if not os.path.isfile(logo) or os.path.getsize(logo) < 1000:
        fail("branding logo missing or tiny: " + logo)
    else:
        ok("branding logo %d bytes" % os.path.getsize(logo))
    required = [
        "project.godot",
        "scenes/main_menu.tscn",
        "scenes/order/order.tscn",
        "scenes/tip_ad/tip_ad.tscn",
        "scenes/explore/explore_3d.tscn",
        "scripts/explore/sunshine_mascot.gd",
        "scripts/explore/review_cameras.gd",
        "assets/models/README.md",
        "assets/models/sunshine_logo_girl.glb",
        "assets/models/sunshine_shop_exterior.glb",
        "assets/models/sunshine_backyard.glb",
        "assets/models/sunshine_interior.glb",
        "docs/REVIEW_CAMERAS.md",
        "assets/branding/icon-192.png",
        "LICENSE",
    ]
    for rel in required:
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            fail("missing " + rel)
        else:
            ok(rel)
    found: set[str] = set()
    for dirpath, _, files in os.walk(ROOT):
        if "/.git/" in dirpath.replace("\\", "/") + "/":
            continue
        for name in files:
            if not name.endswith((".gd", ".tscn", ".godot", ".cfg", ".md")):
                continue
            path = os.path.join(dirpath, name)
            text = open(path, encoding="utf-8", errors="replace").read()
            for match in RES.findall(text):
                found.add(match)
    skip_suffix = (".uid",)
    for res in sorted(found):
        rel = res[len("res://") :]
        if rel.endswith(skip_suffix):
            continue
        disk = os.path.join(ROOT, rel)
        if os.path.isdir(disk):
            continue
        if not os.path.isfile(disk):
            fail("broken %s" % res)
    ok("%d res:// references checked" % len(found))


def check_live_menu() -> None:
    url = os.environ.get(
        "SUNSHINE_ORDER_URL", "https://bakery-drinks-k6uuoen7wa-ue.a.run.app"
    ).rstrip("/") + "/order/api/menu"
    try:
        with urllib.request.urlopen(url, timeout=20) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        fail("live menu: %s" % exc)
        return
    drinks = payload.get("drinks") if isinstance(payload, dict) else None
    source = payload.get("source") if isinstance(payload, dict) else None
    if not isinstance(drinks, list) or not drinks:
        fail("live menu returned no drinks: %s" % payload.keys() if isinstance(payload, dict) else type(payload))
        return
    if source != "square":
        fail("expected source=square, got %r" % source)
        return
    names = [d.get("name") for d in drinks if isinstance(d, dict)]
    ok("live Square catalog (%d drinks): %s" % (len(drinks), ", ".join(str(n) for n in names)))


def check_scenes_mention_features() -> None:
    menu = open(os.path.join(ROOT, "scenes/main_menu.tscn"), encoding="utf-8").read()
    for label in ("ORDER", "TIP VIA AD", "EXPLORE 3D"):
        if label not in menu:
            fail("main menu missing button %s" % label)
        else:
            ok("menu has " + label)
    readme = open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
    if "Fresh Batch" not in readme or "America/Chicago" not in readme:
        fail("README missing Fresh Batch / America/Chicago hunt")
    else:
        ok("README documents Fresh Batch hunt")
    hud = open(os.path.join(ROOT, "scenes/explore/explore_3d.tscn"), encoding="utf-8").read()
    if "FreshTip" not in hud:
        fail("explore HUD missing FreshTip banner")
    else:
        ok("explore HUD has Fresh Batch tip UI")
    mascot = open(os.path.join(ROOT, "scripts/explore/sunshine_mascot.gd"), encoding="utf-8").read()
    if "sunshine-logo-girl.jpg" not in mascot:
        fail("mascot does not reference branding logo")
    else:
        ok("3D mascot uses branding logo texture")
    cams = open(os.path.join(ROOT, "scripts/explore/review_cameras.gd"), encoding="utf-8").read()
    for name in (
        "Entrance",
        "Counter",
        "Dining",
        "LeftCorner",
        "RightCorner",
        "SunshineCloseup",
        "PastryCase",
        "Exterior",
    ):
        if '"%s"' % name not in cams:
            fail("review camera missing " + name)
        else:
            ok("review camera " + name)
    presets = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
    if "use_gradle_build=false" not in presets:
        fail("Android preset should default to no Gradle for first sideload")
    else:
        ok("Android preset Gradle off for first APK")
    if "icon-192.png" not in presets:
        fail("Android launcher icon should be PNG")
    else:
        ok("Android launcher icon PNG")


def main() -> int:
    os.chdir(ROOT)
    check_paths()
    check_scenes_mention_features()
    check_live_menu()
    if FAILS:
        print("\n%d failure(s)" % len(FAILS))
        return 1
    print("\nAll scaffold checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
