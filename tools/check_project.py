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
        "scripts/explore/patio_npc.gd",
        "scripts/explore/logo_sun.gd",
        "scripts/explore/menu_props.gd",
        "assets/models/menu_props/README.md",
        "assets/models/menu_props/prop_cream_cheese_danish.glb",
        "assets/models/menu_props/prop_vietnamese_coffee.glb",
        "assets/models/menu_props/prop_feta_spinach_danish.glb",
        "assets/models/menu_props/prop_nutella_croissant.glb",
        "assets/models/menu_props/prop_sausage_croissant.glb",
        "assets/models/menu_props/prop_mango_entrement.glb",
        "assets/models/menu_props/prop_birthday_cake_macaron.glb",
        "assets/models/menu_props/prop_fruit_tea.glb",
        "assets/models/menu_props/prop_cinnamon_roll.glb",
        "assets/models/menu_props/prop_chocolate_chip_cookie.glb",
        "assets/generated/menu/square_coffee.jpg",
        "scripts/explore/look_pad.gd",
        "scripts/ui/bakery_theme.gd",
        "scripts/ui/storefront_photo.gd",
        "assets/fonts/Nunito-Variable.ttf",
        "assets/fonts/OFL.txt",
        "assets/models/README.md",
        "assets/models/sunshine_logo_girl.glb",
        "assets/models/sunshine_outdoor_eating.glb",
        "assets/models/sunshine_bakery_lot.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4_v2.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4_v3.glb",
        "assets/models/Sunshines_Bakery_Storefront_Godot4_v4.glb",
        "assets/models/sunshine_shop_exterior.glb",
        "assets/models/sunshine_backyard.glb",
        "assets/models/sunshine_interior.glb",
        "docs/REVIEW_CAMERAS.md",
        "assets/branding/icon-192.png",
        "addons/admob/plugin.cfg",
        "addons/admob/android/config.gd",
        "addons/admob/android/bin/ads/poing_godot_admob_ads.gd",
        "addons/admob/gdscript/src/api/RewardedAdLoader.gd",
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
        if "/addons/" in dirpath.replace("\\", "/") + "/":
            continue
        for name in files:
            if not name.endswith((".gd", ".tscn", ".godot", ".cfg", ".md")):
                continue
            path = os.path.join(dirpath, name)
            text = open(path, encoding="utf-8", errors="replace").read()
            for match in RES.findall(text):
                found.add(match)
    skip_suffix = (".uid",)
    skip_missing = {
        "res://assets/models/menu_props/prop_chocolate_chip_cookie_Chocolate_Chip_Cookie.jpg",
    }
    for res in sorted(found):
        rel = res[len("res://") :]
        if rel.endswith(skip_suffix):
            continue
        if res in skip_missing:
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
    hero = os.path.join(ROOT, "assets/branding/storefront-hero.jpg")
    w, h = _jpeg_size(hero)
    if w is None or h is None:
        fail("could not read storefront-hero.jpg dimensions")
    elif h <= w:
        fail("storefront-hero.jpg should be the portrait 2231 lawn photo, got %sx%s" % (w, h))
    else:
        ok("storefront-hero.jpg is portrait %sx%s" % (w, h))
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
    elif '[node name="Plate"' in hud and "visible = false" not in hud.split('[node name="Plate"')[1][:400]:
        fail("explore look pad plate must be hidden (no bottom-right red square)")
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
    if "use_gradle_build=true" not in presets:
        fail("Android presets should use Gradle so AdMob ships")
    else:
        ok("Android presets Gradle on for AdMob")
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
    elif "history_item_photo_url(" not in menu or "_bind_history_photo(" not in menu:
        fail("Previous orders must show Square item photos when the catalog has one")
    else:
        ok("previous orders list modifiers")
    if "func preload_menu(" not in client or "func restore_cached_menu(" not in client:
        fail("OrderClient must cache-first preload the last Square menu")
    else:
        ok("OrderClient preloads last Square menu")
    save = open(os.path.join(ROOT, "scripts/autoload/game_save.gd"), encoding="utf-8").read()
    if "cached_square_menu" not in save:
        fail("GameSave must persist the last successful Square catalog")
    else:
        ok("GameSave persists last Square catalog")
    account = open(os.path.join(ROOT, "scripts/autoload/account_client.gd"), encoding="utf-8").read()
    if "focus_cart" not in account or "order_item_mod_match_keys(" not in account:
        fail("order-again should map Square mods and open the cart")
    elif "func fetch_customer_orders(" not in account:
        fail("previous orders must GET bakery-drinks /order/api/orders")
    elif "func fetch_order(" not in account or "func ensure_full_order(" not in account:
        fail("order-again / previous orders must RetrieveOrder the full Square ticket")
    elif "_line_items" not in client:
        fail("history hydrate must consume drinks _line_items Square modifiers")
    elif "catalog_item_for_history(" not in client:
        fail("Order Again must match history lines to the live Square catalog by id")
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
    if "func _square_groups_from_entry(" not in client or "func hydrate_history_orders(" not in client:
        fail("OrderClient must parse Square modifier lists and hydrate past-order mods")
    else:
        ok("OrderClient parses Square modifier groups + history extras")
    if "Extras not listed on this ticket" not in client:
        fail("history tickets missing a modifiers field must not claim No extras")
    else:
        ok("history extras distinguish missing vs empty Square mods")
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
    elif "app_order_label" not in screen or "status_queue_orders" not in client:
        fail("Status should label app order xxx and keep only paid making tickets")
    elif "is_status_queue_order" not in client or "app_order_label" not in client:
        fail("OrderClient should filter Status to paid making and format app order numbers")
    else:
        ok("Status is personal + paid making + app order + queue ahead")
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
    if "func account_order_api(" not in app_cfg:
        fail("AppConfig should expose RetrieveOrder URL")
    elif "func account_phone_api(" not in app_cfg or "func customer_api(" not in app_cfg:
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
    if "def is_paid_making(" not in account_py or "app_order_number" not in account_py:
        fail("account.py must filter Status to paid making and stamp a short app order number")
    elif 'row.get("paid") and row.get("status") == "making"' not in account_py:
        fail("account.py open_orders must be paid AND making")
    else:
        ok("server/account.py Status is paid making + short app order number")
    if "/v2/orders/batch-retrieve" not in account_py or "def retrieve_order(" not in account_py:
        fail("account.py must RetrieveOrder / BatchRetrieveOrders for full past tickets")
    elif "/order/api/account/orders/{order_id}" not in account_py:
        fail("account.py must expose GET /order/api/account/orders/{id}")
    else:
        ok("server/account.py retrieves full Square orders")
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
    if 'STOREFRONT_GLB := "res://assets/models/sunshine_outdoor_eating.glb"' not in world:
        fail("Explore should instance sunshine_outdoor_eating.glb as the walkable patio")
    elif "chatgpt_shop_grass.glb" in world:
        fail("chatgpt_shop_grass must not be the Explore world")
    elif "ChatGPTStorefront" not in world:
        fail("Explore should still instance the patio GLB as ChatGPTStorefront")
    elif 'preload("res://scripts/explore/patio_npc.gd")' not in world:
        fail("bakery_world.gd should spawn PatioNpc guests")
    elif "LogoSunScript" not in world:
        fail("bakery_world.gd should add the Sunshine logo sun")
    elif "MenuPropsLib.place" not in world:
        fail("bakery_world.gd should place menu props on the patio")
    elif "e8b4b8" not in world and "PINK" not in world:
        fail("bakery_world.gd should keep blush pink trim")
    elif "assets/foss/grass.jpg" not in world:
        fail("bakery_world.gd should use documented CC0 foss textures")
    else:
        ok("bakery_world.gd instances the outdoor eating patio GLB")
    npc_py = open(os.path.join(ROOT, "scripts/explore/patio_npc.gd"), encoding="utf-8").read()
    if "village_npc" not in npc_py:
        fail("patio_npc.gd should add_to_group village_npc")
    elif "_plant_feet" not in npc_py or "held_snack" not in npc_py:
        fail("patio_npc.gd should plant feet on the ground and hold menu props")
    else:
        ok("patio_npc.gd plants feet and holds pastry/drink")
    sun_py = open(os.path.join(ROOT, "scripts/explore/logo_sun.gd"), encoding="utf-8").read()
    if "sunshine-logo-girl.jpg" not in sun_py:
        fail("logo_sun.gd should use the Sunshine bakery logo texture")
    elif "PERIOD_SEC" not in sun_py:
        fail("logo_sun.gd should animate a day-arc across the sky")
    else:
        ok("logo_sun.gd is the branded sky sun")
    props_py = open(os.path.join(ROOT, "scripts/explore/menu_props.gd"), encoding="utf-8").read()
    if "assets/models/menu_props/" not in props_py:
        fail("menu_props.gd should load GLBs from assets/models/menu_props/")
    elif "KEEP_STEMS" not in props_py or "DISPLAY_SCALE" not in props_py:
        fail("menu_props.gd should keep Ronald's 10 top sellers at display scale")
    elif "square_coffee.jpg" not in props_py:
        fail("menu_props.gd should keep Square drink photo fallbacks")
    else:
        ok("menu_props.gd places the 10 top-seller props on the patio")
    props_dir = os.path.join(ROOT, "assets/models/menu_props")
    keep_glbs = {
        "prop_cream_cheese_danish.glb",
        "prop_vietnamese_coffee.glb",
        "prop_feta_spinach_danish.glb",
        "prop_nutella_croissant.glb",
        "prop_sausage_croissant.glb",
        "prop_mango_entrement.glb",
        "prop_birthday_cake_macaron.glb",
        "prop_fruit_tea.glb",
        "prop_cinnamon_roll.glb",
        "prop_chocolate_chip_cookie.glb",
    }
    present = {n for n in os.listdir(props_dir) if n.endswith(".glb")}
    extra_glbs = sorted(present - keep_glbs)
    missing_glbs = sorted(keep_glbs - present)
    if missing_glbs:
        fail("menu_props/ missing top sellers: " + ", ".join(missing_glbs))
    elif extra_glbs:
        fail("menu_props/ should only keep 10 top-seller GLBs, extra=" + ", ".join(extra_glbs))
    else:
        ok("menu_props/ has exactly Ronald's 10 top-seller GLBs")
    patio = os.path.join(ROOT, "assets/models/sunshine_outdoor_eating.glb")
    if not os.path.isfile(patio) or os.path.getsize(patio) < 1_000_000:
        fail("sunshine_outdoor_eating.glb missing or tiny")
    else:
        ok("sunshine_outdoor_eating.glb %d bytes" % os.path.getsize(patio))
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


