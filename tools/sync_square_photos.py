#!/usr/bin/env python3
"""One-shot + refresh: Square catalog image URLs for every Sunshine item.

bakery-drinks /order/api/menu is drinks-only today. Food photos come from the
same Square Online catalog the drinks use (merchant ML089M4WW1WX2):

  1) GET bakery-drinks /order/api/menu → drink `photo` (items-images S3)
  2) If SQUARE_ACCESS_TOKEN is set → Square Catalog Search (ITEM + IMAGE)
  3) Always: Square Online commerce-links + each product og:image
     (Weebly/Square CDN copies of the catalog photos)

Writes assets/generated/menu/square_photos.json. The app loads that file and
also refreshes Square Online at runtime. No FOSS/cartoon pastry tiles.
"""

from __future__ import annotations

import json
import os
import re
import ssl
import concurrent.futures
import urllib.error
import urllib.request
from datetime import datetime, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "generated", "menu", "square_photos.json")
SITE = "https://www.sunshinebakeshop.com"
SITE_UUID = "30aacb50-1317-11ef-ad4f-279b7b292d3d"
DRINKS_MENU = os.environ.get(
    "SUNSHINE_ORDER_URL", "https://bakery-drinks-k6uuoen7wa-ue.a.run.app"
).rstrip("/") + "/order/api/menu"
SQUARE_CATALOG = "https://connect.squareup.com/v2/catalog/search"
CTX = ssl.create_default_context()

ALIASES = {
    "cookie croissant": "Chocolate Chip Cookie Croissant",
    "chocolate chip cookie croissant": "Chocolate Chip Cookie Croissant",
    "blueberry roll": "Blueberry roll",
    "japanese milk bread": "Milk Bread",
    "milk bread": "Milk Bread",
    "cajun blossom": "Cajun Bloom",
    "cajun bloom": "Cajun Bloom",
}

UA = {
    "User-Agent": "SunshineBakeryPhotoSync/0.1.5",
    "Accept": "application/json,text/html,*/*",
    "Referer": SITE + "/",
}


def _get(url: str, headers: dict | None = None, timeout: int = 25) -> tuple[int, bytes]:
    h = dict(UA)
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def _post(url: str, payload: dict, headers: dict | None = None) -> tuple[int, bytes]:
    h = dict(UA)
    h["Content-Type"] = "application/json"
    if headers:
        h.update(headers)
    raw = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=raw, headers=h, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30, context=CTX) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def is_real_photo(url: str) -> bool:
    u = (url or "").strip()
    if not u.startswith("https://"):
        return False
    if "items-images-production.s3" in u:
        return True
    if "items-images-sandbox.s3" in u:
        return True
    if "cdn6.editmysite.com/uploads/" in u and re.search(r"\.(jpe?g|png|webp)(\?|$)", u, re.I):
        return True
    return False


def norm(name: str) -> str:
    return re.sub(r"\s+", " ", (name or "").strip().lower())


def fetch_drinks() -> dict[str, dict]:
    code, body = _get(DRINKS_MENU)
    if code < 200 or code >= 300:
        print("drinks menu HTTP", code)
        return {}
    data = json.loads(body.decode("utf-8"))
    out: dict[str, dict] = {}
    for row in data.get("drinks") or []:
        if not isinstance(row, dict):
            continue
        photo = str(row.get("photo") or "").strip()
        if not is_real_photo(photo):
            continue
        name = str(row.get("name") or "").strip()
        out[norm(name)] = {
            "name": name,
            "photo": photo,
            "source": "bakery-drinks",
            "catalog_object_id": str(row.get("catalog_object_id") or ""),
            "item_id": str(row.get("item_id") or row.get("id") or ""),
        }
    print("drinks with Square S3 photos:", len(out))
    return out


