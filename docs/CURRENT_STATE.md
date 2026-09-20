# CURRENT_STATE — Sunshine COS

## 0.1.74 — Order category tabs pinned; they do not move

Ronald on 0.1.73: wrap helped, but the category **tabs still moved**. The chip bar was still a `ScrollContainer`, and every tap rebuilt the HFlow so chips reflowed. `_reveal_selected_chip` called `ensure_control_visible`, which slid the row.

The tab bar is now a non-scroll `MarginContainer` sibling of the item list, with a fixed 2×3 `GridContainer` (All / Drinks / Pastries, Savory / Bread / Merch). Chips are created once and only restyled on select. List scroll does not move the tabs; selecting a chip does not slide other chips. True filter is unchanged. Explore / Donate untouched.

- **Commit/build:** 0.1.74 / Android versionCode 75
- **Branch:** `cursor/order-category-filter-4095`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.74-debug/sunshines-bakery-0.1.74-debug.apk

## Honest QA (0.1.74)

- 720×1280: tap Drinks, scroll the menu hard — tab bar global Y and every chip rect stay put.
- Six chips always occupy the same two rows; no horizontal chip scroll.
- Filter still shows only that category; scroll does not change the selected chip.

## 0.1.73 — Order category chip bar wraps and stays tappable

Ronald on 0.1.72: the item filter is right, but the category **tabs** are wrong. The chip row was a single clipped HBox: Merch was only a sliver, the ✓ prefix widened the selected pill, and `_render()` reset horizontal scroll so the selected chip could sit off-screen.

Chips now wrap (All / Drinks / Pastries, then Savory / Bread / Merch), keep a stable label, and stay fully on a 720px phone. Filter behavior is unchanged: only that category’s items, scroll does not change the chip. Explore / Donate untouched.

- **Commit/build:** 0.1.73 / Android versionCode 74
- **Branch:** `cursor/order-category-filter-4095`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.73-debug/sunshines-bakery-0.1.73-debug.apk

## Honest QA (0.1.73)

- Every chip (including Merch) is fully visible and tappable without horizontal hunting.
- Selected pill is wine-filled; others are cream. No ✓ width jump.
- Scroll the item list: chip row stays put and the same chip stays selected.

## 0.1.72 — Order category chips filter instead of scroll-spy

Ronald: tapping a category then scrolling the Order list made the chip change (other/out-of-category items still on screen). Root cause is jump-to-section chips on a combined menu — `_jump_to_section` scrolled to a header in the full list, so later rows were other categories. There was no `_selected_category` filter.

Chips now rebuild the list to **only** items in that Square bucket. All shows everything. Scroll does not change the chip. Square Online ids map Drink / Sweet / Savory / Bread / Merch; unknown names stay off every chip except All. Explore chat/centering and Donate are untouched.

- **Commit/build:** 0.1.72 / Android versionCode 73
- **Branch:** `cursor/order-category-filter-4095`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.72-debug/sunshines-bakery-0.1.72-debug.apk

v0.1.71-debug already shipped Explore chat-once on another branch, so this Order filter APK is **0.1.72**. It still includes the 0.1.70 chat cursor/dedupe and centered TPP camera.

## Honest QA (0.1.72)

- Tap Drinks, scroll hard: chip stays Drinks; every visible row is a drink.
- Tap Pastries: Coffee Tiramisu Cake appears; Vietnamese Coffee does not.
- All still shows the full shop. Uncategorized items are not on every chip.
- `player.gd` still has `SpringArm3D` and `SHOULDER := Vector3(0.0, 1.78, 0.12)`.
- Donate checkout remains `https://square.link/u/9tUzPJZQ`.

## 0.1.70 — Explore chat no longer re-reads the same events

Ronald on 0.1.69: patio chat showed the same line many times (looked like an infinite loop). Root cause is the HTTPS `/explore/tick` fallback: the phone re-ingests the room `events` backlog every tick. Throws already dedupe by `proj_id`; **chat did not**. If `_event_seq` stays 0 (or the client processes the full `events` array without a local cursor), the same `seq`/`msg_id` is appended forever (HUD caps at 40, so it looks like a flood).

Fix is client ingest only for the loop: advance `_event_seq` from each event `seq` plus the tick `event_seq`, skip `seq <= cursor`, and dedupe chat by `msg_id` then `seq`. `_http_busy` now stays set until the cursor is applied. Camera / `SHOULDER` / spring-arm are untouched. Donate, cookie MP, controls, and the patio URL stay.

