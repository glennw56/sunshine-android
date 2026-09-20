# CURRENT_STATE — Sunshine COS

- **Commit/build:** 0.1.51 / Android versionCode 52 (this branch)
- **Base:** `cursor/menu-photo-admob-a99b` (0.1.50 tip polish + AdMob + menu photo)
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · Square via bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX` Irondale
- **Completed this checkpoint:** M0 audit notes; §2 contracts; signup-gated Explore customize + forever local/account vault; §10 cart replacement + inventory eligibility; §11 tip polish preserved; version bump
- **Active owners:** COS / integrator (this agent). Logical roster is sequential in one agent — no extra bots were spawned.
- **Interface decisions:** see `docs/COS_CONTRACTS.md`
- **Blockers:** bakery-drinks does not yet expose Square InventoryCounts; avatar PUT `/order/api/account/avatar` is proposed in `server/account.py` and is **not** live on Cloud Run; no dedicated game server
- **Next runnable step:** apply avatar route to bakery-drinks (no new paid service); then dedicated room server (ENet native, 16-player cap)
- **Artifacts:** `docs/BASELINE_M0.md`, `docs/ARCHITECTURE.md`, `docs/ART_DIRECTION.md`, `docs/REQUIREMENT_MATRIX.md`, `docs/CATALOG_MANIFEST.md`, `tools/sunshine_commerce.py`. Debug APK written to `export/sunshines-bakery-0.1.51-debug.apk` (142M, AdMob packaged). Cursor artifact store rejected the 142M file (0-byte after copy); this agent cannot create a GitHub release (`gh` is read-only). No Play upload.

## Advisor

ChatGPT advisor access was **not available** in this run (no ChatGPT tool/namespace). Limitation recorded; work continued.

## What you can run now

1. Phone login / skip guest (unchanged).
2. ORDER — shopping list is inventory-eligible only; **Order again** replaces the cart.
3. TIP VIA AD — 0.1.50 centered blush/wine sheet, first sentence only, no AdMob wording, no tip count.
4. EXPLORE 3D — third-person rounded avatar; toss cookie from the hand socket.
5. CUSTOMIZE LOOK — **signed-in only**; recipe stored in `user://profile_vault.json` keyed by Square customer id (survives logout). First signed-in visit without a saved look opens customize.
