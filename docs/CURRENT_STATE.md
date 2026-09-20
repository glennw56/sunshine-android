# CURRENT_STATE — Sunshine COS

- **Commit/build:** 0.1.52 / Android versionCode 53 (this branch)
- **Base:** `cursor/menu-photo-admob-a99b` (0.1.50 tip polish + AdMob + menu photo)
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · Square via bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX` Irondale
- **Completed this checkpoint:** M0 + customize + §10/§11; **avatar GET/PUT applied on bakery-local `feat/square-account-routes`** (Square custom attribute `sunshine_avatar`); client loads/saves that API when signed in; room-server cost note; no dedicated VM
- **Active owners:** COS / integrator (this agent). Logical roster is sequential in one agent — no extra bots were spawned.
- **Interface decisions:** see `docs/COS_CONTRACTS.md`
- **Blockers:** this agent has **no GCP credentials**, so Cloud Run `bakery-drinks` is **not redeployed from here**. Live `GET /order/api/account/avatar` is still 404 until Glenn/CoS runs the existing drinks deploy. InventoryCounts still omitted (optional). No dedicated game server.
- **Next runnable step:** `gcloud run deploy bakery-drinks` from bakery-local avatar branch (same image, min-instances 0). Then sideload 0.1.52.
- **Artifacts:** `docs/ROOM_SERVER.md`. Debug APK 0.1.51 remains in `export/`; 0.1.52 export attempted after this bump. Cursor artifact store rejected 142M; `gh` is read-only so no GitHub release. No Play upload.

## Advisor

ChatGPT advisor access was **not available** in this run (no ChatGPT tool/namespace). Limitation recorded; work continued.

## What you can run now

1. Phone login / skip guest (unchanged).
2. ORDER — shopping list is inventory-eligible only; **Order again** replaces the cart.
3. TIP VIA AD — 0.1.50 centered blush/wine sheet, first sentence only, no AdMob wording, no tip count.
4. EXPLORE 3D — third-person rounded avatar; toss cookie from the hand socket.
5. CUSTOMIZE LOOK — **signed-in only**; recipe stored in `user://profile_vault.json` keyed by Square customer id (survives logout). First signed-in visit without a saved look opens customize.
