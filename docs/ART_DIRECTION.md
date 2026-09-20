# Art direction — non-blocky cute bakery world

Derived from the live app + brand marks, not a PUBG clone and not a new IP.

## Brand facts

- Circular logo girl: round glasses, shiny black eyes, beauty mark, dark wavy hair, yellow-orange sun hat + sunflower, pink top, red collar, grey apron (`assets/branding/sunshine-logo-girl.jpg`).
- Colors: blush `#e8b4b8`, wine `#4a1c28` / `#6b2d3c`, cream `#fff6ea`, gold/apricot `#e3922e`.
- Place: 2231 1st Ave S, Irondale — pink-trim shop, lawn, picnic tables. Menu uses the **real storefront photo**. Explore uses Ronald’s outdoor eating patio GLB.

## Direction (replace Minecraft/block read)

1. **Rounded silhouettes** — capsules and spheres for people (already true of `patio_npc.gd` and the new `avatar_body.gd`). No cube people.
2. **Cohesive materials** — warm pastry albedo, soft roughness 0.5–0.7, no PBR chrome, no realistic terrain mixed with voxel props.
3. **Keep landmarks** — logo wall, picnic/bistro set, cornhole, 90×80 grass. When the map grows to ~180×160, add pastry garden, picnic lawn, market path, cookie practice — do not scale the character 4×.
4. **Cute third-person** — readable mobile silhouette, orbit camera, visible throw from the hand. “Cute PUBG” is camera/feel only.
5. **Products** — 3D pastries from verified Square/website names. Missing mesh = marked neutral fallback, never a wrong pastry under a real name.

## Current vs target

| Now | Target |
| --- | --- |
| Patio GLB furniture was faceted boxes | Hide those meshes; `cute_pack.gd` drops rounded tables, planters, lamps, hedges. Logo wall + grass stay authored |
| Grass is a flat 90×80 slab | Same footprint first; sculpt paths later |
| Player was an invisible capsule | Rounded customizable chibi (shipped this milestone) |
| Cookie from camera | Cookie on hand socket, released on toss (shipped visual; animation events still open) |

## Map 4× plan (not built)

Baseline accessible area ≈ 90 × 80 m = 7200 m². Target ≈ 2× width and 2× depth → ~180 × 160 m = 28800 m². Do **not** multiply both axes by 4.

Phases: (1) keep patio island, (2) expand south lawn + east garden, (3) north practice range + wayfinding back to the logo wall, (4) collision/camera pass.

## Comparison views

Use existing `ReviewCameras` (Entrance, Counter, Dining, LeftCorner, RightCorner, SunshineCloseup, PastryCase, Exterior) under matched lighting. New player cameras: front, three-quarter, gameplay. Not captured in this cloud image without Godot.