Server (`explore_sim.py`) now stamps `msg_id` on chat. Live sunshine-explore already filters `events_since(event_seq)` — that is enough if the phone acks. CoS can redeploy `Dockerfile.explore` so live ticks include `msg_id`; not required to stop the loop. Still scale-to-zero / max-instances 1.

- **Commit/build:** 0.1.70 / Android versionCode 71
- **Branch:** `cursor/fix-explore-chat-loop-7d45`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.70-debug/sunshines-bakery-0.1.70-debug.apk

## Honest QA (0.1.70)

- Send several chats; each body appears once. Replaying the same tick payload must not grow the log.
- `player.gd` still has `SpringArm3D` and `SHOULDER := Vector3(0.0, 1.78, 0.12)`.
- Patio origin remains `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`.
- Donate checkout remains `https://square.link/u/9tUzPJZQ`.

## 0.1.69 — ship the real centered TPP player (tag must not be main)

The 0.1.68 **APK binary** already had TPP `player.gdc` (~9.5KB, `SHOULDER.x=0`). `gh release create` without `--target` tagged **main** (`ccf75e7`), so GitHub’s tag tree showed the old stub `player.gd` (~1.9KB, bare `$Camera3D`). New exports refuse a stub player; the 0.1.69 tag is created with `--target` on this branch.

- **Commit/build:** 0.1.69 / Android versionCode 70
- **Branch:** `cursor/center-explore-camera-a8b4`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.69-debug/sunshines-bakery-0.1.69-debug.apk

## Honest QA (0.1.69)

- Tag `v0.1.69-debug` must resolve to this branch commit, not `main`.
- `git show v0.1.69-debug:scripts/explore/player.gd` contains `SpringArm3D` and `SHOULDER := Vector3(0.0, 1.78, 0.12)`.
- Exported APK `player.gdc` is ≥6KB and contains `center_baker_v069`.
- Cookie MP, chat, Donate, controls, patio server unchanged.

## 0.1.68 — center the local baker in Explore

Ronald: the local player sits on the **left** of the phone. 0.1.63/0.1.67 kept `SHOULDER.x = 0.68` (over-right-shoulder / lower-left baker). This build only zeros that X offset so the model is horizontally centered. Cookie MP, chat, controls feel, patio server, and Donate are unchanged.

- **Commit/build:** 0.1.68 / Android versionCode 69
- **Branch:** `cursor/center-explore-camera-a8b4`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.68-debug/sunshines-bakery-0.1.68-debug.apk

## Honest QA (0.1.68)

- Camera `SHOULDER` is `(0.0, 1.78, 0.12)`; `TETHER_LEN` stays `4.15`; spawn stays `(0, 0.12, 11)`.
- `git diff origin/cursor/donate-square-link-23ee -- scripts/explore/cookie_projectile.gd scripts/autoload/explore_net.gd scripts/explore/explore_hud.gd scripts/donate` is empty except the Donate User-Agent version bump.
- Donate checkout remains `https://square.link/u/9tUzPJZQ`.

## 0.1.67 — Donate stays; Explore frozen at 0.1.63

Ronald: character was off-center after the Donate APKs. Explore / patio / camera / player / cookie MP is restored from commit `6b639ae` (the build that shipped **v0.1.63-debug**). The git tag `v0.1.63-debug` points at stale `main` — do not restore from that tag. Donate stays additive (lawn button above Tip, dollar progress, `https://square.link/u/9tUzPJZQ`). Donate is **not** in `WARM_SCENES`. No further Explore “improvements.”

- **Commit/build:** 0.1.67 / Android versionCode 68
- **Branch:** `cursor/donate-square-link-23ee`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.67-debug/sunshines-bakery-0.1.67-debug.apk

## Honest QA (0.1.67)

- `git diff 6b639ae -- scripts/explore scenes/explore scripts/autoload/explore_net.gd` is empty.
- Camera `SHOULDER` / `TETHER_LEN` / spawn `(0, 0.12, 11)` unchanged from cookie-MP.
- Donate still works; checkout URL unchanged.

## 0.1.66 — dollar progress bar (not donor count)

Ronald: the bar must show **dollars raised toward the goal**, not supporter count as the primary metric. Names still list under the bar. Copy is `Raised $X of $Y` plus the same dollars on the bar. Live Square goal today is $10,000; fallback stays **$500** if Square’s goal is not API-readable. Checkout remains `https://square.link/u/9tUzPJZQ`.

