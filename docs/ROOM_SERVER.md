# COS patio room under the $15/mo GCP cap

Owner approval (2026-09-19 / 2026-09-20): bakery GCP **hard cap ~$15/mo**. Prefer existing bakery-drinks Cloud Run, scale-to-zero. No new always-on VM unless it still fits with everything else.

## What is running

A dedicated **WebSocket patio process** (`server/explore_app.py`):

- `GET /health` and `GET /explore/health`
- `POST /explore/ticket` — short-lived HMAC join ticket
- `WS /explore/ws` — welcome / snapshot / throw / chat / leave
- `GET/PUT /order/api/account/avatar` — fallback forever-look store (file + memory)

Phones are never the host. Room cap **16**. Protocol v1. No anti-cheat beyond speed/throw/chat clamps.

Transport (cheapest native-Android path that fits Cloud Run and the $15 cap):

1. **Preferred:** `wss://…/explore/ws` on Cloud Run. Google-managed TLS works with Godot 4.3 mbedtls. Session affinity + `--max-instances 1` keep every phone in one process.
2. **Fallback already in the APK:** `HTTPS POST /explore/tick` when WSS TLS fails (seen on Cloudflare quick tunnels, error `-0x7200`). Same room, same snapshot.
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

## Deploy (same $15 cap)

```bash
GCP_PROJECT=YOUR_BAKERY_PROJECT bash tools/deploy_sunshine_explore.sh
```

That builds `server/Dockerfile.explore` and deploys `sunshine-explore` with `--min-instances 0 --max-instances 1 --session-affinity --timeout 3600 --cpu-throttling`. Then set `sunshine/explore_base_url` (or `SUNSHINE_EXPLORE_URL`) to the printed HTTPS origin.

This agent VM has gcloud installed but **no bakery GCP credentials**, so it cannot finish the deploy from here. The Cloudflare quick tunnel in `project.godot` dies with the VM — do not treat it as persistent.

Two-phone / two-client proof: `docs/TWO_PHONE_PATIO.md`.

Laptop:

```bash
pip install -r server/requirements-explore.txt
uvicorn explore_app:app --app-dir server --host 0.0.0.0 --port 8080
```

## Avatar forever-save

Client tries bakery-drinks `GET/PUT/POST/PATCH /order/api/account/avatar` first (Square `sunshine_avatar`). Patio is only a fallback when drinks is 404 or down — not after 401. Local `user://profile_vault.json` remains the offline cache.

Drinks patch: `server/patches/bakery-local-avatar.patch`. This agent still cannot push `glennw56/bakery-local` or run `gcloud`.

## Rollback

Stop the Cloud Run service or blank `explore_base_url`. Ordering and tip flows do not use this process.
