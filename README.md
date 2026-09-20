# Sunshine’s Bakery (FOSS Android)

Godot **4.3+** (MIT) app for [Sunshine’s Bakery](http://sunshinebakeshop.com/),
2231 1st Ave S, Irondale AL 35210.

Sideload an APK first. Play Store comes later. No secrets in this repo.

**v0.1.59-debug APK (sideload):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.59-debug/sunshines-bakery-0.1.59-debug.apk

**Previous sideload (v0.1.58-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.58-debug/sunshines-bakery-0.1.58-debug.apk

No Play upload.

**v0.1.49 Play AAB (Closed testing, target API 36 — no new Play upload for 0.1.50):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.49-play/sunshines-bakery-0.1.49.aab

On first launch the app asks for a **US phone** (no SMS code). **Continue** POSTs bakery-drinks (`/order/api/account/login`, then `/account/phone` / `/customer`). Found → sign in. Missing → CreateCustomer, with opt-in **Join Sunshine’s Bakery loyalty / save your orders**. If the Square customer has **no usable name**, a short form asks for **first name, last name, and email**, then **POST/PATCH `/order/api/account/profile`** (Square `UpdateCustomer`) — it is not stored only on the phone. If drinks returns a `session_token`, the app stores it and uses `Authorization: Bearer` for later account/orders/status/profile — it does **not** `GET ?phone=` (that dumps email/orders). **Skip for now** keeps guest browsing unblocked. Session (`customer_id` + phone + token) is stored in `user://`. **Log out** returns to the phone screen. Secrets stay on Cloud Run — see `server/HOW_TO_TEST.md`.

The **main menu** is the **real 2231 lawn storefront photo** (`storefront-hero.jpg`, 9:16 portrait of the pink-trim shop with the circular girl logo). ChatGPT voxel stills are Explore reference only — they are not the menu backdrop. After login it says **Hi, {First}** from Square. There is **no Settings** button. **PREVIOUS ORDERS** is a lawn button (with ORDER / TIP VIA AD / EXPLORE 3D): signed-in customers see Square tickets (name, date, order total, each line’s qty + Square line total when sent, modifiers with option names/prices, Square item photo when the catalog has one, Order again); guests get a short sign-in prompt.

Four main-menu options:

1. **ORDER** — Irondale kiosk whose **offers come from Square only**: live bakery-drinks `GET /order/api/menu` is the **primary catalog** (drinks, prices, modifiers). A successful drinks response paints the menu immediately; the public Square Online store catalog for food fills in afterward and **must not block or fail ORDER**. Same `price_cents` / sticky cart total. **Type is large throughout the app** (main menu, Order, cart, checkout, Status, Previous Orders, Tip, Explore HUD including Toss cookie, toasts) so older customers can read it. Order/menu browse (and the item picker) show Square photos at **~75% of the card width**; Previous Orders, cart/checkout, and Status keep the older **96px square thumbs** beside the line copy. Dragging on a menu card **scrolls the list**; a short tap still opens the item. Tapping **ORDER** on the lawn opens the kiosk immediately — there is **no full-screen Loading menu overlay**. If Square is still fetching, Order shows a light inline skeleton (not a cover). Each item photo shows a blush/wine **Loading photo** placeholder until the Square image arrives, then swaps in; a failed fetch keeps `no_photo.png`. Inside Order, a failed catalog fetch shows an error and **Retry Square**. The sticky cart bar shows **item count only** (for example `3 items`) — names, extras, and dollars stay on the Cart tab. **Clear cart** on the sticky bar (and Cart tab) empties every line without touching Order again. The last successful Square menu is **cached on the phone** and **prefetched** from the lawn / login so ORDER opens on that last-known catalog immediately, then refreshes quietly (stale-while-revalidate). **Photos fill in asynchronously** from a disk+memory cache and never block the list. Quiet Square refreshes do not rebuild the kiosk if the catalog did not change. We do not invent a menu if Square is down. **Every catalog item keeps every Square modifier list** — optional groups included (Reheat on pastries, Designs + Color on the tote, all drink extras). Menu rows preview those groups; tapping an item shows every option chip. **Cart, Status, and Previous orders all list each line’s chosen extras** (names, plus Square prices when Square sent them); the sticky cart bar stays a count only. **Order again** maps those extras back onto the live catalog and opens Cart with them pre-selected. Every row uses a Square image URL when Square has one. If Square sent no amount the row shows **—** — we do not invent prices or modifiers. If Square/network is down and there is no last-good cache the menu is **empty** with Retry. Square checkout opens in the system browser. **Status** shows only that signed-in customer’s **paid making** Square orders, labeled **app order xxx**, plus how many other **paid making** tickets are **ahead** in the Irondale kitchen queue. Completed/ready/canceled/draft/unpaid checkouts stay off Status (Previous Orders is paid history). Guests see “Log in with phone to see your order status.” There is no Staff tab.
2. **PREVIOUS ORDERS** — signed-in **GET** bakery-drinks `/order/api/orders` with `Authorization: Bearer` (SearchOrders by that Square `customer_id`). **Only paid Square tickets are listed** (canceled / draft / unpaid OPEN checkouts are hidden). Each line includes Square modifiers (`name`, `quantity`, `price_cents` / `base_price_cents`, `catalog_object_id`) and the **same Square item photo** Order uses (match by catalog id then name). If Square has no photo, a neutral placeholder is shown — we do not invent images. Optional **GET** `/order/api/orders/{order_id}` fills a ticket if the list is still thin. There is **no second Cloud Run**. Guests are asked to sign in with phone. **Order again** waits for the live Square catalog, matches lines by catalog id then name, and adds every line with those extras.
3. **TIP VIA AD** — Android **AdMob rewarded** (Poing plugin, Godot 4.3). Credits a **FREE TIP to the STAFF jar** (not a customer perk). Release/Play default is **live** production `tip_reward` (`ca-app-pub-2788636443838183/7894363467`, app id `ca-app-pub-2788636443838183~1520526800`). Debug sideloads and `SUNSHINE_AD_MODE=test` load Google’s official sample rewarded unit so Send a tip still works before Play is linked in AdMob. If a rewarded ad still does not fill, a short thank-you confirm still credits the staff tip. Editor/desktop uses the same confirm overlay. Do not tap your own production ads while testing.
4. **EXPLORE 3D** — Ronald’s Y-up outdoor eating patio (`assets/models/sunshine_outdoor_eating.glb`: picnic/bistro tables, chairs, flower planters, cornhole, Sunshine logo wall, 90×80 m grass). Chibi guests and staff stand on the grass/patio holding Square pastries and drinks. **Toss cookie** (bottom-center thumb button, or Space) throws a chocolate-chip cookie copy that knocks guests back; they stay on the grass and keep wandering. Look stays an invisible drag pad (no red square). The Sunshine bakery logo travels the sky as the sun. Ronald’s **10 top-seller** Square-photo menu `.glb` props sit large on the outdoor tables. The **main menu stays the real storefront photo**. Silent on-screen left stick + look drag pad (no LOOK/MOVE coaching). Collect **3 pastry props** for stamps. Morning **Fresh Batch** hunt stays stubbed (9–11 America/Chicago logic is still in `GameSave`). The HUD banner and stamp line tell you when it is live — entering Explore does **not** fire a Fresh Batch toast. Stamp card + local weekly finder leaderboard.

**CUSTOMIZE LOOK** (signed-in) picks a rounded bakery chibi and username. Signed-in looks load/save on bakery-drinks `GET/PUT /order/api/account/avatar` (live) with `user://profile_vault.json` as the offline cache. Guests can still EXPLORE with the default look. **Order again** replaces the cart with available lines from that ticket; it does not append onto leftover items.

This is a **cute third-person patio** (rounded people, real 2231 lawn menu photo) with CC0 textures (see `assets/foss/NOTICE.md`), not a photoreal remake. 0.1.59 prunes idle HTTPS ghosts before the 16-cap, POSTs leave, and shares cookie crumb bursts. Patio origin stays `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`. See `docs/ROOM_SERVER.md`.

## Open in Godot

1. Install [Godot 4.3 or 4.4+](https://godotengine.org/download) (standard or .NET — GDScript only here).
2. Import this folder (`project.godot`).
3. Press **F5**, or from a terminal: `godot --path .`
   You should land on the phone login (or the storefront-photo main menu if you skipped / already signed in). ORDER is the wine primary; PREVIOUS ORDERS / TIP VIA AD / EXPLORE 3D are secondary. Blush `#e8b4b8` + wine brown.

Desktop debug window is **480×800** so the left stick and look pad stay on a 1280×800 laptop. The logical viewport stays **720×1280**. For a larger phone frame: `godot --path . --resolution 720x1280`.

Explore 3D is built for a phone thumb zone (no on-screen coaching):

- **Move** — large **fixed** left stick, bottom-left (stationary circle, not a floating pad). Slight push walks, mid jog, outer sprint, with a short ramp. Pushing the stick to the top locks a gentle sprint until you pull back. Click or drag (mouse **or** touch).
- **Look** — invisible **right-half** drag. Finger motion is 1:1 while down; a short ease when it lifts. Looking while walking does not yank the walk direction.
- **Camera** — over-right-shoulder third-person, baker lower-left so the patio ahead stays readable.
- **Menu** — small **Menu** button (and **Esc**) returns home, without a tutorial line.

Details live in `scripts/explore/virtual_joystick.gd` and `look_pad.gd`.

### Explore 3D layout

The player spawns on the south lawn **facing the Sunshine logo wall** (yaw 0, looking −Z): picnic and bistro seating, string lights, planters, and the logo. **WASD** or the MOVE stick walk −Z across the grass toward the patio.

| Zone | What you see |
| --- | --- |
| **South lawn** | Enlarged 90×80 m grass field; spawn, cube pastries, strolling guests. |
| **Patio** | Picnic tables, bistro tables and chairs, flower planters, cornhole, menu-photo standees, seated guests. |
| **Logo wall** | `Logo_Hero` / `LogoWall` at the north edge of the seating. |
| **Borders** | Low rails on north / east / west of the patio island. |

Three cube pastries spawn on the south lawn (Fresh Batch can add extras). Tables show real Sunshine food/drink photos (and `.glb` menu props when those files land). **Esc** or **Menu** returns to the main menu.

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
| `SUNSHINE_EXPLORE_URL` | `https://sunshine-explore-k6uuoen7wa-ue.a.run.app` | persistent patio Cloud Run origin |
| `SUNSHINE_AD_MODE` | `live` | `mock` (in-engine overlay), `test` (Google sample rewarded unit on Android), `live` (production `tip_reward`) |
| `SUNSHINE_ADMOB_APP_ID` | `ca-app-pub-2788636443838183~1520526800` | AdMob application id baked into the Android manifest |
| `SUNSHINE_ADMOB_REWARDED_UNIT` | `ca-app-pub-2788636443838183/7894363467` | Production rewarded unit `tip_reward`. `ad_mode=test` swaps in Google sample `/5224354917` at runtime |
| `SUNSHINE_STAFF_PIN` | empty | Optional shop-tab PIN (set on the device, not in git) |
| `SUNSHINE_FRESH_BATCH` | `auto` | `auto` (9–11 America/Chicago), `force` (preview hunt), `off` |

Live APIs used (same as [bakery-drinks `/order`](https://bakery-drinks-k6uuoen7wa-ue.a.run.app/order)):

- `GET /order/api/menu` — Square catalog
- `POST /order/api/checkout` — hosted Square pay URL
- `GET /order/api/status?oid=` — customer status
- `GET /board` + `GET /board/tickets` — shop drink board

Order URL overrides stay in env / `user://config.cfg` (no in-app Settings screen).

## Android export (sideload APK)

Gradle is **on** (AdMob). Install the Android build template once
(**Project → Install Android Build Template**).

Package id: `shop.sunshines.bakery`. Output: `export/sunshines-bakery.apk` (gitignored). Launcher icon: `assets/branding/icon-192.png`.

1. Install [Godot 4.3/4.4 export templates](https://godotengine.org/download) matching your editor (**Editor → Manage Export Templates**).
2. JDK **17** + Android SDK (`adb` in `platform-tools`). **Editor Settings → Export → Android**: SDK path, Java path, debug keystore.
3. If the keystore is missing: `bash tools/make_debug_keystore.sh` (standard `~/.android/debug.keystore`, alias/password `android`).
4. **Project → Export → Android → Export Project** → `export/sunshines-bakery.apk`
5. Sideload: `adb install -r export/sunshines-bakery.apk`  
   (or copy the APK to the phone).

More detail: `export/README.md`. Play Store AAB + upload-key handoff: `docs/PLAY_STORE.md`. Release keystore passwords stay on the build machine / password manager, **never in this repo**.

CLI once the editor has SDK + templates:

```bash
godot --headless --path . --export-debug Android export/sunshines-bakery.apk
```

Turn **Use Gradle Build** stays **on** so the vendored AdMob plugin is packaged.

### AdMob on device

`SUNSHINE_AD_MODE` defaults to **`live`**. Android builds load a real rewarded ad through the vendored [Poing Studios AdMob plugin](https://github.com/poingstudios/godot-admob-plugin) **v4.3.1** (Godot 4.3). Editor/desktop still uses the mock overlay.

Production ids (Ronald AdMob console, wired in `[sunshine]`):

1. `sunshine/admob_app_id` — `ca-app-pub-2788636443838183~1520526800` (Android manifest `APPLICATION_ID`)
2. `sunshine/admob_rewarded_unit` — `ca-app-pub-2788636443838183/7894363467` (`tip_reward`)
3. `ad_mode=live` (or `SUNSHINE_AD_MODE=live`)

`SUNSHINE_AD_MODE=test` keeps Google’s official sample rewarded unit `ca-app-pub-3940256099942544/5224354917` for safe device clicks. The Play package is **not** linked in AdMob yet — CoS handles console linking separately; ads can still serve.

Google Mobile Ads is proprietary; the rest of the app stays MIT. The editor remains fully playable with the mock overlay.

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
| Google Mobile Ads / AdMob | Proprietary SDK pulled by Gradle; Poing Godot plugin is MIT (`addons/admob`) |

No paid engine. Do not add Unity / Unreal paid SKUs.

## Branding and photos

The 3D mascot **must** match `assets/branding/sunshine-logo-girl.jpg`: chibi girl, round glasses, shiny black eyes, beauty mark, dark brown wavy hair + bangs, yellow-orange hat with black band and sunflower, pink top, red collar, grey apron, cream sunburst, orange **SUNSHINE’S BAKERY** bar, thick black circle.

Storefront photographs: `assets/branding/storefront-hero.jpg` is the **main-menu / login** 9:16 lawn photo of 2231 (white siding, pink trim, circular logo, picnic table). `assets/branding/sunshine-bakery-exterior-2231.jpg` is an extra branding still of the 2231 lot. `assets/branding/sunshine-bakery-backyard-good.jpg` is the primary rear yard (dark tables, fence, trees, lattice deck). Explore 3D rebuilds both in low-poly; the circular mark on the wall is `sunshine-logo-girl.jpg`. See `docs/ASSETS.md`.

0.1.59 prunes idle HTTPS ghosts before the 16-cap, POSTs leave when you exit Explore, and shares cookie crumb bursts. Patio origin stays `https://sunshine-explore-k6uuoen7wa-ue.a.run.app` (cap 16, min 0 / max 1). See `docs/ROOM_SERVER.md` and `docs/TWO_PHONE_PATIO.md`.

## Smoke check without the editor

```bash
python3 tools/check_project.py
godot --path .
godot --headless --path . res://scenes/dev/feature_smoke.tscn
godot --headless --path . -s res://tools/launch_smoke.gd
godot --headless --path . -s res://tools/scene_smoke.gd
```

`feature_smoke` instantiates the menu, ORDER (live Square catalog only), EXPLORE 3D (outdoor eating patio + 3 cube pastries + review cameras), and a mock staff-tip ad. `launch_smoke` presses **ORDER / TIP VIA AD / EXPLORE 3D** for real scene changes.
