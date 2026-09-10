# Sunshine’s Bakery (FOSS Android)

Godot **4.3+** (MIT) app for [Sunshine’s Bakery](http://sunshinebakeshop.com/),
2231 1st Ave S, Irondale AL 35210.

Sideload an APK first. Play Store comes later. No secrets in this repo.

Three main-menu options:

1. **ORDER** — live Square-backed drink catalog from the bakery-drinks service (HTTP). No hardcoded menu. Square checkout opens in the system browser / WebView host. In-app customer notice when an order is ready; staff/shop tab for ready/complete.
2. **TIP VIA AD** — rewarded ad that credits a **FREE TIP to the STAFF jar** (not a customer perk). Default **mock** mode (no Google keys). Optional AdMob **test** unit.
3. **EXPLORE 3D** — walkable low-poly **indoor bakery + exterior + backyard**. Enter through the storefront door. Stub interior: counter, pastry case, small standing area (no interior photos yet). Circular girl logo on the facade. Collectible croissants & drinks spawn **indoors and outdoors**. Morning **Fresh Batch** hunt (9–11 America/Chicago). Stamp card + local weekly finder leaderboard.

This is a **runnable scaffold**, not a photoreal finished game.

## Open in Godot

1. Install [Godot 4.3 or 4.4+](https://godotengine.org/download) (standard or .NET — GDScript only here).
2. Import this folder (`project.godot`).
3. Press **F5**. You should land on the three-button menu with the circular girl logo.

Explore 3D is built for a phone thumb zone (and desktop playtests that are not WASD-only):

- **MOVE** — large on-screen stick, bottom-left. Click or drag (mouse **or** touch). The stick is centered: tapping the top walks forward immediately.
- **LOOK** — drag pad on the bottom-right, plus **◀ LOOK / LOOK ▶** (and ▲/▼) hold buttons. Same mouse-click and touch path.
- **Keyboard / mouse** — **WASD** walk, **right mouse** capture to look, **Esc** to release.

The HUD line repeats this. Details also live in `scripts/explore/virtual_joystick.gd` and `look_pad.gd`.

### Explore 3D layout

The player spawns on the front lawn **facing the storefront door**. Walk the pavers → front door → indoor aisle → **left yard door** → concrete strip → backyard.

| Zone | What you see |
| --- | --- |
| **Indoor (stub)** | Tile floor, blush runner, back counter, glass pastry case with trays, copper espresso, chalkboard, standing ledge, pendants. No interior photos yet — set `BakeryWorld.INTERIOR_PHOTO` when you have a ≤1-year shot. |
| **Exterior** | White clapboard, pink trim, awning, flower boxes, two windows, circular girl logo, orange **SUNSHINE’S BAKERY** bar, **2231**, picnic lawn (`sunshine-bakery-exterior-2231.jpg`). |
| **Backyard** | Grass, dark picnic tables, fence, trees, lattice deck (`sunshine-bakery-backyard-good.jpg`). Through the shop or around the left sidewalk. |

Croissants and drinks spawn on the front lawn, at the indoor case/counter/standing area, and at the backyard tables.

Eight fixed **review cameras** (Entrance, Counter, Dining, LeftCorner, RightCorner, SunshineCloseup, PastryCase, Exterior) live under `ReviewCameras`. Capture PNGs with:

```bash
godot --path . --headless -s res://tools/capture_review.gd
```

See `docs/REVIEW_CAMERAS.md`. Drop real `.glb` files into `assets/models/` (placeholders are in git; README there lists names and axes).

### Fresh Batch (morning hunt)

Shop-local **America/Chicago** (Irondale). Active **9:00–11:00** (until 11:00).

- Extra croissant and drink pickups spawn **indoors and outdoors** while the window is open.
- The **first 3 finds** that morning grant **2 stamps** on the free-drink stamp card (8 stamps = free drink). After that, finds are 1 stamp each.
- The local **weekly finder leaderboard** still counts **1 find** per pickup.
- The Explore HUD banner and status line tell you when it is live and how many 2× stamps remain.

Preview outside that window: `SUNSHINE_FRESH_BATCH=force` (or `off` to disable). Default is `auto`.

### Project layout

```
project.godot
scenes/main_menu.tscn          # ORDER / TIP VIA AD / EXPLORE 3D
scenes/order/order.tscn
scenes/tip_ad/tip_ad.tscn
scenes/explore/explore_3d.tscn
assets/branding/sunshine-logo-girl.jpg
assets/models/                 # optional GLB drop-ins (stubs in git)
scripts/autoload/              # config, HTTP client, notices, ads, save
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

In-app **Settings** on the main menu can override the order URL on-device.

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
godot --headless --path . res://scenes/dev/feature_smoke.tscn
godot --headless --path . -s res://tools/launch_smoke.gd
```

`feature_smoke` instantiates the menu, ORDER (live Square catalog), EXPLORE 3D (including review cameras), and a mock staff-tip ad. `launch_smoke` presses **ORDER / TIP VIA AD / EXPLORE 3D** for real scene changes.
