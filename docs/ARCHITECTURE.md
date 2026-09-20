# Architecture — COS Explore upgrade

## Chosen stack (simplest supportable)

```
Godot 4.3 Android client
    │ HTTPS (existing)
    ├─ bakery-drinks Cloud Run  → Square Customers / Catalog / Orders / Checkout / Loyalty
    │     proposed: GET/PUT /order/api/account/avatar  (file store, no extra GCP service)
    │
    └─ (next) dedicated Godot headless game process
          ENet : port TBD, admission via join ticket minted by bakery-drinks
```

Components that may share a process: account API + catalog + avatar vault (bakery-drinks). Game simulation stays a separate dedicated process so a customer phone is never the host.

Avoided: new microservices, new paid auth vendor, scraping Square dashboards, inventing password crypto.

## Persistence

| Data | Where | Restart |
| --- | --- | --- |
| Square customer / orders | Square (source of truth) | Survives |
| Session token | bakery-drinks HMAC + `user://` | Revoke = 401 |
| Avatar / username | `user://profile_vault.json`; proposed drinks file store | Survives logout; reinstall loses local vault until drinks route is live |
| Cart | In-memory (+ not Square until checkout) | Lost on kill |
| Room state | Game server memory | Lost on room shutdown; late joiners get snapshot |
| Chat | Not stored by default | Reports only, limited retention TBD |

## Version mismatch

Client sends `protocol: 1`. Server rejects other versions with a structured error. Do not silently degrade.

## Transport tradeoff

Android-native ENet is acceptable. There is **no** HTML5 export in `export_presets.cfg`. If Ronald later wants web Explore, we add a WebSocket path rather than forcing ENet in the browser.

## Cost sketch (labels, not a bill)

Assumptions: 16 players/room, one e2-small or Cloud Run job equivalent, us-east1, modest egress.

| Concurrent players | Rough monthly (game + existing drinks) |
| --- | --- |
| 10 | Existing drinks (~current) + $0 if no dedicated VM yet |
| 50 | One small always-on VM often exceeds the **$15/mo bakery GCP cap** — needs owner approval / staging hours-only |
| 200 | Multiple rooms; do not turn on without a spend decision |

This milestone adds **no** new production spend.

## Rollback

- Client: sideload previous APK (0.1.50). Cart/avatar fields are additive.
- Avatar route: unused if not mounted.
- Cart replacement is client-side; Square checkout is unchanged.
