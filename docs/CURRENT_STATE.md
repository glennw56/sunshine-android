# CURRENT_STATE — Sunshine COS

## Owner approval 2026-09-19 — deploy / cost / APK

Ronald authorized bakery GCP work under a **$15/mo hard cap**. This checkpoint used that approval as follows:

| Ask | What happened |
| --- | --- |
| Deploy forever avatar `GET/PUT /order/api/account/avatar` on bakery-drinks | **Applied** on bakery-local `feat/square-account-routes` (commit `4459897` locally) and vendored as `server/patches/bakery-local-avatar.patch`. Durable store is Square custom attribute `sunshine_avatar` (same existing Customers token). **Not live on Cloud Run:** this agent has no GCP ADC / `gcloud`, and `glennw56/bakery-local` push is **403** to `cursor[bot]`. Rechecked 2026-09-20: live `GET` and `PUT` still **404**. |
| Wire the signed-in client | **Done.** `ProfileStore.refresh_from_server` / `_sync_remote` call the live drinks URL; login awaits GET before customize. 404 falls back to `user://profile_vault.json`. |
| Square InventoryCounts | **Not added.** Live menu is still 8 drinks with no ATS. Optional and would be $0 on the same service; omitted. |
| Dedicated always-on game VM | **Not started.** Would risk the $15 cap (`docs/ROOM_SERVER.md`). Cheapest fit: avatar + later join tickets on existing scale-to-zero drinks (**$0**). |
| Public 0.1.51+ debug APK | **Published:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.52-debug/sunshines-bakery-0.1.52-debug.apk |

**Monthly cost estimate:** **$0 extra** on current bakery-drinks (keep `--min-instances 0`). No new Cloud Run service, no Cloud SQL, no VM. Redeploy of the existing image is the remaining owner/CoS step (`server/patches/README.md`).

- **Commit/build:** 0.1.52 / Android versionCode 53 (this branch)
- **Base:** `cursor/menu-photo-admob-a99b` (0.1.50 tip polish + AdMob + menu photo)
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · Square via bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX` Irondale
- **Completed this checkpoint:** M0 + customize + §10/§11; avatar GET/PUT applied as drinks patch + client wired; room-server cost note; no dedicated VM; public 0.1.52 APK
- **Active owners:** COS / integrator (this agent). Logical roster is sequential in one agent — no extra bots were spawned.
- **Interface decisions:** see `docs/COS_CONTRACTS.md`
- **Blockers:** Cloud Run `bakery-drinks` is **not redeployed from here** (no GCP, cannot push bakery-local). Live avatar path is still 404 until Glenn/CoS applies the patch and runs the existing drinks deploy.
- **Next runnable step:** apply `server/patches/bakery-local-avatar.patch` on bakery-local `feat/square-account-routes`, then `gcloud run deploy bakery-drinks --min-instances 0`. Sideload 0.1.52.
- **Artifacts:** `docs/ROOM_SERVER.md`. Public sideload: https://github.com/glennw56/sunshine-android/releases/download/v0.1.52-debug/sunshines-bakery-0.1.52-debug.apk — No Play upload.

## Advisor

ChatGPT advisor access was **not available** in this run (no ChatGPT tool/namespace). Limitation recorded; work continued.

## What you can run now

1. Phone login / skip guest (unchanged).
2. ORDER — shopping list is inventory-eligible only; **Order again** replaces the cart.
3. TIP VIA AD — 0.1.50 centered blush/wine sheet, first sentence only, no AdMob wording, no tip count.
4. EXPLORE 3D — third-person rounded avatar; toss cookie from the hand socket.
5. CUSTOMIZE LOOK — **signed-in only**. When the drinks avatar route is live, signed-in load/save uses `GET/PUT /order/api/account/avatar` (Square `sunshine_avatar`). Until Cloud Run is redeployed (still 404), the client keeps `user://profile_vault.json` keyed by Square customer id. First signed-in visit without a saved look opens customize.