- **Commit/build:** 0.1.66 / Android versionCode 67
- **Branch:** `cursor/donate-square-link-23ee`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.66-debug/sunshines-bakery-0.1.66-debug.apk

## Honest QA (0.1.66)

- Progress metric is raised/goal dollars. Donor count is not on the bar line.
- Supporters list stays under the bar (names when bakery-drinks `/order/api/donations` is live).
- Donate URL is the existing Square link only.

## 0.1.65 — live donation progress + supporters

Ronald wants to **see donation data** (progress + customers), not a fake bar. The Donate screen loads bakery-drinks `GET /order/api/donations` then Square’s public checkout page. 0.1.66 made the bar dollars-only (raised/goal); names stay under it. Names need Glenn/CoS to apply `server/account.py` + `server/donations.py` onto bakery-drinks. Fallback goal $500 if Square does not publish one.

- **Commit/build:** 0.1.65 / Android versionCode 66
- **Branch:** `cursor/donate-square-link-23ee`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.65-debug/sunshines-bakery-0.1.65-debug.apk

## 0.1.64 — in-app Donate → existing Square link

Lawn **DONATE** sits above **TIP VIA AD**. First ship of the donation screen (blush/wine, optional name, Square CTA). Public checkout HTML parsed for goal/progress; 0.1.65 replaced the placeholder bar with live totals + a supporters list.

- **Commit/build:** 0.1.64 / Android versionCode 65
- **Branch:** `cursor/donate-square-link-23ee`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.64-debug/sunshines-bakery-0.1.64-debug.apk

## 0.1.63 — share throws across HTTPS and WSS

Ronald on 0.1.61: sees movement, no reliable remote cookies, no knockback. A WSS probe received CoS `t:throw` while the phone did not, and saw zero glenn tosses. Godot often falls to HTTPS tick; that path only returned the caller’s own events and did **not** broadcast throws to WSS. HTTPS ticks now return a shared event backlog (`event_seq`) and broadcast throw/impact/chat. The phone never drops a toss if WSS is not up yet. 0.1.62 target-side knockback stays (`hits_local`, no baker grace). CoS must redeploy `Dockerfile.explore` for the relay. No Play.

| Ask | Status |
| --- | --- |
| See remote throws | HTTPS ticks get others’ `throw` events; WSS still broadcasts. |
| Publish local toss | `send_throw` queues if WSS is down; HTTP tick + WSS broadcast. |
| Feel hits | Same 0.1.62 inbound `hits_local` knock + crumbs. |

**Monthly cost:** **$0 idle**. Still min 0 / max 1 under the $15 cap.

- **Commit/build:** 0.1.63 / Android versionCode 64
- **Branch:** `cursor/cookie-throw-relay-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.63-debug/sunshines-bakery-0.1.63-debug.apk

## Honest QA (0.1.63)

- Server tests: 16 OK (HTTP throw reaches other HTTP + WSS).
- Feature smoke EXIT 0: remote baker hit + local baker shoved 2.15 m. Godot WSS TLS `-29184` (HTTPS tick) still seen here.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.63-debug/sunshines-bakery-0.1.63-debug.apk (`shop.sunshines.bakery`, versionCode 64).
- **CoS must redeploy** `Dockerfile.explore` or live HTTPS phones still miss WSS throws.
- Physical two-phone still Ronald.

## 0.1.62 — feel remote cookie hits

WSS throws were visible; Ronald still felt nothing when CoS cookies reached him. 0.1.61 skipped baker tests for 0.1s (~1.2 m at throw speed) and skipped `local_baker` when `net_id` was empty. Inbound cookies now `hits_local` + `arm_from_net` with no baker grace, a 2.05 m planar volume, stronger knock (14) + lean-back flinch, and crumbs. Wall rays that strike a baker collider also knock. Impact near the local body knocks even without `hit_net_id`. Server accepts CosContracts nested `origin`/`dir` (CoS can redeploy `Dockerfile.explore`; not required for Ronald’s feel). No Play.

| Ask | Status |
| --- | --- |
| Feel remote hits | Inbound cookies hurt `local_baker` immediately. |
| Fight-noticeable | Knock 14 / 0.62s, camera punch, `play_hit` lean-back. |
| Persist patio | Same origin. Redeploy optional for nested throw aim + `hit_net_id`. |

**Monthly cost:** **$0 idle**. Still min 0 / max 1 under the $15 cap.

- **Commit/build:** 0.1.62 / Android versionCode 63
- **Branch:** `cursor/cookie-feel-hits-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.62-debug/sunshines-bakery-0.1.62-debug.apk

