# Sunshine’s Bakery (FOSS Android)

Godot **4.3+** (MIT) app for [Sunshine’s Bakery](http://sunshinebakeshop.com/),
2231 1st Ave S, Irondale AL 35210.

Sideload an APK first. Play Store comes later. No secrets in this repo.

**v0.1.23-debug APK:**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.23-debug/sunshines-bakery-0.1.23-debug.apk

On first launch the app asks for a **US phone** (no SMS code). **Continue** POSTs bakery-drinks (`/order/api/account/login`, then `/account/phone` / `/customer`). Found → sign in. Missing → CreateCustomer, with opt-in **Join Sunshine’s Bakery loyalty / save your orders**. If the Square customer has **no usable name**, a short form asks for **first name, last name, and email**, then **POST/PATCH `/order/api/account/profile`** (Square `UpdateCustomer`) — it is not stored only on the phone. If drinks returns a `session_token`, the app stores it and uses `Authorization: Bearer` for later account/orders/status/profile — it does **not** `GET ?phone=` (that dumps email/orders). **Skip for now** keeps guest browsing unblocked. Session (`customer_id` + phone + token) is stored in `user://`. **Log out** returns to the phone screen. Secrets stay on Cloud Run — see `server/HOW_TO_TEST.md`.

The **main menu** is the **real 2231 storefront photo** (`storefront-hero.jpg`), cropped so the **full circular logo** (girl + SUNSHINE’S BAKERY ring) stays on a phone portrait. ChatGPT voxel stills are Explore reference only — they are not the menu backdrop. After login it says **Hi, {First}** from Square. There is **no Settings** button. **PREVIOUS ORDERS** is a lawn button (with ORDER / TIP VIA AD / EXPLORE 3D): signed-in customers see Square tickets (name, date, total, items, Order again); guests get a short sign-in prompt.

Four main-menu options:

1. **ORDER** — Irondale kiosk whose **offers come from Square only**: live bakery-drinks (Square-backed drinks, prices, modifiers) plus the public Square Online store catalog for food (same `price_cents` / sticky cart total as drinks). **Every catalog item keeps every Square modifier list** — optional groups included (Reheat on pastries, Designs + Color on the tote, all drink extras). Menu rows preview those groups; tapping an item shows every option chip. **Cart, the sticky checkout bar, Status, and Previous orders all list each line’s chosen extras** (names, plus Square prices when Square sent them). **Order again** maps those extras back onto the live catalog and opens Cart with them pre-selected. Every row uses a Square image URL when Square has one. If Square sent no amount the row shows **—** — we do not invent prices or modifiers. If Square/network is down the menu is **empty** with Retry. Square checkout opens in the system browser. **Status** shows only that customer’s open Square orders and how many tickets are **ahead** in the Irondale queue. Guests see “Log in with phone to see your order status.” There is no Staff tab.
2. **PREVIOUS ORDERS** — Square SearchOrders for the signed-in session. Guests are asked to sign in with phone.
3. **TIP VIA AD** — thin **mock** stub. Credits a **FREE TIP to the STAFF jar** (not a customer perk). Do not expand AdMob for this MVP.
4. **EXPLORE 3D** — Ronald’s Y-up outdoor eating patio (`assets/models/sunshine_outdoor_eating.glb`: picnic/bistro tables, chairs, flower planters, cornhole, Sunshine logo wall, 90×80 m grass). The **main menu stays the real storefront photo**. Silent on-screen left stick + look drag pad (no LOOK/MOVE coaching). Collect **3 cube pastries** for stamps. Morning **Fresh Batch** hunt stays stubbed (9–11 America/Chicago logic is still in `GameSave`). Stamp card + local weekly finder leaderboard.

This is a **voxel-styled MVP** with CC0 textures (see `assets/foss/NOTICE.md`), not a photoreal remake.

## Open in Godot

1. Install [Godot 4.3 or 4.4+](https://godotengine.org/download) (standard or .NET — GDScript only here).
2. Import this folder (`project.godot`).
3. Press **F5**, or from a terminal: `godot --path .`
   You should land on the phone login (or the storefront-photo main menu if you skipped / already signed in). ORDER is the wine primary; PREVIOUS ORDERS / TIP VIA AD / EXPLORE 3D are secondary. Blush `#e8b4b8` + wine brown.

Desktop debug window is **480×800** so the left stick and look pad stay on a 1280×800 laptop. The logical viewport stays **720×1280**. For a larger phone frame: `godot --path . --resolution 720x1280`.

Explore 3D is built for a phone thumb zone (no on-screen coaching):

- **Move** — large on-screen left stick, bottom-left. Click or drag (mouse **or** touch). The stick is centered: tapping the top walks forward immediately.
- **Look** — silent drag pad, bottom-right. No LOOK arrows and no “drag” label.
- **Menu** — small **Menu** button (and **Esc**) returns home, without a tutorial line.

Details live in `scripts/explore/virtual_joystick.gd` and `look_pad.gd`.

### Explore 3D layout

The player spawns on the south lawn **facing the Sunshine logo wall** (yaw 0, looking −Z): picnic and bistro seating, string lights, planters, and the logo. **WASD** or the MOVE stick walk −Z across the grass toward the patio.

| Zone | What you see |
| --- | --- |
| **South lawn** | Enlarged 90×80 m grass field; spawn and cube pastries. |
| **Patio** | Picnic tables, bistro tables and chairs, flower planters, cornhole. |
| **Logo wall** | `Logo_Hero` / `LogoWall` at the north edge of the seating. |
| **Borders** | Low rails on north / east / west of the patio island. |

Three cube pastries spawn on the south lawn (Fresh Batch can add extras). **Esc** or **Menu** returns to the main menu. The hero reference is `assets/reference/storefront-hero.jpg`. Ground, siding, wood, asphalt, and bark use **CC0 ambientCG** maps (pixel-blocked grass/leaves for a clean Minecraft lawn — not ObjToSchematic) documented in `assets/foss/NOTICE.md`.

Eight fixed **review cameras** (Entrance, Counter, Dining, LeftCorner, RightCorner, SunshineCloseup, PastryCase, Exterior) live under `ReviewCameras`. Capture PNGs with:

```bash
godot --path . --headless -s res://tools/capture_review.gd
```

See `docs/REVIEW_CAMERAS.md`. Drop real `.glb` files into `assets/models/` (placeholders are in git; README there lists names and axes).

### Fresh Batch (morning hunt)

Shop-local **America/Chicago** (Irondale). Active **9:00–11:00** (until 11:00).

- Extra croissant and drink pickups spawn **on the south lawn** while the window is open.
- The **first 3 finds** that morning grant **2 stamps** on the free-drink stamp card (8 stamps = free drink). After that, finds are 1 stamp each.
- The local **weekly finder leaderboard** still counts **1 find** per pickup.
- The Explore HUD banner and status line tell you when it is live and how many 2× stamps remain.

Preview outside that window: `SUNSHINE_FRESH_BATCH=force` (or `off` to disable). Default is `auto`.

### Project layout

```
project.godot
scenes/account/login.tscn      # phone login / signup / skip
scenes/main_menu.tscn          # storefront photo · ORDER / PREVIOUS ORDERS / TIP / EXPLORE
scenes/order/order.tscn
scenes/tip_ad/tip_ad.tscn
scenes/explore/explore_3d.tscn
assets/branding/storefront-hero.jpg
assets/branding/sunshine-logo-girl.jpg
assets/models/                 # optional GLB drop-ins (stubs in git)
scripts/autoload/              # config, HTTP, account, notices, ads, save
server/account.py              # bakery-drinks Square Customers / Loyalty / Orders routes
```

## Environment (order URL + AdMob)

Godot reads **OS environment variables** at runtime, then `user://config.cfg`, then `[sunshine]` in `project.godot`. Copy `.env.example` for a local cheat sheet — **do not commit `.env`**.

| Variable | Default | Purpose |
| --- | --- | --- |
| `SUNSHINE_ORDER_URL` | `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` | bakery-drinks Cloud Run origin |
| `SUNSHINE_AD_MODE` | `mock` | `mock` (in-engine overlay), `test` (AdMob test unit), `live` (your unit, never git) |
| `SUNSHINE_ADMOB_APP_ID` | Google sample `ca-app-pub-3940256099942544~3347511713` | Safe test application id |
| `SUNSHINE_ADMOB_REWARDED_UNIT` | Google sample `ca-app-pub-3940256099942544/5224354917` | Safe test rewarded unit |
| `SUNSHINE_STAFF_PIN` | empty | Optional shop-tab PIN (set on the device, not in git) |
| `SUNSHINE_FRESH_BATCH` | `auto` | `auto` (9–11 America/Chicago), `force` (preview hunt), `off` |

Live APIs used (same as [bakery-drinks `/order`](https://bakery-drinks-k6uuoen7wa-ue.a.run.app/order)):

- `GET /order/api/menu` — Square catalog
- `POST /order/api/checkout` — hosted Square pay URL
- `GET /order/api/status?oid=` — customer status
- `GET /board` + `GET /board/tickets` — shop drink board

Order URL overrides stay in env / `user://config.cfg` (no in-app Settings screen).

## Android export (sideload APK)

Gradle is **off** on the bundled Android preset so the first sideload APK does **not** need “Install Android Build Template”.

Package id: `shop.sunshines.bakery`. Output: `export/sunshines-bakery.apk` (gitignored). Launcher icon: `assets/branding/icon-192.png`.

1. Install [Godot 4.3/4.4 export templates](https://godotengine.org/download) matching your editor (**Editor → Manage Export Templates**).
2. JDK **17** + Android SDK (`adb` in `platform-tools`). **Editor Settings → Export → Android**: SDK path, Java path, debug keystore.
3. If the keystore is missing: `bash tools/make_debug_keystore.sh` (standard `~/.android/debug.keystore`, alias/password `android`).
4. **Project → Export → Android → Export Project** → `export/sunshines-bakery.apk`
5. Sideload: `adb install -r export/sunshines-bakery.apk`  
   (or copy the APK to the phone).

More detail: `export/README.md`. Release keystore passwords stay in editor settings / CI, **never in this repo**.

CLI once the editor has SDK + templates:

```bash
godot --headless --path . --export-debug Android export/sunshines-bakery.apk
```

Turn **Use Gradle Build** on later only if you add the AdMob plugin.

### AdMob on device

Mock mode needs nothing else. For `SUNSHINE_AD_MODE=test` on a phone:

1. Install the MIT [Poing Studios AdMob plugin](https://github.com/poingstudios/godot-admob-plugin) into `addons/` (optional; not vendored).
2. After Gradle template install, add the test application id to the Android manifest:

```xml
<meta-data
  android:name="com.google.android.gms.ads.APPLICATION_ID"
  android:value="ca-app-pub-3940256099942544~3347511713"/>
```

Live unit ids belong in env / CI, not git. Google Mobile Ads is an **optional proprietary SDK**; the app remains FOSS and fully playable in mock mode.

Godot has no built-in WebView widget. ORDER uses HTTP for the catalog; Square’s hosted checkout URL is opened with `OS.shell_open` (Android Custom Tabs / browser). The **Web** button loads the live `/order` page the same way.

## FOSS licenses

| Piece | License |
| --- | --- |
| This repository | MIT (`LICENSE`) |
| [Godot Engine](https://godotengine.org/license) | MIT |
| Procedural textures (`tools/gen_assets.py`) | MIT (generated in-repo) |
| [Nunito](https://fonts.google.com/specimen/Nunito) (`assets/fonts/`) | SIL Open Font License 1.1 |
| Official circular logo | Sunshine’s Bakery brand mark (see `assets/branding/SOURCE.txt`) |
| Square catalog / checkout | Runtime calls to the bakery’s existing service; Square’s terms apply to payments |
| Google Mobile Ads / AdMob | Optional, proprietary; default path is mock ads with zero Google binaries |

No paid engine. Do not add Unity / Unreal paid SKUs.

## Branding and photos

The 3D mascot **must** match `assets/branding/sunshine-logo-girl.jpg`: chibi girl, round glasses, shiny black eyes, beauty mark, dark brown wavy hair + bangs, yellow-orange hat with black band and sunflower, pink top, red collar, grey apron, cream sunburst, orange **SUNSHINE’S BAKERY** bar, thick black circle.

Storefront photographs: `assets/branding/sunshine-bakery-exterior-2231.jpg` is the 2231 lot (white siding, pink trim, picnic tables). `assets/branding/sunshine-bakery-backyard-good.jpg` is the primary rear yard (dark tables, fence, trees, lattice deck). Explore 3D rebuilds both in low-poly; the circular mark on the wall is `sunshine-logo-girl.jpg`. See `docs/ASSETS.md`.

## Smoke check without the editor

```bash
python3 tools/check_project.py
godot --path .
godot --headless --path . res://scenes/dev/feature_smoke.tscn
godot --headless --path . -s res://tools/launch_smoke.gd
godot --headless --path . -s res://tools/scene_smoke.gd
```

`feature_smoke` instantiates the menu, ORDER (live Square catalog only), EXPLORE 3D (outdoor eating patio + 3 cube pastries + review cameras), and a mock staff-tip ad. `launch_smoke` presses **ORDER / TIP VIA AD / EXPLORE 3D** for real scene changes.
