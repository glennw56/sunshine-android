# Cheapest COS room server under the $15/mo GCP cap

Owner approval (2026-09-19): bakery GCP **hard cap ~$15/mo**. Prefer existing bakery-drinks Cloud Run, scale-to-zero. No new always-on VM unless it still fits with everything else.

## What already costs money

`bakery-drinks` Cloud Run (`min-instances 0`, us-east1) already serves menu, checkout, phone login, and (after redeploy) avatar. Scale-to-zero is the reason drinks stays cheap. Do not raise `min-instances`.

Twilio ready-SMS is **not** billed to GCP (DEPLOY.md). Leave it alone.

## What does **not** fit under the cap

A dedicated always-on game host (e2-micro / e2-small, 24×7) is typically **$6–12/mo** before egress. Added to current drinks + Artifact Registry + logging, that is the item that **risks breaking $15**. ENet/UDP also does not fit Cloud Run (HTTP/1, 300s timeout, no customer UDP). **Not implemented.**

## Cheapest option that fits (implemented / planned)

| Piece | Where | Extra monthly |
| --- | --- | --- |
| Forever avatar | Square customer custom attribute `sunshine_avatar` on existing drinks | **$0** (same service, same token) |
| Join tickets (next) | HMAC mint on bakery-drinks `POST /order/api/explore/ticket` | **$0** when added (same scale-to-zero process) |
| Room simulation | Not hosted | $0 |

Phones keep predicting movement locally. A room process is a **later** spend decision (hours-only Cloud Run job or a scheduled VM), not this checkpoint.

InventoryCounts stay **optional**. They would also live on drinks (same Square token, ITEMS_READ / inventory read). Not added — live menu has no ATS today and the client already uses provider flags.

## Rollback

Avatar routes unused if Cloud Run is not redeployed (client treats 404 as “use local vault”). No new GCP product to delete.
