# Optional GLB drop-ins

Explore 3D is procedural until you drop **real** glTF Binary files here
(Godot 4 imports `.glb` as a PackedScene). Filenames must match exactly:

| File | Replaces |
| --- | --- |
| `sunshine_logo_girl.glb` | Walk-up 3D chibi on the front lawn |
| `sunshine_shop_exterior.glb` | Hollow shop shell + facade (lot/street stay) |
| `sunshine_interior.glb` | Indoor stub (counter, pastry case, standing area) |
| `sunshine_backyard.glb` | Rear yard tables, fence, trees, lattice deck |

## How to drop in

1. Export from Blender (or similar) as **glTF Binary (.glb)**.
2. Units: **meters**. Origin at the storefront door on the ground. Front of the shop faces **−Z** (player walks **+Z** into the shop).
3. Overwrite the matching filename in this folder (keep the name).
4. Reopen the project in Godot 4.3+ so it reimports. Play **EXPLORE 3D**.

Placeholder `.glb` files in git are locators only (root node `PLACEHOLDER_*`, no mesh). `ImportedModels` ignores those and keeps the low-poly stand-in. A real export whose root node is **not** named `PLACEHOLDER…` is instanced and the matching procedural chunk is skipped.

Do not commit paid/store meshes. Keep the circular girl on-model with `assets/branding/sunshine-logo-girl.jpg` (not a sun-face).

Regenerate stubs: `python3 tools/gen_model_stubs.py`

## Current girl mascot (v31)

`sunshine_logo_girl.glb` is the cleared ChatGPT-likeness FOSS model (~30k tris). Previews: `mascot_previews/`. Explore uses it via `ImportedModels` (root is `SunshineLogoGirl`, not `PLACEHOLDER_*`). Standing height is meter-authored (~1.5m; Hat world Y ≈1.35) — do not apply extra attach scale.
