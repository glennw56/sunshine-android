# CURRENT_STATE — Sunshine COS

## 0.1.55 — persistent Cloud Run patio

CoS deployed `sunshine-explore` on bakery GCP. This APK points at that origin. Cute-pack furniture and remote nameplate fade from the persist branch are included.

| Ask | Status |
| --- | --- |
| Persist patio on Cloud Run | **Live.** `https://sunshine-explore-k6uuoen7wa-ue.a.run.app` — `/explore/health` ok, room=patio, cap=16, min 0 / max 1. `project.godot` + `AppConfig` default use this origin. Not trycloudflare. |
| Soften faceted patio | Authored furniture hidden; `cute_pack.gd` rounded tables, planters, lamps, hedges, stalls. Logo wall + grass stay authored. |
| Remote nameplate clutter | Local plate hidden. Custom names fade 5.5–10 m. Default Sunshine Guest / Baker only inside 3.8 m. Idle HTTPS ghosts prune after 8 s. |
| Two-phone / two-client | `docs/TWO_PHONE_PATIO.md`. CI two-client against the live origin. Physical two-phone still Ronald. |
| Player floating / TPP / avatar / Order / tip | Unchanged from 0.1.54. No Play upload. |

**Transport:** WSS `/explore/ws` on Google TLS; HTTPS `POST /explore/tick` fallback. ENet/UDP not used.

**Monthly cost estimate:** **$0 idle** (min-instances 0). Typical patio use a few hours/month: **under $2**. Inside the $15 bakery GCP hard cap with existing drinks. No e2-micro VM.

- **Commit/build:** 0.1.55 / Android versionCode 56
- **Branch:** `cursor/persist-explore-patio-320e` / PR 29
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX`
- **Patio URL:** https://sunshine-explore-k6uuoen7wa-ue.a.run.app/explore/health
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.55-debug/sunshines-bakery-0.1.55-debug.apk
- **Advisor:** ChatGPT namespace still unavailable; work continued.

## Honest QA

- Live patio health: `ok`, `service=sunshine-explore`, `room=patio`, `cap=16`.
- Client wiring: `AppConfig.explore_http_origin()`, WSS, and tick APIs must contain `sunshine-explore-k6uuoen7wa-ue.a.run.app` and must not contain `trycloudflare`.
- Two HTTPS tick clients on that origin share one snapshot.
- Physical two-phone walk-around still outstanding.
- Debug APK GitHub release **HTTP 200**: https://github.com/glennw56/sunshine-android/releases/download/v0.1.55-debug/sunshines-bakery-0.1.55-debug.apk (`shop.sunshines.bakery`, versionCode 56). `assets/project.binary` contains `sunshine-explore-k6uuoen7wa-ue.a.run.app` and does **not** contain `trycloudflare`.

## What you can run now

1. Sideload 0.1.55 (release URL above).
2. Phone Continue — customize save still hits drinks avatar when signed in.
3. EXPLORE 3D — joins the Cloud Run patio; rounded lot props; nameplates only when close.
4. Second phone: `docs/TWO_PHONE_PATIO.md`.
5. ORDER / TIP VIA AD — 0.1.50 behavior preserved.