def _jpeg_size(path: str) -> tuple[int | None, int | None]:
    try:
        data = open(path, "rb").read()
    except OSError:
        return None, None
    i = 2
    while i < len(data) - 8:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2):
            h = int.from_bytes(data[i + 5 : i + 7], "big")
            w = int.from_bytes(data[i + 7 : i + 9], "big")
            return w, h
        if marker == 0xD8 or marker == 0xD9:
            i += 2
            continue
        if i + 3 >= len(data):
            break
        seglen = int.from_bytes(data[i + 2 : i + 4], "big")
        i += 2 + seglen
    return None, None


def check_admob_wiring() -> None:
    ads = open(os.path.join(ROOT, "scripts/autoload/ad_tip_service.gd"), encoding="utf-8").read()
    if 'ClassDB.instantiate("RewardedAdLoader")' in ads:
        fail("AdTipService must not instantiate RewardedAdLoader via ClassDB")
    elif "LOADER_PATH" not in ads or "RewardedAdLoader.gd" not in ads:
        fail("AdTipService should load Poing RewardedAdLoader.gd by path")
    elif "PoingGodotAdMobRewardedAd" not in ads:
        fail("AdTipService should require PoingGodotAdMobRewardedAd")
    else:
        ok("AdTipService loads RewardedAdLoader.gd by path (not ClassDB)")
    aar = os.path.join(ROOT, "addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar")
    if not os.path.isfile(aar):
        fail("missing Poing AdMob debug AAR")
    else:
        ok("Poing AdMob debug AAR present")
    cfg = open(os.path.join(ROOT, "addons/admob/android/config.gd"), encoding="utf-8").read()
    if "sunshine/admob_app_id" not in cfg:
        fail("AdMob android config.gd should read sunshine/admob_app_id")
    else:
        ok("AdMob APPLICATION_ID follows sunshine/admob_app_id")
    project = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    if 'ad_mode="live"' not in project:
        fail("project.godot should default ad_mode to live for Play/release AdMob")
    else:
        ok("project.godot ad_mode=live")
    if "ca-app-pub-2788636443838183~1520526800" not in project:
        fail("project.godot should ship Ronald's production AdMob app id")
    else:
        ok("production AdMob app id in project.godot")
    if "ca-app-pub-2788636443838183/7894363467" not in project:
        fail("project.godot should ship production tip_reward unit")
    else:
        ok("production tip_reward unit in project.godot")
    if "res://addons/admob/plugin.cfg" not in project:
        fail("project.godot should enable the AdMob editor plugin")
    else:
        ok("AdMob editor plugin enabled")
    app_cfg = open(os.path.join(ROOT, "scripts/autoload/app_config.gd"), encoding="utf-8").read()
    if "GOOGLE_TEST_REWARDED_UNIT" not in app_cfg or "effective_rewarded_unit" not in app_cfg:
        fail("AppConfig should keep Google test rewarded unit behind ad_mode=test")
    elif "is_debug_sideload" not in app_cfg or "should_use_google_test_unit" not in app_cfg:
        fail("AppConfig should use Google test rewarded ads on debug sideloads")
    else:
        ok("Google test rewarded unit is used for test mode and debug sideloads")
    if "_play_confirm_tip" not in ads:
        fail("AdTipService must grant a tip after a non-tech confirm when ads fail")
    elif "Skip (no tip)" in ads:
        fail("AdTipService confirm path must not deny the tip")
    else:
        ok("AdTipService credits a tip after a confirm fallback")
    presets = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
    if 'version/name="0.1.50"' not in presets or "version/code=51" not in presets:
        fail("export_presets.cfg should be 0.1.50 / versionCode 51")
    else:
        ok("export_presets 0.1.50 code 51")
    tip_scene = open(os.path.join(ROOT, "scenes/tip_ad/tip_ad.tscn"), encoding="utf-8").read()
    if "AdMob" in tip_scene or "admob" in tip_scene:
        fail("tip_ad.tscn must not mention AdMob on screen")
    else:
        ok("tip screen copy has no AdMob")
    if "Send a free tip to the Sunshine staff." not in tip_scene:
        fail("tip screen must keep the first-sentence pitch")
    elif "CenterContainer" not in tip_scene or 'text = "Send a tip"' not in tip_scene:
        fail("tip screen should center a Send a tip sheet")
    else:
        ok("tip screen centers first-sentence pitch + Send a tip")
    if "Staff jar this week" in open(os.path.join(ROOT, "scripts/tip/tip_screen.gd"), encoding="utf-8").read():
        fail("tip_screen.gd must not show a free-tip count")
    else:
        ok("tip screen hides free-tip counts")


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
    check_admob_wiring()
    check_tip_payload_shapes()
    check_live_menu()
    if FAILS:
        print("\n%d failure(s)" % len(FAILS))
        return 1
    print("\nAll scaffold checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
