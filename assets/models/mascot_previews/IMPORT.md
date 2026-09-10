# Sunshine Logo Girl — Godot Import (v31)

## Files
- `sunshine_logo_girl.glb` — primary
- `sunshine_logo_girl.gltf` + `.bin`, `.blend`
- `preview_front.png` / `preview_threequarter.png`

## Polycount
- **29964** tris, **15289** verts

## v31 — CRITICAL regression fix (restore v29 face + graft v30 hat/flower)
1. **FACE RESTORED (v29):** open round anime eyes + thin wire glasses + layered side-swept bangs + tiny beauty mark + small smile + two Peter Pan lobes
2. **Hat (from v30):** broader floppy straw brim + single solid black band
3. **Sunflower:** enlarged vs v30, warmer orange-yellow petals + darker brown center, physically overlapping viewer-right brim/band/crown
4. **Side hair:** lightly narrowed vs bulky columns; body/apron kept from v29

## Rebuild
```bash
blender --background --python /workspace/sunshine-mascot/build_mascot.py
```

## Scale (Explore / Godot) — updated 2026-09-10
- **Root height ≈ 1.5 m** (feet at Z=0, top of hat ≈ 1.5 m).
- Blender units = meters. glTF export Y-up.
- Prior greeter bug: unscaled export was ~4.76 m tall (~4 m in Explore). Re-exported with scale factor applied; verified reimport height **1.5000 m**.
- If Explore still looks wrong, check scene scale / parent Node3D scale (should be 1,1,1).
- Look: **v31** (ChatGPT 87% clear) — scale-only change, no art change.
