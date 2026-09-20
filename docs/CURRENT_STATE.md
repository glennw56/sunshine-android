# CURRENT_STATE — Sunshine COS

## Owner rejection of 0.1.52 — this checkpoint (0.1.54)

Ronald rejected 0.1.52 as unusable (Explore/customize quality, floating player, no shared patio). 0.1.53 planted feet and stood up a hosted room. **0.1.54** keeps those fixes and makes walking / looking easier (fixed left stick, right-half look, over-shoulder camera). Feel only — cute bakery world, no combat HUD.

| Ask | Status |
| --- | --- |
| Player floating | **Fixed.** CharacterBody origin is the soles. Capsule sits at y=0.62. Ray-snap to patio grass. Contact shadow under the feet. |
| Easier move / look | **Fixed in code.** Fixed bottom-left stick (walk / jog / sprint + top-of-stick sprint lock). Invisible right-half look, 1:1 while down, short ease on lift. Move yaw freezes while looking and walking. Over-right-shoulder SpringArm. Big thumb zones that do not overlap. |
| Explore quality | Third-person spring-arm camera, walk swing, planted chibi, 180×160 lawn around the authored patio, cookie still leaves the hand. |
| Customize / save | Preview stands on a ground disc; save awaits the server; drinks avatar API is **live** (GET without token is 401, not 404). Local vault remains the offline cache. |
| Live multiplayer | Hosted WebSocket patio at `https://measurements-guests-particles-wait.trycloudflare.com` — health, tickets, avatar fallback, `wss://…/explore/ws`, HTTPS `POST /explore/tick`. Cap 16. No anti-cheat. Tunnel dies with this agent VM. |
| bakery-drinks avatar | **Live.** `GET/PUT/POST/PATCH /order/api/account/avatar` (deploy `bakery-drinks-00021-ghm`) → 401 without Bearer. Square custom attribute `sunshine_avatar`. Client uses this first when signed in. |
| Dedicated VM | **Not started.** Patio is scale-to-zero compatible (`max-instances 1`). Persistent $0 option: Cloud Run `sunshine-explore` (see `docs/ROOM_SERVER.md`). |
| InventoryCounts | **Not added.** |
| Tip / Order | Unchanged 0.1.50 polish. |

**Monthly cost estimate:** **$0 extra** while the patio uses the existing drinks service + this scale-to-zero room. An always-on VM would risk the $15 cap and was not created.

- **Commit/build:** 0.1.54 / Android versionCode 55
- **Base:** `cursor/cos-explore-contracts-320e` / PR 28
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX`
- **Patio URL:** https://measurements-guests-particles-wait.trycloudflare.com/health
- **APK:** 0.1.54 release URL is pending export. Last public sideload remains https://github.com/glennw56/sunshine-android/releases/download/v0.1.53-debug/sunshines-bakery-0.1.53-debug.apk
- **Advisor:** ChatGPT namespace still unavailable; work continued.

## Honest QA

- **Avatar API on drinks:** live (401 without session). Not re-tested with Ronald’s real phone session in this run.
- **Multiplayer:** two Python WebSocket clients through the public Cloudflare URL joined one room and received join/snapshot. **Not** yet two physical phones. The public URL is a Cloudflare quick tunnel in front of this agent’s patio process — it stays up for this run. For a patio that outlives the agent VM, deploy `server/Dockerfile.explore` to Cloud Run (`min-instances 0`, `max-instances 1`) and point `explore_base_url` at that origin.
- **Grounding:** xvfb capture `explore_tpp_look.png` after a forward walk: `y=0.02` (in −0.08…0.22). Spawn `(0, 0.02, 11)` → `(0, 0.02, 8.52)` toward the logo wall.
- **Controls:** 48 px right-half look changed yaw by −0.173 (1:1 at 0.36). Smoke still requires top-of-stick forward `y ≥ 0.35`, `look_delta(80,0)` yaws ≥ 0.06, no NoticeService on Explore enter, look plate hidden.
- **Patio during capture:** HUD `Patio · live · 6 bakers` (HTTPS tick; Godot WSS to the tunnel still fails TLS).
- **No Play upload.**

## What you can run now

1. Sideload the latest debug APK on the PR / GitHub release (0.1.54 when published; 0.1.53 until then).
2. Phone Continue — customize save hits drinks avatar when signed in.
3. EXPLORE 3D — left stick walks the patio; right-half drag looks; feet on the grass; other bakers appear if they joined the hosted patio.
4. Toss cookie — local hand release + server broadcast.
5. Chat row on the patio HUD (server-filtered).
6. ORDER / TIP VIA AD — 0.1.50 behavior preserved.
