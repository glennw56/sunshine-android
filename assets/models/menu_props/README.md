# Menu props (Explore 3D)

Drop **Godot 4 .glb** files here. Explore instances every real mesh (root not
`PLACEHOLDER_*`) onto the outdoor eating patio — tables, seating, and the
south lawn. These are **walkable map items**, not the Order screen.

3D Models should texture each prop from real Sunshine photos (Square catalog
and `assets/generated/menu/`), not invented fantasy food.

## Filenames (matched to table slots)

| File | Slot |
| --- | --- |
| `croissant.glb` | West picnic table |
| `croissant_cookie.glb` | East picnic table |
| `roll.glb` | North picnic table |
| `croissant_almond.glb` | SW bistro |
| `savory.glb` | SE bistro |
| `loaf.glb` | NW bistro |
| `croissant_berry.glb` | NE bistro |
| `coffee.glb` | Center bistro (offset off the spawn walk) |
| `biscoff.glb` | Beside the chalk menu board |
| `fruit_tea.glb` | Ground near cornhole |

Extra `*.glb` files that do not match a slot still spawn on the south lawn.

Until a matching GLB is present, Explore shows a photo standee of the real
bakery shot on a small plate so the patio is not empty.

Units: meters, Y-up, identity attach.
