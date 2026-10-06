# Test world (0.1.93 / 95)

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

`explore_3d.tscn` with the flag off is the store patio: 220×220 grass, photo borders at ±109.6, daytime logo sun, no Halloween nodes, no pumpkin bin, no patio ghosts, no pets, no graveyard, no giant pumpkin, no ping label.

The test scene is the same Explore rig plus `test_world_boot.gd`. Gameplay (walk, loyalty, orders, cookie toss) stays. Cookie toss still spends cookies. A held pumpkin throws on the same button and does not spend a cookie.

Ping is a client timer around the existing `GET /explore/health` on the current Explore origin. It does not add a server, change `explore_base_url`, or deploy anything.

## Map Modeler handoff

Locked and untouched: `sunshine_outdoor_eating_b1.glb` materials and logo, `photo_borders` on the 220×220 rim at ±109.6, A1 head.

Test World loads `res://assets/explore/sunshine_outdoor_eating_expand.glb` when that file is present. It is already the 1.5× island (**22.8 × 0.14 × 19.35**), so the runtime scale below does not run on top of it. If the expand file is missing, Test World falls back to scaling the locked patio in place.

Runtime scale (fallback only), about the Patio_Island center, **1.5× in X and Z only** (height unchanged):

- `Patio_Island`
- `Picnic_*`, `Bistro_*`, `Menu_Board`, `Trash_Can`, `Cornhole_*`, `Beanbag*`, `FlowerPlanter*`, `LightPost*`
- Patio hedges `NorthBorder`, `WestBorder`, `EastBorder`

Not scaled: `Grass_Base`, `LogoWall` / `Logo_Hero`, photo borders.

Anything whose center lands inside a **3.6 m** radius of the island center is pushed out so the middle stays a toss gather (about 7 m across). Practice targets stay at **z 34–37**. Player spawn stays on the south lawn (x ≈ 0, z ≈ 11), looking −Z at the logo wall.

Halloween pockets use the Map Modeler GLBs under `res://assets/explore/halloween/` when those files are present (`HW_NorthLawn.glb`, `HW_WestCorner.glb`, `HW_DiscoFringe.glb`). The combined `halloween_pockets.glb` is kept beside them and is not instanced. Procedural pockets remain the fallback. Colors stay blush `#e8b4b8` / wine `#722F37` / cream `#FFF8F0`.

| Node | What |
| --- | --- |
| `HW_NorthLawn` | Hay, pumpkins, lanterns around z −28…−36, off the market stalls |
| `HW_WestCorner` | Crate, candy bowl, standing pumpkin on the west deck, south of center so the logo wall stays clear |
| `HW_DiscoFringe` | Two jack-o'-lanterns beside the disco. No cobweb, fog, or extra party lights |

Pumpkin:

| Node / file | Spec |
| --- | --- |
| `PumpkinBin` | `res://assets/explore/PumpkinBin.glb` at **(8, 0, 31)**, next to cookie practice. Open blush rim, dark recess, cream emblem. A procedural basket is the fallback |
| `prop_pumpkin_toss.glb` | `res://assets/explore/prop_pumpkin_toss.glb`. **0.35–0.45 m**, origin at the bottom, parented to `HandSocket` like the cookie. A procedural stand-in is used if that GLB is missing |
| Throw | Same windup as the cookie, slightly softer arc, squash on land, knockback on bakers and NPCs |

Patio ghosts and the giant pumpkin are test-world only. Neither is parented in production `explore_3d`.

| Node | Spec |
| --- | --- |
| `PatioGhosts` | Four sheet ghosts with oval eyes, a smile or a small "o", wavy hems, and little arms. They bob and sway. No colliders |
| `PatioPets` | A cat and a dog on the patio. Walk up and tap **Pick up** to carry one. **Put down** sets it in front of you. They are not throwable; Toss stays hidden while you hold one |
| `Graveyard` | A fenced yard at **(-84, 0, -58)**, far from spawn, the patio, and the giant pumpkin. Tombstones, a gate, dead trees, and a little fog. The Headless Horseman gallops inside and throws cookies only while a player is in the yard |
| `GiantPumpkin` | A carved jack-o'-lantern about **30 m** tall at **(72, 0, 78)**, with deep ribs, a gnarled stem, and a glowing face. A railed spiral stays outside the ribs and ends on a railed deck beside the crown |
| `LogoMoon` | Night sky only. The bakery logo disc hangs in the sky and casts one soft shadowless moonlight. A small fill light keeps faces readable. Patio albedo is tinted so the unshaded lot reads as night |

Measured on this branch (Patio_Island AABB, meters):

| | X | Y | Z |
| --- | --- | --- | --- |
| Before | 15.2 | 0.14 | 12.9 |
| After (1.5× XZ) | 22.8 | 0.14 | 19.35 |

Center stays at the origin. Author the next patio GLB at the **after** footprint (about 22.8 × 19.4 m). Do not reopen the locked B1 file in place; import a new GLB beside it.

Practice posts are `PracticeTargetWest` (z 34), `PracticeTargetEast` (z 34), and `PracticeTargetNorth` (z 37.2).

## Build betas from this branch only

Same package name. Test presets use **versionName 0.1.93** and **versionCode 95**. Store presets in this repo file are still **0.1.88 / 90** so a mistaken Production upload is not a new version.

iOS Tip uses live AdMob ids. Android ids are unchanged.

| | Value |
| --- | --- |
| iOS app id (`GADApplicationIdentifier`) | `ca-app-pub-2788636443838183~5610388009` |
| iOS rewarded Tip unit | `ca-app-pub-2788636443838183/5379462878` |
| Android app id | `ca-app-pub-2788636443838183~1520526800` |
| Android rewarded unit | `ca-app-pub-2788636443838183/7894363467` |

Mac TestFlight export (no archive from this Linux agent):

```bash
export SUNSHINE_AD_MODE=live
export SUNSHINE_ADMOB_IOS_APP_ID=ca-app-pub-2788636443838183~5610388009
export SUNSHINE_ADMOB_IOS_REWARDED_UNIT=ca-app-pub-2788636443838183/5379462878
godot --headless --path . --export-release "iOS Test World" export/test/ios/SunshineBakery.ipa
```

Then archive that Xcode project as in `export/README.md`. Do not submit it for App Review.

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
