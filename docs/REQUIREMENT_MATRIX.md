# Requirement-to-task matrix

Statuses: ready / in-progress / blocked / review / done. Evidence is what exists in this branch, not a production claim.

| ID | Requirement | Owner | Deps | Acceptance | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| M0-1 | Baseline audit | Repo/arch | — | Current app recorded | `docs/BASELINE_M0.md` | done |
| M0-2 | Architecture + contracts | COS | M0-1 | Contracts agreed | `docs/ARCHITECTURE.md`, `docs/COS_CONTRACTS.md`, `scripts/contracts/cos_contracts.gd` | done |
| A1 | Signup-gated customize | Avatar | M0-2 | Guest cannot save a look; signed-in can | `customize.tscn`, main-menu CUSTOMIZE LOOK, login → customize if unset | done |
| A2 | Forever appearance save | Identity | A1 | Survives logout; bound to Square customer | Live drinks GET/PUT/POST/PATCH `/order/api/account/avatar` — 401 without Bearer on all four; client drinks-first, no 401 patio fallback; file-store recipe round-trip. Signed-in Square write still needs Ronald’s session | done (needs signed-in phone proof) |
| A3 | Visible rounded avatar + hand toss | Avatar | A1 | Third-person body; cookie leaves hand; feet on ground | `avatar_body.gd` soles at y=0, `player.gd` snap_to_ground, over-shoulder SpringArm, fixed stick + right-half look | done (device visual still needed) |
| O1 | Cart replacement | Catalog + client | — | Reorder replaces cart; failure preserves | `OrderClient.replace_cart_from_order`, `tools/test_cos_commerce.py` | done (client); checkout still Square |
| O2 | Inventory-only shopping | Catalog + client | O1 | Hide untracked/unknown/zero/sold-out; drinks without counts use provider flags | `is_purchase_eligible`, `shop_drinks`, search | partial (drinks has no ATS yet) |
| T1 | Tip polish §11 | Tip UI | — | Centered, first sentence, no AdMob text, no count, send works | Unchanged `tip_screen.gd` / `tip_ad.tscn` from 0.1.50 | done |
| C1 | 3D catalog products | Product 3D | M0-2 | ≥20 verified named assets | 10 top-seller props + photo map; rest outstanding | partial |
| G1 | Purchase link + displays | Catalog | C1, E | Synthetic grant once; private orders | Contracts only | ready |
| D1 | Dedicated multiplayer | Gameplay/net | M0-2 | Two devices, rooms, tickets | Hosted WS patio + tickets; two scripted public clients joined one room. Physical two-phone test outstanding | partial |
| D2 | Cookie throw sync | Gameplay/net | D1, A3 | Same projectile both sides | Server assigns/broadcasts `proj_id`; client skips echo | partial (scripted, not two phones) |
| B1 | 4× map | Art/world | M0-1 | Measured ~4× area | 180×160 walkable lawn around the authored 90×80 patio + garden/picnic/practice/market | partial |
| H1 | Room chat + moderation | Social | D1 | Server filter, mute/block/report | Room chat + banned-term filter live on patio server; mute/block/report queue still thin | partial |
| E1 | Managed auth beyond phone | Identity | — | Password recovery / MFA admin | Phone+Square remains; no new vendor | blocked (need owner if replacing Square phone) |
| I1 | Staging deploy + APK | Infra | A1,O1 | Installable debug APK | 0.1.54 pending export; last public https://github.com/glennw56/sunshine-android/releases/download/v0.1.53-debug/sunshines-bakery-0.1.53-debug.apk | in-progress |
| Q1 | Automated eligibility/reorder | QA | O1 | Pack §10 cases | `tools/test_cos_commerce.py`, feature_smoke slice | done |
| Q2 | Physical device / 2-network MP | QA | D1 | Do not fabricate | Not available here | untested |

## Next milestones (honest)

1. **Persist the patio** on Cloud Run (`sunshine-explore`, min 0 / max 1) so it outlives this agent VM.
2. **Two-phone proof** on different networks against that origin.
3. **Cookie animation-event sync** — hand release timing, impact dedupe on device.
4. **Catalog 3D products** — next verified batch beyond the 10 top sellers.
5. **Purchase display linking** — Square-proven account link, entitlement ledger.
6. **Full mute/block/report queue.**

## Owner approvals needed

- Optional: `gcloud run deploy sunshine-explore` from `server/Dockerfile.explore` (`--min-instances 0 --max-instances 1`). Monthly add **~$0**.
- InventoryCounts still optional / not added.
- Dedicated game VM still **not** started.
- No Play upload (Cursor only).
