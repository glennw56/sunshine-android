# Test world (0.1.100 / 102)

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

Test World loads `res://assets/explore/sunshine_outdoor_eating_p2.glb` when that file is present. The remade patio is already the bigger island (**about 22 × 0.15 × 16**, x ±11, z −7 to 9), so the runtime scale below does not run on it, and the cute-pack furniture swap is skipped so the new tables, hedges, and planters stay. Leaf cards keep their alpha cutout, and textured surfaces keep baked vertex color. If p2 is missing, Test World uses the older expand GLB the same way, and only if both are missing does it scale the locked patio in place.

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
| `HW_DiscoFringe` | Two jack-o'-lanterns just east of the north picnic table, clear of the disco circle. No cobweb, fog, or extra party lights |

Pumpkin:

| Node / file | Spec |
| --- | --- |
| `PumpkinBin` | `res://assets/explore/PumpkinBin.glb` at **(8, 0, 31)**, next to cookie practice. Crate, hay, pumpkins, and a chalk **PUMPKINS** sign. The code collider stays. A procedural basket is the fallback |
| `prop_pumpkin_toss.glb` | `res://assets/explore/prop_pumpkin_toss.glb`. **0.41 m**, origin at the bottom, cute face toward −Z. A procedural stand-in is used if that GLB is missing |
| Throw | Same windup as the cookie, slightly softer arc, squash on land, knockback on bakers and NPCs |

Patio ghosts and the giant pumpkin are test-world only. Neither is parented in production `explore_3d`.

| Node | Spec |
| --- | --- |
| `PatioGhosts` | Four copies of `ghost_sheet.glb`. Even ghosts show FaceSmile, odd ones FaceOh. The sheet stays alpha blended at 0.86. Arms use the existing ±0.35 pose. The face is on local −Z and yaws to the travel tangent each frame. No colliders |
| `PatioPets` | `pet_cat.glb` and `pet_dog.glb`. Tails wag and the four legs swing. Near one, a large **Pick up** button appears (tap the pet or the button). Held pets sit upright on the head, facing forward, clear of the skull and hat. **Put down** sets the pet on the ground ahead. They are not throwable; Toss stays hidden while you hold one |
| `Graveyard` | A fenced yard at **(-84, 0, -58)**. Tombstones, fence, gate, dead trees, and the dirt disc are the batch-2 GLBs, night-flattened. Post and rail colliders stay, plus two short rails beside the gate. Fog stays procedural. `headless_horseman.glb` is not night-tinted. He gallops inside (legs ±0.6) and throws from the lantern. HorsemanHit is one box per mesh part, resynced each physics tick so the hooves, cloak, and lantern follow the gallop. Cookie toss hits those shapes. The old 2.15 m aim sphere is gone |
| `GiantPumpkin` | `giant_pumpkin.glb`, about **30 m** tall at **(72, 0, 78)**, turned to face the patio. JackLight sits in the carved face. `pumpkin_stairs.glb` is the stair and deck visual in the pumpkin's unrotated space. Every code RampStep, RampRail, DeckRail, and DeckDisc mesh is hidden, including the copies Godot renames. Their StaticBodies stay. Rib shelves still let you stand on the shell |
| `LogoMoon` | Night sky only. `logo_moon.glb` faces the camera, LogoDisc uses the existing glow shader, and MoonHalo plus MoonLight stay. The disc is not night-tinted. Patio albedo is tinted so the unshaded lot reads as night |
| Disco party | The bullseye is unchanged. A hit still asks the room for the shared 20s clock, and in this build it also starts that clock on this phone so a missed echo does not leave the patio dark. The blush floor sits above the deck (the old pad was inside the slab) and the light shafts reach the floor. Unshaded night materials ignore the omni lamps, so the floor, shafts, host, and wash are what you see |

Measured on this branch (Patio_Island AABB, meters):

| | X | Y | Z |
| --- | --- | --- | --- |
| Locked B1 (store) | 15.2 | 0.14 | 12.9 |
| Test World p2 | 22.0 | 0.15 | 16.0 |

Center stays near the origin (p2 center z ≈ 1). The locked menu-prop tables stay on their old slots. New seating (`Bistro_W2`, `Bistro_W3`, `Bistro_E2`, `Bistro_E3`, `Picnic_SW2`, `Picnic_SE2`, `Bench_W`, `Bench_E`, `Bench_Logo`) has walk hulls. Do not reopen the locked B1 file in place.

Practice posts are `PracticeTargetWest` (z 34), `PracticeTargetEast` (z 34), and `PracticeTargetNorth` (z 37.2). In the test world they use `practice_target.glb`, keep the post collider, and add a face box about **0.8×0.8×0.12** at y 1.1. Store posts stay procedural.

Test-world cookies (in hand and in flight, including the horseman's) are `cookie_projectile.glb` at scale 1, root name `Cookie`. Store cookies stay on the catalog mesh at the old scale. Croissant pickups in the test world are `collectible_pastry.glb` at scale 1 with the plate hidden. Drinks stay on the catalog prop.

## Build betas from this branch only

`PerimeterWall` sits inside the photo borders (inner face at ±102). Each side is 20 m of cobblestone with a closed gate in the middle: `GateNorth` (−Z), `GateEast`, `GateSouth`, `GateWest`. Doors, iron bands, a stone arch, and a torch on each pillar. `GateBlock` fills the opening from the ground to y 42, and the wall runs have the same invisible collar, so the giant-pumpkin deck cannot cross the rim. The player model is unchanged.

Same package name. Test presets use **versionName 0.1.100** and **versionCode 102**. Store presets in this repo file are still **0.1.88 / 90** so a mistaken Production upload is not a new version.

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
