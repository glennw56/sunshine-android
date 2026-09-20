# COS patio room under the $15/mo GCP cap

Owner approval (2026-09-19 / 2026-09-20): bakery GCP **hard cap ~$15/mo**. Prefer existing bakery-drinks Cloud Run, scale-to-zero. No new always-on VM unless it still fits with everything else.

## What is running

A dedicated **WebSocket patio process** (`server/explore_app.py`):

- `GET /health` and `GET /explore/health`
- `POST /explore/ticket` — short-lived HMAC join ticket
- `WS /explore/ws` — welcome / snapshot / throw / impact / chat / leave
- `POST /explore/tick` — HTTPS fallback (same room)
- `POST /explore/leave` — HTTPS clients free their seat immediately
- `GET/PUT /order/api/account/avatar` — fallback forever-look store (file + memory)

Phones are never the host. Room cap **16**. Protocol v1. No anti-cheat beyond speed/throw/chat clamps.

Transport (cheapest native-Android path that fits Cloud Run and the $15 cap):

1. **Preferred:** `wss://…/explore/ws` on Cloud Run. Google-managed TLS works with Godot 4.3 mbedtls. Session affinity + `--max-instances 1` keep every phone in one process.
2. **Fallback already in the APK:** `HTTPS POST /explore/tick` when WSS TLS fails (seen on Cloudflare quick tunnels, error `-0x7200`). Same room, same snapshot. Leaving Explore POSTs `/explore/leave` so the seat does not wait on idle prune.
3. **Not used:** ENet/UDP. That needs a 24×7 VM (~$6–12) and would crowd the $15 cap.

Cloud Run WebSockets are supported (3600s timeout). UDP is the thing Cloud Run cannot do — that is why the patio is WebSocket + HTTPS, not ENet.

## Monthly cost

| Piece | Extra monthly |
| --- | --- |
| Existing bakery-drinks (menu, login, checkout) | current (scale-to-zero) |
| Patio room Cloud Run `min-instances 0`, `max-instances 1` | **$0–1** idle; billed only while someone is on the patio |
| Always-on e2-micro game VM | **$6–12** — **not used** (risks the $15 cap) |
| Square InventoryCounts | not added |

`--max-instances 1` keeps every phone in the same process. `--min-instances 0` scales to zero when the patio is empty.

## How the room clears

Cap is **16**. Smoke, capture, and HTTPS clients that never send WebSocket `leave` used to pin the patio until Cloud Run scaled to zero (or a human redeployed). Clearing rules now:

1. **WebSocket disconnect** — `leave()` runs in the socket `finally`. Immediate.
2. **HTTPS leave** — Explore POSTs `/explore/leave` (or `/explore/tick` with `"leave": true`). Immediate.
3. **Idle prune** — runs on **join**, **tick**, **snapshot**, and **health**, *before* the cap check.
   - HTTPS tick seats: **12 seconds** after the last tick (`idle_http_seconds` on `/explore/health`).
   - WebSocket seats: **45 seconds** (`idle_ws_seconds`). Hung sockets only; a clean disconnect already left.
4. **Same `player_id` rejoins** reuse that baker’s seat instead of minting a 17th ghost.
5. **Scale-to-zero** — when nobody is requesting, Cloud Run (`min-instances 0`) drops the process and the in-memory room with it.

Live `/explore/health` reports `players`, `cap`, `idle_http_seconds`, and `idle_ws_seconds`. Cookie **hits** are client-side: inbound throws set `hits_local` and test bakers immediately (no 0.1s grace). The server relays `throw` and `impact` (`hit_net_id` + CosContracts nested `origin`/`dir` after `Dockerfile.explore` redeploy).

This agent **cannot** `gcloud` (no bakery ADC). CoS redeploys with:

```bash
GCP_PROJECT=YOUR_BAKERY_PROJECT bash tools/deploy_sunshine_explore.sh
```

`server/Dockerfile.explore` copies `explore_sim.py` + `explore_app.py`. Confirm after deploy: `idle_http_seconds` is 12 on `GET /explore/health`, then `python3 tools/two_client_patio.py https://sunshine-explore-k6uuoen7wa-ue.a.run.app` (the tool now POSTs leave).

## Deploy (same $15 cap)

```bash
GCP_PROJECT=YOUR_BAKERY_PROJECT bash tools/deploy_sunshine_explore.sh
```

Live origin (CoS deployed, min 0 / max 1):

**https://sunshine-explore-k6uuoen7wa-ue.a.run.app**

`project.godot` `sunshine/explore_base_url` and `AppConfig.explore_base_url` point at that HTTPS origin. Health: `/explore/health`. Two-phone / two-client proof: `docs/TWO_PHONE_PATIO.md`.

Laptop:

```bash
pip install -r server/requirements-explore.txt
uvicorn explore_app:app --app-dir server --host 0.0.0.0 --port 8080
```

## Avatar forever-save

Client tries bakery-drinks `GET/PUT/POST/PATCH /order/api/account/avatar` first (Square `sunshine_avatar`). Patio is only a fallback when drinks is 404 or down — not after 401. Local `user://profile_vault.json` remains the offline cache.

Drinks patch: `server/patches/bakery-local-avatar.patch`. This agent still cannot push `glennw56/bakery-local` or run `gcloud`. CoS has bakery gcloud for `tools/deploy_sunshine_explore.sh`.

## Rollback

Stop the Cloud Run service or blank `explore_base_url`. Ordering and tip flows do not use this process.
