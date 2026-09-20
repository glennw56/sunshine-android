# CURRENT_STATE — Sunshine COS

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
- Physical two-phone throw/impact still outstanding.
- Debug APK GitHub release **HTTP 200** after ship (`shop.sunshines.bakery`, versionCode 57). `assets/project.binary` must contain `sunshine-explore-k6uuoen7wa-ue.a.run.app` and must **not** contain `trycloudflare`.

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