## Honest QA (0.1.62)

- Server tests: 15 OK (nested CosContracts throw origin/dir).
- Feature smoke EXIT 0: remote baker hit + **local baker shoved 2.15 m**, NPC still on grass, chat overlay compact, glb_meshes=67.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.62-debug/sunshines-bakery-0.1.62-debug.apk (`shop.sunshines.bakery`, versionCode 63).
- Hit detection: **client predicts**. Inbound `t:throw` sets `hits_local` and arms immediately (no baker grace). Server relays `throw` / `impact`. Redeploy `Dockerfile.explore` only if the CoS stand-in sends nested `origin`/`dir`.
- Physical two-phone still Ronald.

## 0.1.61 — cookie hits other bakers

Ronald’s 0.1.60 two-phone test: cookies flew through CoS. Root cause: hit tests only `village_npc`. Remote bakers have no collider. Cookies now sweep `remote_baker` + `local_baker` (not the thrower), flinch/knock the target, and send `hit_net_id` on impact. Client predicts the hit; server relays `hit_net_id` after CoS `Dockerfile.explore` redeploy. No Play.

| Ask | Status |
| --- | --- |
| Hit other players | Client sweep, 1.45 m baker radius, knockback + crumbs. |
| Shared feel | Impact carries `hit_net_id`. Both phones burst that `proj_id`. |
| Persist patio | Same origin. Redeploy only so live tick/WSS keep `hit_net_id`. |

**Monthly cost:** **$0 idle**. Still min 0 / max 1 under the $15 cap.

- **Commit/build:** 0.1.61 / Android versionCode 62
- **Branch:** `cursor/cookie-hit-players-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.61-debug/sunshines-bakery-0.1.61-debug.apk

## Honest QA (0.1.61)

- Server tests: 14 OK (`hit_net_id` on `apply_impact`).
- Feature smoke EXIT 0: cookie hit remote baker, NPC knockback still shoves on the grass, chat overlay still compact, glb_meshes=67.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.61-debug/sunshines-bakery-0.1.61-debug.apk (`shop.sunshines.bakery`, versionCode 62). `assets/project.binary` has `sunshine-explore` and no trycloudflare.
- Hit detection: **client predicts**. Cookies sweep `remote_baker` + `local_baker` (skip thrower) at 1.45 m, then knock + crumb burst. Server only relays `throw` / `impact` (`hit_net_id` after CoS `Dockerfile.explore` redeploy). Live health already shows idle prune (`idle_http_seconds=12`).
- Physical two-phone still Ronald.

## 0.1.60 — chat clear of the walking stick

Ronald liked Explore. Chat was sitting on the left stick and used chunky Mute/Block/Report buttons. Chat is now a compact overlay on the upper-left (name + text, scroll, tiny text actions, Send), ending above the 368px stick zone. Stick z_index 16 so its touches never become chat. Patio net unchanged. No Cloud Run redeploy. No Play.

| Ask | Status |
| --- | --- |
| Stick usable with chat open | ChatDock stops 392px from the bottom; Joy is last sibling at z 16. |
| Compact chat log | Scroll list of name + text. Mute / Block / Report are 28px links, not 56px buttons. |
| Persist patio | Unchanged `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`. |

**Monthly cost:** **$0 idle**. No extra GCP this pass.

- **Commit/build:** 0.1.60 / Android versionCode 61
- **Branch:** `cursor/explore-chat-hud-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.60-debug/sunshines-bakery-0.1.60-debug.apk

## Honest QA (0.1.60)

- Feature smoke EXIT 0: chat overlay clear of stick, Mute+Block+Report compact, joystick still walks, glb_meshes=67.
- Capture: `export/review/explore_chat_overlay.png` — top-left chat card, stick free below.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.60-debug/sunshines-bakery-0.1.60-debug.apk (`shop.sunshines.bakery`, versionCode 61).
- Physical two-phone still Ronald.

## 0.1.59 — idle prune + shared cookie crumbs

