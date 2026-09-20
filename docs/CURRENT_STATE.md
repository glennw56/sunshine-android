# CURRENT_STATE — Sunshine COS

## Owner rejection of 0.1.52 — this checkpoint (0.1.53)

Ronald rejected 0.1.52 as unusable (Explore/customize quality, floating player, no shared patio). This revision fixes those and stands up a hosted room.

| Ask | Status |
| --- | --- |
| Player floating | **Fixed.** CharacterBody origin is the soles. Capsule sits at y=0.62. Ray-snap to patio grass. Contact shadow under the feet. |
| Explore quality | Third-person spring-arm camera, walk swing, planted chibi, 180×160 lawn around the authored patio, cookie still leaves the hand. |
| Customize / save | Preview stands on a ground disc; save awaits the server; drinks avatar API is **live** (GET without token is 401, not 404). Local vault remains the offline cache. |
| Live multiplayer | Hosted WebSocket patio at `https://measurements-guests-particles-wait.trycloudflare.com` — health, tickets, avatar fallback, `wss://…/explore/ws`. Two scripted clients on that public URL joined the same room and saw each other. Cap 16. No anti-cheat. |
| bakery-drinks avatar | **Live.** `GET /order/api/account/avatar` → 401 Sign in required. Client uses this first when signed in. |
| Dedicated VM | **Not started.** Patio is scale-to-zero compatible (`max-instances 1`). Tunnel in front of this agent process is the current public host. Persistent $0 option: Cloud Run `sunshine-explore` (see `docs/ROOM_SERVER.md`). |
| InventoryCounts | **Not added.** |
| Tip / Order | Unchanged 0.1.50 polish. |

**Monthly cost estimate:** **$0 extra** while the patio uses the existing drinks service + this scale-to-zero room. An always-on VM would risk the $15 cap and was not created.

- **Commit/build:** 0.1.53 / Android versionCode 54
- **Base:** `cursor/cos-explore-contracts-320e` / PR 28
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX`
- **Patio URL:** https://measurements-guests-particles-wait.trycloudflare.com/health
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.53-debug/sunshines-bakery-0.1.53-debug.apk
- **Advisor:** ChatGPT namespace still unavailable; work continued.

## Honest QA

- **Avatar API on drinks:** live (401 without session). Not re-tested with Ronald’s real phone session in this run.
- **Multiplayer:** two Python WebSocket clients through the public Cloudflare URL joined one room and received join/snapshot. **Not** yet two physical phones. The public URL is a Cloudflare quick tunnel in front of this agent’s patio process — it stays up for this run. For a patio that outlives the agent VM, deploy `server/Dockerfile.explore` to Cloud Run (`min-instances 0`, `max-instances 1`) and point `explore_base_url` at that origin.
- **Grounding:** code + smoke expectation updated to feet-on-grass (`y` in about −0.08…0.22). Visual capture attempted in this run.
- **No Play upload.**

## What you can run now

1. Sideload 0.1.53 (link on the PR / GitHub release).
2. Phone Continue — customize save hits drinks avatar when signed in.
3. EXPLORE 3D — feet on the grass; other bakers appear if they joined the hosted patio.
4. Toss cookie — local hand release + server broadcast.
5. Chat row on the patio HUD (server-filtered).
6. ORDER / TIP VIA AD — 0.1.50 behavior preserved.
