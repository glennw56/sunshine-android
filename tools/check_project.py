#!/usr/bin/env python3
"""Scaffold sanity: res:// paths exist, branding logo present, live catalog reachable."""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
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
        "scenes/account/login.tscn",
        "scripts/autoload/account_client.gd",
        "scripts/account/login_screen.gd",
        "server/account.py",
        "assets/branding/storefront-hero.jpg",
        "assets/explore/chatgpt_voxel_1.png",
        "assets/explore/chatgpt_voxel_2.png",
        "scenes/order/order.tscn",
        "scenes/tip_ad/tip_ad.tscn",
        "scenes/explore/explore_3d.tscn",
        "scripts/explore/sunshine_mascot.gd",
        "scripts/explore/review_cameras.gd",
        "scripts/explore/look_pad.gd",
        "scripts/ui/bakery_theme.gd",
        "scripts/ui/storefront_photo.gd",
        "assets/fonts/Nunito-Variable.ttf",
        "assets/fonts/OFL.txt",
        "assets/models/README.md",
        "assets/models/sunshine_logo_girl.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4_v2.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4_v3.glb",
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
    cust_url = os.environ.get("SUNSHINE_ORDER_URL", "https://bakery-drinks-k6uuoen7wa-ue.a.run.app").rstrip(
        "/"
    ) + "/order/api/account"
    try:
        with urllib.request.urlopen(cust_url, timeout=20) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        if isinstance(payload, dict) and payload.get("customer"):
            fail("unauthenticated GET /order/api/account should not dump a customer")
        else:
            ok("GET /order/api/account without session did not dump a customer")
    except urllib.error.HTTPError as exc:
        ok("GET /order/api/account without session HTTP %s (no public PII dump)" % exc.code)
    except Exception as exc:
        print("WARN: live account GET: %s" % exc)