Quality pass after 0.1.58. Smoke filled the patio to 16 HTTPS ghosts. Join/tick now prune before the cap (12s HTTP / 45s hung WSS), HTTPS clients POST `/explore/leave`, and the same `player_id` reuses its seat. Cookie impacts relay so both phones burst the same `proj_id`. This agent cannot `gcloud`; CoS redeploys `server/Dockerfile.explore`. No Play.

| Ask | Status |
| --- | --- |
| Idle prune | Join/tick/health prune before the 16-cap. HTTP 12s, WSS 45s. |
| HTTPS leave | Explore POSTs `/explore/leave` when leaving. |
| Cookie impact | `apply_impact` + `ExploreNet.send_impact`. Live after CoS redeploy. |
| Persist patio | Same origin `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`. |

**Monthly cost:** **$0 idle**. No extra GCP this pass. Still min 0 / max 1 under the $15 cap.

- **Commit/build:** 0.1.59 / Android versionCode 60
- **Branch:** `cursor/explore-idle-prune-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.59-debug/sunshines-bakery-0.1.59-debug.apk
- **Advisor:** ChatGPT namespace still unavailable.

## Honest QA (0.1.59)

- Server tests: 14 OK (prune-before-cap, HTTP leave, impact relay).
- Feature smoke EXIT 0: glb_meshes=67, cute beanbags=3, cookie crumbs + impact queued, Mute+Block+Report, live Ada+Bo then POST leave.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.59-debug/sunshines-bakery-0.1.59-debug.apk (`shop.sunshines.bakery`, versionCode 60). `assets/project.binary` has `sunshine-explore-k6uuoen7wa-ue.a.run.app` and no trycloudflare.
- Live `/explore/health` still lacks `idle_http_seconds` until CoS redeploys `Dockerfile.explore`.
- Physical two-phone still Ronald.

## 0.1.58 — calmer Explore on a full patio

Quality pass after 0.1.57. Live patio was hitting 13–16 bakers. HUD no longer collides, Guest nameplates stay quiet, hidden GLB furniture is freed (67 meshes left vs hundreds), remotes hold a cheap disc cookie. No Cloud Run redeploy. No Play.

| Ask | Status |
| --- | --- |
| HUD jank | Live Fresh Batch lives on the status line only. Weekly board is 5 rows. |
| Nameplate wall | Generic `* Guest` plates hide unless close. |
| Mid-phone | `queue_free` hidden faceted GLB. Remote cookies are unshaded discs. Avatar fade 40 m. |
| World | Walkway paver joints stripped. Planters along the left of the blush path, not on the poufs. |
| Persist patio | Unchanged `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`. |

**Monthly cost:** **$0 idle**. No extra GCP this pass.

- **Commit/build:** 0.1.58 / Android versionCode 59
- **Branch:** `cursor/explore-calm-perf-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.58-debug/sunshines-bakery-0.1.58-debug.apk
- **Advisor:** ChatGPT namespace still unavailable.

## Honest QA (0.1.58)

- Feature smoke EXIT 0: glb_meshes=67, cute beanbags=3, cookie crumbs, Mute+Block+Report. Full-room tick 409 is allowed.
- Capture: `export/review/explore_hud_quiet.png` — status + 5-row board, no wrapping hint over the list.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.58-debug/sunshines-bakery-0.1.58-debug.apk (`shop.sunshines.bakery`, versionCode 59). `assets/project.binary` has `sunshine-explore-k6uuoen7wa-ue.a.run.app` and no trycloudflare.
- Physical two-phone still Ronald.

## 0.1.57 — rounded patio seats

Quality pass after 0.1.56. Default TPP no longer shows faceted beige beanbag mounds. Rounded poufs, south bistro umbrellas, Mute/Block/Report after chat. No Cloud Run redeploy. No Play.

| Ask | Status |
| --- | --- |
| Soften remaining blocky props | Hid `Beanbag00/01/02`; cute-pack poufs + SE/SW umbrellas. Disc pavers on practice/market paths. Rounded staff visor/apron/shoes. |
| Chat block/report | **Mute / Block / Report** after a remote line. Block persists in `GameSave`. Report is client + WS payload; server queue still thin. |
| Cookie impact broadcast | Still local crumbs. Not worth a sunshine-explore redeploy this pass. |
| Mid-phone perf | MSAA forced off in `bakery_world.setup`. Far trees/umbrellas/pavers fade. |
| Persist patio | Unchanged `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`. |

**Monthly cost:** **$0 idle**. No extra GCP this pass.

