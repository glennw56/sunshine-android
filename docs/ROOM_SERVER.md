# COS patio room under the $15/mo GCP cap

Owner approval (2026-09-19 / 2026-09-20): bakery GCP **hard cap ~$15/mo**. Prefer existing bakery-drinks Cloud Run, scale-to-zero. No new always-on VM unless it still fits with everything else.

## What is running

A dedicated **WebSocket patio process** (`server/explore_app.py`):

- `GET /health` and `GET /explore/health`
- `POST /explore/ticket` — short-lived HMAC join ticket
- `WS /explore/ws` — welcome / snapshot / throw / chat / leave
- `GET/PUT /order/api/account/avatar` — fallback forever-look store (file + memory)

Phones are never the host. Room cap **16**. Protocol v1. No anti-cheat beyond speed/throw/chat clamps.

Transport is **WebSocket over TLS**, not ENet. ENet/UDP does not fit Cloud Run and would need a 24×7 VM.

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
gcloud builds submit --tag REGION-docker.pkg.dev/PROJECT/bakery/sunshine-explore \
  --file server/Dockerfile.explore
gcloud run deploy sunshine-explore \
  --image REGION-docker.pkg.dev/PROJECT/bakery/sunshine-explore \
  --region REGION \
  --min-instances 0 \
  --max-instances 1 \
  --session-affinity \
  --allow-unauthenticated \
  --port 8080
```

Then set `sunshine/explore_base_url` (or `SUNSHINE_EXPLORE_URL`) to that HTTPS origin.

Laptop:

```bash
pip install -r server/requirements-explore.txt
uvicorn explore_app:app --app-dir server --host 0.0.0.0 --port 8080
```

## Avatar forever-save

Client tries bakery-drinks `GET/PUT /order/api/account/avatar` first (Square `sunshine_avatar`). If that is still 404, it uses the patio service’s same path. Local `user://profile_vault.json` remains the offline cache.

Drinks patch: `server/patches/bakery-local-avatar.patch`. This agent still cannot push `glennw56/bakery-local` or run `gcloud`.

## Rollback

Stop the Cloud Run service or blank `explore_base_url`. Ordering and tip flows do not use this process.
