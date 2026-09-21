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

1. **Preferred:** `wss://…/explore/ws` on Cloud Run. Google-managed TLS works with Godot 4.3 mbedtls. Session affinity + `--max-instances 1` keep every phone in one process. The first WS frame **must** be `t:hello` (ticket optional). The 0.1.74 client awaited `/explore/ticket` then often sent `t:state` first; the room closed the socket and the phone stayed on HTTP polling. 0.1.75 sends hello immediately and does not send state until `t:welcome`.
2. **Fallback already in the APK:** `HTTPS POST /explore/tick` when WSS cannot stay open (TLS `-0x7200` on some tunnels, or a closed socket). Same room. Remotes interpolate (~180 ms buffer) so 5–10 Hz ticks do not rubber-band. Leaving Explore POSTs `/explore/leave` so the seat does not wait on idle prune. The phone retries WSS about every 5 s.
3. **Not used:** ENet/UDP. That needs a 24×7 VM (~$6–12) and would crowd the $15 cap.
4. **Not used:** Cloud Run `--min-instances 1`. A cold `/explore/health` can take a few seconds after scale-to-zero; in-session stutter was the hello/state race + HTTP fallback, not idle cold start. Keep min 0 unless join-after-idle becomes the complaint.

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

Live `/explore/health` reports `players`, `cap`, `idle_http_seconds`, and `idle_ws_seconds`. Cookie **hits** are client-side: inbound throws set `hits_local` and test bakers immediately (no 0.1s grace). HTTPS `/explore/tick` now returns a shared `event_seq` backlog and broadcasts `throw`/`impact`/`chat` to WSS so phone HTTPS and WSS see the same cookies. The phone must ack `event_seq` (and skip `seq <= cursor`) so chat is not re-appended every tick; chat also dedupes by `msg_id`.

WSS movement is a **one-player** `t:snapshot` (plus `vx`/`vz`) so old APKs still upsert that baker without a full-room flood every 100 ms. Redeploy `Dockerfile.explore` for that bandwidth cut; the 0.1.75 APK already stays on WSS and interpolates against the live server as-is. Chat/cookie `msg_id` + `event_seq` are unchanged.

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
