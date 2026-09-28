# M0 baseline — inspected 2026-09-20

Recorded from `cursor/menu-photo-admob-a99b` (0.1.50) before COS edits. Do not treat older verbal descriptions as current.

## App / engine

| Item | Verified |
| --- | --- |
| Engine | Godot 4.3 (`config/features=4.3, Mobile`) |
| Renderer | `mobile`, MSAA 3D on, ETC2/ASTC |
| Package | `shop.sunshines.bakery` |
| Version at baseline | 0.1.50 / versionCode 51 |
| Main scene | `scenes/account/login.tscn` |
| Platforms | Android sideload APK (arm64). Play AAB last uploaded as 0.1.49. Desktop editor 720×1280 logical. No web export in presets. |
| Min SDK / target | 24 / 36 |
| Signing | Debug keystore local; release keystore not in repo |

## What already works

- Phone Continue → bakery-drinks `POST /order/api/account/login` (no SMS OTP). Session Bearer. Skip guest. Nameless Square customers get first/last/email → profile update.
- ORDER kiosk from live `GET /order/api/menu` (drinks primary). Square Online store enriches food in the background. Cached last-good catalog. Photos async. Checkout via hosted Square URL.
- PREVIOUS ORDERS: Bearer `GET /order/api/orders`, paid tickets only. **Order again (baseline) appended lines** — this was the §10 defect.
- TIP VIA AD: Poing AdMob 4.3.1. Debug sideload uses Google sample rewarded unit + confirm fallback. Centered blush/wine sheet. No AdMob/tech copy. First sentence only. No tip counts.
- EXPLORE 3D: `sunshine_outdoor_eating.glb` 90×80 m patio, joystick + look pad, cube/chibi NPCs, toss cookie from **camera** (not a hand), stamp card, Fresh Batch stub.
- Navigation: lawn menu ORDER / PREVIOUS ORDERS / TIP / EXPLORE. Large Nunito type. No Settings.

## What does not exist yet (not a regression)

- Dedicated multiplayer / rooms / join tickets
- Persistent customizable player (baseline player is an invisible capsule + first-person-ish camera)
- Server chat / moderation
- 4× map
- Purchase-linking entitlements / public displays
- Rigged throw animation with animation events

## Online services

- bakery-drinks Cloud Run: menu, checkout, status, account, orders, board
- Square Online public catalog (site `30aacb50-1317-11ef-ad4f-279b7b292d3d`, store location `L4CK6YWGT5XQX`)
- AdMob production `tip_reward` (Play package not linked yet)
- Official website: `https://www.sunshinebakeshop.com/` (from `AppConfig.square_online_origin()`, not guessed)

## Live menu sample (2026-09-20)

`GET /order/api/menu` returned **8 drinks**, `source=square`, `pay_mode=square`, location Irondale:

Biscoff Coffee, Coffee, Vietnamese Coffee, Water, Fruit Tea, Lemonade, Matcha Latte, Milk Tea.

Item keys: `id` (variation), `item_id`, `catalog_object_id`, names, `price_cents`, `photo`, `groups`, `defaults`, `category`. **No inventory / ATS / tracking fields.** Sold-out flags were absent on this sample.

Food/pastry rows still arrive from Square Online enrichment + last-good cache on device.

## Explore map (baseline measure)

`bakery_world.gd` colliders: Grass_Base authored **90 × 80 m**. Patio island + logo wall + furniture hulls. This is the measured playable footprint for the 4× target (about 180 × 160 m later, not 360 × 320).

World style: low-poly / voxel-adjacent patio GLB + rounded chibi NPCs. Menu backdrop is the real 2231 lawn photo.

## Assets

- Brand: `sunshine-logo-girl.jpg`, `storefront-hero.jpg`
- Patio GLB ~1MB+; 10 top-seller menu prop GLBs
- CC0 foss textures; Nunito OFL
- Cookie toss uses `menu_props.instantiate_cookie()`

## Performance

Not measured on a physical phone in this environment. Editor/headless only. Do not invent device FPS.

## Existing defects (baseline)

1. Order again **merged/appended** into the current cart.
2. Shopping showed sold-out rows (muted) instead of hiding them.
3. No inventory ATS — drinks omits counts.
4. Cookie spawned from camera, not a hand.
5. Player body not visible.
6. Guest and customer share only a local `player_name` string; no stable player_id.