def check_scenes_mention_features() -> None:
    menu = open(os.path.join(ROOT, "scenes/main_menu.tscn"), encoding="utf-8").read()
    for label in ("ORDER", "PREVIOUS ORDERS", "TIP VIA AD", "EXPLORE 3D"):
        if label not in menu:
            fail("main menu missing button %s" % label)
        else:
            ok("menu has " + label)
    if "storefront-hero.jpg" not in menu or "Storefront" not in menu:
        fail("main menu should be built around the storefront photo")
    elif "chatgpt" in menu.lower() or "voxel_1" in menu or "voxel_2" in menu:
        fail("main menu must stay the real storefront photo, not ChatGPT concept art")
    else:
        ok("main menu uses storefront-hero.jpg")
    if 'text = "Settings"' in menu or '[node name="Settings"' in menu or '[node name="Gear"' in menu:
        fail("customer main menu must not show Settings")
    else:
        ok("main menu has no Settings")
    login = open(os.path.join(ROOT, "scenes/account/login.tscn"), encoding="utf-8").read()
    for needle in ("Phone", "Continue", "Skip for now", "Join Sunshine"):
        if needle not in login:
            fail("login scene missing " + needle)
        else:
            ok("login has " + needle)
    for needle in ("FirstName", "LastName", "Email", "Save to Square"):
        if needle not in login:
            fail("login scene missing profile field " + needle)
        else:
            ok("login has profile " + needle)
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
    if "LookPad" not in hud or '[node name="Joy"' not in hud:
        fail("explore HUD missing on-screen joystick / look pad")
    elif "LookLeft" in hud or "LOOK · drag" in hud or "◀ LOOK" in hud:
        fail("explore HUD must not show LOOK arrows or drag coaching")
    else:
        ok("explore HUD has silent joystick + look drag pad")
    if "on-screen" not in readme.lower() and "left stick" not in readme.lower():
        fail("README missing on-screen Explore controls")
    else:
        ok("README documents on-screen Explore controls")
    if "pink" not in readme.lower() or "deck" not in readme.lower():
        fail("README should describe the Irondale patio / deck Explore")
    else:
        ok("README documents Irondale patio Explore")
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
    screen = open(os.path.join(ROOT, "scripts/order/order_screen.gd"), encoding="utf-8").read()
    client = open(os.path.join(ROOT, "scripts/autoload/order_client.gd"), encoding="utf-8").read()
    if "_jump_to_section" not in screen or "_bind_photo" not in screen:
        fail("order screen should show photos and category jumps")
    else:
        ok("order screen has photos + category jumps")
    for needle in ("_render_cart_tip", "TIP_PERCENTS", '"Custom"', '"No tip"', "%d%%"):
        if needle not in screen:
            fail("order cart missing tip control %s" % needle)
        else:
            ok("order cart has " + needle.strip('"'))
    if "line_mod_summary(" not in client or "line_mod_labels(" not in client or "visible_mod_line(" not in client or "cart_bar_text(" not in client:
        fail("OrderClient must expose cart modifier labels for checkout")
    else:
        ok("OrderClient cart modifier labels")
    if "visible_mod_line(" not in screen or "cart_bar_text(" not in screen:
        fail("cart/checkout must list selected modifiers on each line")
    else:
        ok("order cart lists modifiers")
    if "available_mod_preview(" not in screen:
        fail("menu rows should preview Square modifier groups")
    else:
        ok("menu rows preview Square extras")
    menu = open(os.path.join(ROOT, "scripts/ui/main_menu.gd"), encoding="utf-8").read()
    if "visible_mod_line(" not in menu:
        fail("Previous orders must list modifiers on each line")
    else:
        ok("previous orders list modifiers")
    account = open(os.path.join(ROOT, "scripts/autoload/account_client.gd"), encoding="utf-8").read()
    if "focus_cart" not in account or "order_item_mod_match_keys(" not in account:
        fail("order-again should map Square mods and open the cart")
    else:
        ok("order-again maps Square mods")
    if '"amount_cents"' not in client:
        fail("checkout tip must send amount_cents (bakery-drinks rejects cents)")
    else:
        ok("checkout custom tip uses amount_cents")
    if "func checkout_tip(" not in client or "func checkout_payload(" not in client:
        fail("OrderClient should expose checkout_tip / checkout_payload")
    else:
        ok("OrderClient checkout tip payload helpers")
    if "sold_out" not in client:
        fail("OrderClient should still read Square sold_out flags")
    else:
        ok("OrderClient reads sold_out")
    if "func bakery_case_items(" in client or "pistachio-croissant" in client or "_fallback_drink(" in client:
        fail("OrderClient must not invent a fallback bakery menu")
    elif "empty_catalog(" not in client or "square_commerce_links(" not in client:
        fail("OrderClient should load Square Online + drinks and empty on failure")
    else:
        ok("OrderClient is Square-only (no invented fallback menu)")
    if "func placeholder_photo(" not in client or "func item_photo_url(" not in client:
        fail("OrderClient should map Square photos and a no-photo fallback")
    elif "square_photos.json" not in client or "func square_photo_for(" not in client:
        fail("OrderClient should load Square catalog image URLs for food + drinks")
    elif "no_photo.png" not in client:
        fail("OrderClient fallback must be the neutral no-photo tile, not a pastry doodle")
    else:
        ok("OrderClient maps Square catalog photos")
    photos_json = os.path.join(ROOT, "assets/generated/menu/square_photos.json")
    if not os.path.isfile(photos_json):
        fail("missing Square photo map assets/generated/menu/square_photos.json")
    else:
        try:
            payload = json.loads(open(photos_json, encoding="utf-8").read())
        except Exception as exc:
            fail("square_photos.json is not JSON: %s" % exc)
            payload = {}
        photos = payload.get("photos") if isinstance(payload, dict) else None
        if not isinstance(photos, dict) or len(photos) < 10:
            fail("square_photos.json should list Square HTTPS photos")
        elif "Almond Croissant" not in photos or "items-images-production.s3" not in json.dumps(photos):
            fail("square_photos.json should include bakery-case + drink Square URLs")
        else:
            ok("square_photos.json has %d Square URLs" % len(photos))
    no_photo = os.path.join(ROOT, "assets/generated/menu/no_photo.png")
    if not os.path.isfile(no_photo) or os.path.getsize(no_photo) < 400:
        fail("missing neutral no-photo tile")
    else:
        ok("no-photo fallback tile")
    app_cfg = open(os.path.join(ROOT, "scripts/autoload/app_config.gd"), encoding="utf-8").read()
    if "func square_commerce_links(" not in app_cfg:
        fail("AppConfig should expose Square Online commerce-links")
    else:
        ok("AppConfig has Square Online catalog URL")
    if "func square_store_catalog(" not in app_cfg or "low_subunits" not in client:
        fail("OrderClient must map Square store catalog amounts (low_subunits) into price_cents")
    elif "func _square_price_cents(" not in client or "func display_price(" not in client:
        fail("OrderClient should parse Square price maps and display $ or —")
    else:
        ok("OrderClient maps Square store catalog prices")
    screen = open(os.path.join(ROOT, "scripts/order/order_screen.gd"), encoding="utf-8").read()
    if "display_price(" not in screen or "_refresh_cart_bar" not in screen:
        fail("order rows must show Square prices and a sticky cart total")
    else:
        ok("order screen shows Square prices + cart total")
    if "Staff" in screen or "_render_staff" in screen or "Tab.STAFF" in screen:
        fail("customer Order screen must not include a Staff tab")
    else:
        ok("Order screen has no Staff tab")
    if "ahead" not in screen or "Log in with phone" not in screen:
        fail("Status should be the logged-in customer's queue with N ahead")
    else:
        ok("Status is personal + queue ahead")
    account = open(os.path.join(ROOT, "scripts/autoload/account_client.gd"), encoding="utf-8").read()
    if "SQUARE_ACCESS_TOKEN" in account or "sq0atp" in account or "TWILIO" in account:
        fail("Square/Twilio secrets must not appear in the Godot client")
    elif "?phone=" in account or "?customer_id=" in account:
        fail("AccountClient must not GET customer PII by phone/customer_id query")
    elif "otp" in account:
        fail("AccountClient must not implement SMS text-code login")
    elif "session_token" not in account or "Authorization: Bearer" not in account:
        fail("AccountClient should POST login and send session Bearer when drinks provides a token")
    elif "account_phone_api(" not in account:
        fail("AccountClient should call bakery-drinks account_phone_api")
    elif "func update_profile(" not in account or "func needs_profile(" not in account:
        fail("AccountClient should update Square profile via bakery-drinks")
    elif "account_profile_api(" not in account:
        fail("AccountClient should POST/PATCH bakery-drinks account_profile_api")
    else:
        ok("AccountClient POST login + session Bearer, no phone GET, no OTP")
    login_ui = open(os.path.join(ROOT, "scripts/account/login_screen.gd"), encoding="utf-8").read()
    login_tscn = open(os.path.join(ROOT, "scenes/account/login.tscn"), encoding="utf-8").read()
    if "Request code" in login_tscn or "otp" in login_ui:
        fail("login UI must stay phone Continue (no text-code step)")
    elif "Continue" not in login_tscn or "Skip for now" not in login_tscn:
        fail("login UI needs Continue + Skip for now")
    else:
        ok("login UI is phone Continue + Skip, no OTP")
    if "func account_phone_api(" not in app_cfg or "func customer_api(" not in app_cfg:
        fail("AppConfig should expose account_phone_api and customer_api")
    elif "func account_profile_api(" not in app_cfg:
        fail("AppConfig should expose account_profile_api for Square UpdateCustomer")
    else:
        ok("AppConfig has Square account URLs")
    account_py = open(os.path.join(ROOT, "server/account.py"), encoding="utf-8").read()
    if "/order/api/account/profile" not in account_py or "def update_customer_profile(" not in account_py:
        fail("server/account.py must expose UpdateCustomer profile route")
    elif "PUT" not in account_py or "/v2/customers/" not in account_py:
        fail("profile update must call Square UpdateCustomer")
    else:
        ok("server/account.py has Square UpdateCustomer profile route")
    theme = open(os.path.join(ROOT, "scripts/ui/bakery_theme.gd"), encoding="utf-8").read()
    if "class_name BakeryTheme" not in theme:
        fail("bakery_theme.gd missing class_name BakeryTheme")
    else:
        ok("bakery_theme.gd has class_name BakeryTheme")
    preload_needle = 'preload("res://scripts/ui/bakery_theme.gd")'
    for rel in (
        "scripts/ui/main_menu.gd",
        "scripts/account/login_screen.gd",
        "scripts/order/order_screen.gd",
        "scripts/tip/tip_screen.gd",
        "scripts/explore/explore_hud.gd",
        "scripts/explore/look_pad.gd",
    ):
        text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        if preload_needle not in text:
            fail("%s must preload bakery_theme.gd (class_name is not enough on a clean .godot)" % rel)
        else:
            ok("%s preloads bakery_theme.gd" % rel)
    hud = open(os.path.join(ROOT, "scripts/explore/explore_hud.gd"), encoding="utf-8").read()
    if 'preload("res://scripts/explore/look_pad.gd")' not in hud:
        fail("explore_hud.gd must preload look_pad.gd (LookPad class_name is not enough on a clean .godot)")
    else:
        ok("explore_hud.gd preloads look_pad.gd")
    world = open(os.path.join(ROOT, "scripts/explore/bakery_world.gd"), encoding="utf-8").read()
    if "Sunshines_Bakery_Storefront_Godot4.glb" not in world or "ChatGPTStorefront" not in world:
        fail("Explore should instance the ChatGPT bakery GLB as the walkable storefront")
    elif "village_npc" not in world:
        fail("bakery_world.gd should still spawn staff in village_npc")
    elif "e8b4b8" not in world and "PINK" not in world:
        fail("bakery_world.gd should keep blush pink trim")
    elif "assets/foss/grass.jpg" not in world:
        fail("bakery_world.gd should use documented CC0 foss textures")
    else:
        ok("bakery_world.gd instances the ChatGPT GLB storefront")
    notice = os.path.join(ROOT, "assets/foss/NOTICE.md")
    if not os.path.isfile(notice) or "CC0" not in open(notice, encoding="utf-8").read():
        fail("assets/foss/NOTICE.md should document CC0 Explore textures")
    else:
        ok("FOSS Explore textures are documented")
    for tex in ("grass.jpg", "wood.jpg", "asphalt.jpg", "concrete.jpg", "plaster.jpg", "grass_block.png", "clapboard.png"):
        path = os.path.join(ROOT, "assets/foss", tex)
        if not os.path.isfile(path) or os.path.getsize(path) < 400:
            fail("missing FOSS texture " + tex)
        else:
            ok("FOSS texture " + tex)