def fetch_square_catalog_token() -> dict[str, dict]:
    token = os.environ.get("SQUARE_ACCESS_TOKEN", "").strip()
    if not token:
        print("SQUARE_ACCESS_TOKEN unset — skip Catalog Search")
        return {}
    out: dict[str, dict] = {}
    cursor = ""
    images: dict[str, str] = {}
    items: list[dict] = []
    while True:
        body = {
            "object_types": ["ITEM", "IMAGE"],
            "include_related_objects": True,
            "limit": 100,
        }
        if cursor:
            body["cursor"] = cursor
        code, raw = _post(
            SQUARE_CATALOG,
            body,
            {"Authorization": "Bearer " + token, "Square-Version": "2024-01-18"},
        )
        if code < 200 or code >= 300:
            print("Square Catalog Search HTTP", code, raw[:180])
            break
        payload = json.loads(raw.decode("utf-8"))
        for obj in list(payload.get("objects") or []) + list(payload.get("related_objects") or []):
            if not isinstance(obj, dict):
                continue
            if obj.get("type") == "IMAGE":
                img = obj.get("image_data") or {}
                url = str(img.get("url") or "")
                if is_real_photo(url):
                    images[str(obj.get("id") or "")] = url
            elif obj.get("type") == "ITEM":
                items.append(obj)
        cursor = str(payload.get("cursor") or "")
        if not cursor:
            break
    for obj in items:
        data = obj.get("item_data") or {}
        name = str(data.get("name") or "").strip()
        image_ids = list(data.get("image_ids") or [])
        url = ""
        for iid in image_ids:
            if iid in images:
                url = images[iid]
                break
        if not url:
            continue
        out[norm(name)] = {
            "name": name,
            "photo": url,
            "source": "square-catalog",
            "catalog_object_id": str(obj.get("id") or ""),
        }
    print("Square Catalog items with images:", len(out))
    return out


def fetch_square_online() -> dict[str, dict]:
    url = f"{SITE}/app/website/cms/api/v1/sites/{SITE_UUID}/commerce-links"
    code, body = _get(url)
    if code < 200 or code >= 300:
        print("commerce-links HTTP", code)
        return {}
    data = json.loads(body.decode("utf-8"))
    products = data.get("products") or {}
    print("Square Online products:", len(products))

    def scrape(prod: dict) -> dict | None:
        name = str(prod.get("name") or "").strip()
        link = str(prod.get("site_link") or "").strip()
        if not name or not link:
            return None
        page = SITE + link
        pcode, html = _get(page)
        if pcode < 200 or pcode >= 300:
            return None
        text = html.decode("utf-8", "replace")
        og = re.findall(r'property="og:image"\s+content="([^"]+)"', text)
        if not og:
            og = re.findall(r'content="([^"]+)"\s+property="og:image"', text)
        photo = og[0] if og else ""
        if not is_real_photo(photo):
            extras = re.findall(
                r'https://149698726\.cdn6\.editmysite\.com/uploads/[^"\']+\.(?:jpe?g|png|webp)',
                text,
                re.I,
            )
            photo = extras[0] if extras else ""
        if not is_real_photo(photo):
            return None
        return {
            "name": name,
            "photo": photo,
            "source": "square-online",
            "site_product_id": str(prod.get("site_product_id") or ""),
            "site_link": link,
        }

    out: dict[str, dict] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        futs = [pool.submit(scrape, p) for p in products.values() if isinstance(p, dict)]
        for fut in concurrent.futures.as_completed(futs):
            row = fut.result()
            if row:
                out[norm(row["name"])] = row
    print("Square Online products with photos:", len(out))
    return out


def merge(*tables: dict[str, dict]) -> dict[str, dict]:
    """Later tables win only when they have a real photo; drinks S3 preferred first."""
    out: dict[str, dict] = {}
    for table in tables:
        for key, row in table.items():
            if key not in out:
                out[key] = row
                continue
            # Prefer bakery-drinks / catalog S3 over Weebly CDN when both exist.
            prev = out[key]
            prev_s3 = "items-images" in prev.get("photo", "")
            new_s3 = "items-images" in row.get("photo", "")
            if new_s3 and not prev_s3:
                out[key] = row
    return out


def main() -> int:
    drinks = fetch_drinks()
    catalog = fetch_square_catalog_token()
    online = fetch_square_online()
    # Prefer official Catalog / drinks S3, then Square Online CDN copies.
    merged = merge(online, catalog, drinks)
    photos = {row["name"]: row["photo"] for row in merged.values()}
    items = sorted(merged.values(), key=lambda r: r["name"].lower())
    payload = {
        "source": "square",
        "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "drinks_api": DRINKS_MENU,
        "square_online": f"{SITE}/app/website/cms/api/v1/sites/{SITE_UUID}/commerce-links",
        "aliases": ALIASES,
        "photos": photos,
        "items": items,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
        fh.write("\n")
    print("wrote", OUT, "photos", len(photos))
    needed = [
        "Almond Croissant",
        "Pistachio Croissant",
        "Plain Croissant",
        "Chocolate Chip Cookie Croissant",
        "Strawberry Croissant",
        "Blueberry roll",
        "Plain Sourdough",
        "Milk Bread",
        "Cajun Bloom",
        "Biscoff Coffee",
    ]
    missing = [n for n in needed if n not in photos]
    if missing:
        print("WARNING missing expected Square photos:", missing)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
