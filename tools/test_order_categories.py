#!/usr/bin/env python3
"""Verify live Square catalog maps onto Order UI chips (no Godot required)."""

from __future__ import annotations

import json
import sys
import urllib.request

DRINKS = "https://bakery-drinks-k6uuoen7wa-ue.a.run.app/order/api/menu"
STORE = (
    "https://cdn5.editmysite.com/app/store/api/v28/editor/users/149698726"
    "/sites/159839133986356010/store-locations/L4CK6YWGT5XQX/products"
    "?per_page=100&include=images,options,modifiers&cache-version=2026-03-25"
)

SQUARE_CATEGORY_IDS = {
    "BYKQS3P2SI7WP22F6BWKFZGR": "drink",
    "ROPXOXPWBYM42T3LJQESG3NX": "drink",
    "JPDWRRN3AWK3ROSJJ2CXY4CI": "drink",
    "OCV6MHUVAXUXXXFATFKLJNPI": "drink",
    "ST2VWDGCETTZ3PLB4O777RIC": "drink",
    "2HU26VZFGBMNS6KA4WUKTCMA": "pastry",
    "4I7E2RVKZ3BXRRLVRDDQPM4O": "pastry",
    "Z37F5BCY6NG65R6TL4RAIUTV": "pastry",
    "6H4R32VMU3YD235PHRVNJ5NO": "pastry",
    "YTJ2TQ3OOZAZEMB3PGB4LD5O": "pastry",
    "FYERUJILKHCRMTHEPZZDL6DD": "pastry",
    "2KNLDXSSU43PRA6SLHZWMXYE": "pastry",
    "OWW3LE5MJXWM6WKWKAZOTEV5": "pastry",
    "HQ3PHZ67S3AJCU57LIMT6AD2": "pastry",
    "UT4B6QESSSLJDIFEXNEPQINW": "savory",
    "3YCM7GHNPJJQULDPLIVXYSMJ": "savory",
    "O6WM5ELNM5MZUS5CXN3LBZK2": "savory",
    "SHTNBSR6RGM6FJ34QZ5TA6R6": "bread",
    "AOFDPLXQXL7GFWOTCT3C3BRB": "bread",
    "BD4NRJ5UQURXYGYBCMPAB6CO": "more",
    "NBSZUW2RBDK3DV4T2AL6XRHB": "more",
}

EXPECT = {
    "Vietnamese Coffee": "drink",
    "Coffee": "drink",
    "Fruit Tea": "drink",
    "Matcha Latte": "drink",
    "Water": "drink",
    "Coffee Tiramisu Cake": "pastry",
    "Chocolate Chip Cookie": "pastry",
    "Ham and Cheese Croissant": "savory",
    "Sausage Croissant": "savory",
    "Plain Sourdough": "bread",
    "Tote Bag": "more",
}


def fetch(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "SunshineBakery/0.1.71"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.load(resp)


def from_ids(ids) -> str:
    mapped = set()
    for raw in ids or []:
        key = SQUARE_CATEGORY_IDS.get(str(raw).strip(), "")
        if key:
            mapped.add(key)
    for key in ("drink", "savory", "bread", "more", "pastry"):
        if key in mapped:
            return key
    return ""


def main() -> int:
    drinks = fetch(DRINKS).get("drinks") or []
    store = fetch(STORE).get("data") or []
    by_name: dict[str, str] = {}
    for row in drinks:
        name = str(row.get("name", "")).strip()
        cat = from_ids(row.get("category_ids") or [])
        if name:
            by_name[name] = cat
    for row in store:
        name = str(row.get("name", "")).strip()
        cat = from_ids(row.get("categoryIds") or [])
        if name:
            by_name[name] = cat
    fails = 0
    for name, want in EXPECT.items():
        got = by_name.get(name)
        if got is None:
            print("NOTE missing live item", name)
            continue
        if got != want:
            print("FAIL", name, "got", got, "want", want)
            fails += 1
        else:
            print("OK  ", name, "->", got)
    if from_ids([]) != "":
        print("FAIL empty ids must be uncategorized")
        fails += 1
    buckets: dict[str, int] = {}
    for cat in by_name.values():
        key = cat or "uncategorized"
        buckets[key] = buckets.get(key, 0) + 1
    print("buckets", buckets)
    if buckets.get("drink", 0) < 5:
        print("FAIL expected several Square drinks")
        fails += 1
    if buckets.get("pastry", 0) < 10:
        print("FAIL expected a bakery case of sweets")
        fails += 1
    if fails:
        print("CATEGORY MAP FAIL", fails)
        return 1
    print("CATEGORY MAP OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