def check_tip_payload_shapes() -> None:
    """Unit-style check of bakery-drinks POST /order/api/checkout tip shapes."""

    def valid(tip: dict) -> bool:
        kind = tip.get("type")
        if kind == "none":
            return True
        if kind == "percent":
            return tip.get("percent") in (15, 18, 20)
        if kind == "custom":
            cents = tip.get("amount_cents")
            return isinstance(cents, int) and 0 <= cents <= 10000
        return False

    def parse_custom_tip_cents(raw: str):
        text = str(raw).strip()
        if text.startswith("$"):
            text = text[1:]
        text = text.replace(",", "").strip()
        if text.endswith(("c", "C", "¢")):
            core = text[:-1].strip()
            if not core.isdigit():
                return None
            return int(core)
        if not text:
            return 0
        if re.match(r"^\d+(\.\d{0,2})?$", text) is None:
            return None
        return int(round(float(text) * 100.0))

    def percent_tip_cents(subtotal: int, percent: int) -> int:
        if percent < 1 or subtotal < 1:
            return 0
        return (subtotal * percent + 50) // 100

    good = (
        {"type": "none"},
        {"type": "percent", "percent": 15},
        {"type": "percent", "percent": 18},
        {"type": "percent", "percent": 20},
        {"type": "custom", "amount_cents": 0},
        {"type": "custom", "amount_cents": 100},
        {"type": "custom", "amount_cents": 10000},
    )
    bad = (
        {"type": "custom", "cents": 100},
        {"type": "percent", "percent": 16},
        {"type": "percent"},
        {"type": "custom"},
        {"type": "nope"},
        {"type": "custom", "amount_cents": 10001},
        {"type": "custom", "amount_cents": -1},
    )
    for tip in good:
        if not valid(tip):
            fail("expected valid tip shape %s" % tip)
        else:
            ok("tip shape %s" % tip)
    for tip in bad:
        if valid(tip):
            fail("expected invalid tip shape %s" % tip)
        else:
            ok("reject tip shape %s" % tip)

    if parse_custom_tip_cents("") != 0:
        fail("empty custom tip should parse as 0")
    else:
        ok("parse empty custom tip = 0")
    if parse_custom_tip_cents("1.00") != 100 or parse_custom_tip_cents("$1.50") != 150:
        fail("dollar custom tip parse")
    else:
        ok("parse $1.00 / $1.50")
    if parse_custom_tip_cents("150c") != 150:
        fail("cents-suffix custom tip parse")
    else:
        ok("parse 150c")
    if parse_custom_tip_cents("nope") is not None:
        fail("nonsense custom tip should be rejected")
    else:
        ok("reject nonsense custom tip")
    if percent_tip_cents(850, 15) != 128:
        fail("15% of 850 cents should be 128 (live checkout tip_cents)")
    else:
        ok("percent tip rounding 850@15% = 128")


def main() -> int:
    os.chdir(ROOT)
    check_paths()
    check_scenes_mention_features()
    check_tip_payload_shapes()
    check_live_menu()
    if FAILS:
        print("\n%d failure(s)" % len(FAILS))
        return 1
    print("\nAll scaffold checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
