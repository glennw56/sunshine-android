# CURRENT_STATE — Sunshine COS

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

