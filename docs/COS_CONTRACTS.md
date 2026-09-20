# Shared COS contracts (v1)

Agreed before parallel work. Godot: `scripts/contracts/cos_contracts.gd`. Server helpers: `server/account.py`.

## 1. Identity

| Field | Stability | Public? | Notes |
| --- | --- | --- | --- |
| `player_id` | Stable (`plr_` + hex) | Yes | Never the authorization key |
| `username` | Unique, normalized `[a-z0-9_]{3,20}` | Yes | Reserved: sunshine, admin, staff, bakery, ronald, system, moderator, support |
| `display_name` | Mutable, 1–24 chars, not an email | Yes | Default first name or “Sunshine Guest” — never billing name/email |
| `square_customer_id` | Commerce id | **No** | Private; linking only |
| email / phone / session | Mutable | **No** | Client stores session in `user://` only |

Public profile payload:

```json
{
  "player_id": "plr_…",
  "username": "ada_walk",
  "display_name": "Ada",
  "avatar": { "v": 1, "skin": "peach", "hair": "bangs", "hair_color": "brown", "outfit": "blush", "apron": "grey", "hat": "sun", "accessory": "glasses" },
  "displays": []
}
```

Private account also has Square session, orders, phone, email. Game replication may only send the public object.

## 2. Avatar recipe

Approved option IDs only (no uploads this release). Version `v: 1`. Unknown IDs clamp to defaults.

Skin: fair, peach, tan, deep, rich  
Hair: bangs, wavy, short, bun, none  
Hair color: brown, wine, black, honey, cream  
Outfit: blush, wine, cream, apricot  
Apron: none, grey, blush, wine  
Hat: none, sun, beanie, bow  
Accessory: none, glasses, flower, scarf

Unlocks: none yet (all listed IDs are free). Persistence: `user://profile_vault.json` keyed by `square_customer_id`, plus GameSave. Cloud: `GET/PUT/POST/PATCH /order/api/account/avatar` (Bearer) → Square custom attribute `sunshine_avatar`. **Live** on bakery-drinks (`bakery-drinks-00021-ghm`). Local vault is the offline cache.

## 3. Catalog IDs

| Field | Source |
| --- | --- |
| `item_id` | Square ITEM id (`item_id` on drinks) |
| `variation_id` | Square ITEM_VARIATION (`id` / `catalog_object_id`) |
| `canonical_name` | `square_name` or customer-facing `name` |
| `aliases` | `assets/generated/menu/square_photos.json` |
| `asset_id` / `asset_version` | 3D mapping; empty until a real mesh exists (neutral fallback, never a wrong pastry) |

Location for inventory: `L4CK6YWGT5XQX`.

## 4. Purchase display entitlement (not live)

```
player_id, variation_id, source_order_id, status (pending|granted|revoked), processing_version
```

Order amounts, addresses, emails stay private. Default public displays **off**.

## 5. Room / protocol

- Protocol version `1`. Room cap **16**.
- Native Android transport: **ENet** (Godot high-level multiplayer). Web export is not a current target; if a browser client is added later, add a WebSocket relay — do not assume UDP works in HTML5.
- Join ticket: short-lived, room-scoped, single-use, bound to authenticated `player_id`. Client-supplied player IDs are rejected.
- Messages: `move` (seq, wish, yaw, jump), `throw` (seq, origin, dir, item_id=`practice_cookie`), `impact` (projectile_id, pos), `chat`, `report`.
- Authority: dedicated/headless server (not a phone host). Client may predict movement/throw visuals; hits and entitlements are server-side.
- Persistent vs room-local: identity/avatar/blocks persist; positions/projectiles are room-local and die with the room.

## 6. Chat / moderation (not live)

Room text only. Server validates membership and stamps author from the session. Max 180 chars. Rate limit TBD (start 4 / 6s). Banned-word list with Unicode fold. Mute/block/report persist. Block hides chat, not the whole public profile, unless later specified.

## 7. API auth

- HTTPS bakery-drinks. `Authorization: Bearer <session_token>` (and `X-Session-Token`).
- Structured errors: `{ "ok": false, "error_code", "error", "retryable" }`.
- Idempotency: cart replacement uses a monotonic `request_seq`; stale responses are ignored.
- Schema ownership: COS integrator owns contract version bumps. bakery-drinks owns Square customer/order schemas.

## 8. Cost / hosting

No new paid service in this milestone. Avatar store is a JSON file next to bakery-drinks if applied. Stay inside the bakery GCP ~$15/mo cap. Dedicated game VM is a **future owner approval** (staging first).
