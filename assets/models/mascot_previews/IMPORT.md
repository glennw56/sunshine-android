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
