# Test world (0.1.89 / 91)

Same app id: `shop.sunshines.bakery`. This is not a second store listing.

Store builds of **0.1.88 (90)** stay the production Explore layout. The bigger patio, Halloween pockets, pumpkin toss, and on-screen ping ship only in the **test world** flavor on branch `cursor/test-explore-halloween-3c24`.

Do not merge this branch to `main`. Do not upload anything from it to Play Production or App Store production. Do not change production server config or deploy the patio server.

## What turns the test world on

`AppConfig.test_world` is false unless one of these is set:

| Switch | Effect |
| --- | --- |
| Export feature `test_world` | Set on the three **Test World** export presets |
| `SUNSHINE_TEST_WORLD=1` | Editor / desktop runs |
| `res://scenes/explore/explore_test.tscn` | Sets the flag before the patio builds |

`explore_3d.tscn` with the flag off is the store patio: 220×220 grass, photo borders at ±109.6, no Halloween nodes, no pumpkin bin, no ping label.

The test scene is the same Explore rig plus `test_world_boot.gd`. Gameplay (walk, loyalty, orders, cookie toss) stays. Cookie toss still spends cookies. A held pumpkin throws on the same button and does not spend a cookie.

Ping is a client timer around the existing `GET /explore/health` on the current Explore origin. It does not add a server, change `explore_base_url`, or deploy anything.

## Map Modeler handoff

Locked and untouched: `sunshine_outdoor_eating_b1.glb` materials and logo, `photo_borders` on the 220×220 rim at ±109.6, A1 head.

Runtime scale (test world only), about the Patio_Island center, **1.5× in X and Z only** (height unchanged):

- `Patio_Island`
- `Picnic_*`, `Bistro_*`, `Menu_Board`, `Trash_Can`, `Cornhole_*`, `Beanbag*`, `FlowerPlanter*`, `LightPost*`
- Patio hedges `NorthBorder`, `WestBorder`, `EastBorder`

Not scaled: `Grass_Base`, `LogoWall` / `Logo_Hero`, photo borders.

Anything whose center lands inside a **3.6 m** radius of the island center is pushed out so the middle stays a toss gather (about 7 m across). Practice targets stay at **z 34–37**. Player spawn stays on the south lawn (x ≈ 0, z ≈ 11), looking −Z at the logo wall.

Halloween pockets (modest meshes, blush `#e8b4b8` / wine `#722F37` / cream `#FFF8F0`):

| Node | What |
| --- | --- |
| `HW_NorthLawn` | Hay, pumpkins, lanterns around z −28…−36, off the market stalls |
| `HW_WestCorner` | Crate, candy bowl, standing pumpkin on the west deck, south of center so the logo wall stays clear |
| `HW_DiscoFringe` | Two jack-o'-lanterns beside the disco. No cobweb, fog, or extra party lights |

Pumpkin:

| Node / file | Spec |
| --- | --- |
| `PumpkinBin` | Basket at **(8, 0, 31)**, next to cookie practice |
| `prop_pumpkin_toss.glb` | Optional art at `res://assets/explore/prop_pumpkin_toss.glb`. **0.35–0.45 m**, origin at the bottom, parented to `HandSocket` like the cookie. A procedural stand-in is used until that GLB is imported |
| Throw | Same windup as the cookie, slightly softer arc, squash on land, knockback on bakers and NPCs |

Measured on this branch (Patio_Island AABB, meters):

| | X | Y | Z |
| --- | --- | --- | --- |
| Before | 15.2 | 0.14 | 12.9 |
| After (1.5× XZ) | 22.8 | 0.14 | 19.35 |

Center stays at the origin. Author the next patio GLB at the **after** footprint (about 22.8 × 19.4 m). Do not reopen the locked B1 file in place; import a new GLB beside it.

Practice posts are `PracticeTargetWest` (z 34), `PracticeTargetEast` (z 34), and `PracticeTargetNorth` (z 37.2).

## Build betas from this branch only

Same package name. Test presets use **versionName 0.1.89** and **versionCode 91**. Store presets in this repo file are still **0.1.88 / 90** so a mistaken Production upload is not a new version.

| Preset | Output | Track |
| --- | --- | --- |
| Android Test World | `export/test/sunshines-bakery-test.apk` | Sideload / internal check |
| Android Play Test World | `export/test/sunshines-bakery-test.aab` | Play Console **Closed testing → Alpha** only |
| iOS Test World | `export/test/ios/SunshineBakery.ipa` (Xcode project; `export_project_only`) | **TestFlight** internal/alpha only |

Godot **4.7.2** export templates, same signing docs as `docs/PLAY_STORE.md` and `export/README.md`.

1. Check out `cursor/test-explore-halloween-3c24`. Do not build these presets from `main`.
2. Godot → Project → Export → **Android Play Test World** or **iOS Test World**.
3. Play Console: open the existing app `shop.sunshines.bakery` → Testing → Closed testing → Alpha → create a release with the AAB. Do not promote to Production. Do not edit the production store listing.
4. App Store Connect: upload the TestFlight build for the same bundle id. Do not submit for App Review / production release.
5. Desktop check without a phone: `SUNSHINE_TEST_WORLD=1 godot --path .` or open `scenes/explore/explore_test.tscn`.

Headless check (no store upload):

```
godot --path . --headless -s res://tools/test_world_smoke.gd
```