- **Commit/build:** 0.1.57 / Android versionCode 58
- **Branch:** `cursor/soften-beanbags-320e`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.57-debug/sunshines-bakery-0.1.57-debug.apk
- **Advisor:** ChatGPT namespace still unavailable.

## Honest QA (0.1.57)

- Feature smoke EXIT 0: cute beanbags=3, Mute+Block+Report, cookie n=1 crumbs=9.
- Capture: `export/review/explore_hud_quiet.png` shows a rounded pouf instead of faceted mounds.
- Debug APK **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.57-debug/sunshines-bakery-0.1.57-debug.apk (`shop.sunshines.bakery`, versionCode 58). `assets/project.binary` has `sunshine-explore-k6uuoen7wa-ue.a.run.app` and no trycloudflare.
- Cookie impact broadcast and server report queue still need a later Cloud Run pass.
- Physical two-phone still Ronald.

## 0.1.56 — cookie toss feel

Quality pass after 0.1.55. Toss cookie now winds up locally, leaves the hand, and remotes play the release pose from their own hand with crumb burst on impact. Rounded lawn shade trees, a one-tap Mute after patio chat, Order smoke that does not fail xvfb wheel, MSAA off for mid phones.

| Ask | Status |
| --- | --- |
| Cookie throw sync | Local 0.12s wind-up then release from `hand_socket`. Remotes skip wind-up, hide the hand cookie, spawn from their hand, and `burst_at` crumbs. Server impact broadcast still needs a later Cloud Run redeploy. Two-phone still Ronald. |
| Soften remaining blocky world | 8 capsule+sphere shade trees on the expanded lot. Pickup OmniLights removed. Authored furniture still hidden behind cute-pack. |
| Chat moderation | After a remote chat line, **Mute {name}** hides that display name locally. Server banned-term filter unchanged. Block/report queue still thin. |
| Order feature_smoke | Overflow + `MOUSE_FILTER_PASS` prove scroll; xvfb wheel is best-effort and no longer fails the suite. |
| Mid-Android performance | `msaa_3d=0`. NPC `visibility_range_end` 46 m. No pickup lights. |
| Persist patio | Unchanged live origin `https://sunshine-explore-k6uuoen7wa-ue.a.run.app`. No Play upload. No extra GCP spend this pass. |

**Monthly cost estimate:** **$0 idle** (min-instances 0). Typical patio use a few hours/month: **under $2**. Inside the $15 bakery GCP hard cap.

- **Commit/build:** 0.1.56 / Android versionCode 57
- **Branch:** `cursor/cookie-throw-feel-320e`
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Patio URL:** https://sunshine-explore-k6uuoen7wa-ue.a.run.app/explore/health
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.56-debug/sunshines-bakery-0.1.56-debug.apk
- **Advisor:** ChatGPT namespace still unavailable; work continued.

## Honest QA

- Cookie capture: `export/review/explore_toss_cookie.png` with a flying chocolate-chip cookie.
- Feature smoke EXIT 0: cookie projectile n=1, crumbs kids=9, Order overflow + PASS, origin `sunshine-explore`.
- Physical two-phone throw/impact still outstanding.
- Debug APK GitHub release **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.56-debug/sunshines-bakery-0.1.56-debug.apk (`shop.sunshines.bakery`, versionCode 57, 148528677 bytes). `assets/project.binary` contains `sunshine-explore-k6uuoen7wa-ue.a.run.app` and does **not** contain `trycloudflare`.

## What you can run now

1. Sideload 0.1.56 (release URL above).
2. EXPLORE 3D — Toss cookie: wind-up, cookie leaves the hand, crumbs on impact. Mute after a remote chat line.
3. Second phone: `docs/TWO_PHONE_PATIO.md` — watch the other baker’s arm fling and the cookie leave their hand.
4. ORDER / TIP VIA AD — 0.1.50 behavior preserved.

## 0.1.55 — persistent Cloud Run patio

CoS deployed `sunshine-explore` on bakery GCP. Cute-pack furniture and remote nameplate fade from the persist branch are included.

| Ask | Status |
| --- | --- |
| Persist patio on Cloud Run | **Live.** `https://sunshine-explore-k6uuoen7wa-ue.a.run.app` — `/explore/health` ok, room=patio, cap=16, min 0 / max 1. Not trycloudflare. |
| Player floating / TPP / avatar / Order / tip | Unchanged from 0.1.54. No Play upload. |

- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.55-debug/sunshines-bakery-0.1.55-debug.apk

