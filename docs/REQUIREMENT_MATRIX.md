# Requirement-to-task matrix

Statuses: ready / in-progress / blocked / review / done. Evidence is what exists in this branch, not a production claim.

| ID | Requirement | Owner | Deps | Acceptance | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| M0-1 | Baseline audit | Repo/arch | — | Current app recorded | `docs/BASELINE_M0.md` | done |
| M0-2 | Architecture + contracts | COS | M0-1 | Contracts agreed | `docs/ARCHITECTURE.md`, `docs/COS_CONTRACTS.md`, `scripts/contracts/cos_contracts.gd` | done |
| A1 | Signup-gated customize | Avatar | M0-2 | Guest cannot save a look; signed-in can | `customize.tscn`, main-menu CUSTOMIZE LOOK, login → customize if unset | done |
| A2 | Forever appearance save | Identity | A1 | Survives logout; bound to Square customer | Client GET/PUT `/order/api/account/avatar`; drinks patch on bakery-local; **Cloud Run not redeployed (no GCP creds)** | partial (code ready) |
| A3 | Visible rounded avatar + hand toss | Avatar | A1 | Third-person body; cookie leaves hand | `avatar_body.gd`, `player.gd` | partial (no animation events / no 2-client sync) |
| O1 | Cart replacement | Catalog + client | — | Reorder replaces cart; failure preserves | `OrderClient.replace_cart_from_order`, `tools/test_cos_commerce.py` | done (client); checkout still Square |
| O2 | Inventory-only shopping | Catalog + client | O1 | Hide untracked/unknown/zero/sold-out; drinks without counts use provider flags | `is_purchase_eligible`, `shop_drinks`, search | partial (drinks has no ATS yet) |
| T1 | Tip polish §11 | Tip UI | — | Centered, first sentence, no AdMob text, no count, send works | Unchanged `tip_screen.gd` / `tip_ad.tscn` from 0.1.50 | done |
| C1 | 3D catalog products | Product 3D | M0-2 | ≥20 verified named assets | 10 top-seller props + photo map; rest outstanding | partial |
| G1 | Purchase link + displays | Catalog | C1, E | Synthetic grant once; private orders | Contracts only | ready |
| D1 | Dedicated multiplayer | Gameplay/net | M0-2 | Two devices, rooms, tickets | Contracts + architecture | ready |
| D2 | Cookie throw sync | Gameplay/net | D1, A3 | Same projectile both sides | Not started | ready |
| B1 | 4× map | Art/world | M0-1 | Measured ~4× area | Plan in ART_DIRECTION; patio still 90×80 | ready |
| H1 | Room chat + moderation | Social | D1 | Server filter, mute/block/report | Contracts only | ready |
| E1 | Managed auth beyond phone | Identity | — | Password recovery / MFA admin | Phone+Square remains; no new vendor | blocked (need owner if replacing Square phone) |
| I1 | Staging deploy + APK | Infra | A1,O1 | Installable debug APK | 0.1.51 APK built locally (142M). No public GitHub URL (`gh` read-only). CoS can publish | partial |
| Q1 | Automated eligibility/reorder | QA | O1 | Pack §10 cases | `tools/test_cos_commerce.py`, feature_smoke slice | done |
| Q2 | Physical device / 2-network MP | QA | D1 | Do not fabricate | Not available here | untested |

## Next milestones (honest)

1. **Multiplayer server** — headless Godot, join tickets on bakery-drinks, ENet, 16 cap, staging only.
2. **Cookie throw animation sync** — hand release event, projectile id, impact dedupe.
3. **4× map** — 180×160 m expansion with bakery-themed rooms, same human scale.
4. **Chat** — room text + server filter + report queue.
5. **Catalog 3D products** — next verified batch beyond the 10 top sellers; never invent names.
6. **Purchase display linking** — Square-proven account link, entitlement ledger, opt-in shelf.

## Owner approvals needed

- **Redeploy bakery-drinks** from bakery-local avatar branch (this agent cannot: no GCP ADC). Monthly add **$0**.
- InventoryCounts still optional / not added.
- Dedicated game VM still **not** approved to turn on (see `docs/ROOM_SERVER.md`).
- Public 0.1.51+ APK URL: CoS GitHub release (agent `gh` is read-only).
- No Play upload (Cursor only).
