# Review cameras (screenshot feedback)

Explore 3D mounts eight fixed `Camera3D` markers under `ReviewCameras`.
They are **not** current during play (the player camera stays in control).

| Name | Shot |
| --- | --- |
| `Entrance` | Hero spawn: south lawn looking −Z at the patio and Sunshine logo wall |
| `Counter` | Bistro seating looking toward the center table |
| `Dining` | South edge of the patio looking at the tables |
| `LeftCorner` | East picnic / cornhole |
| `RightCorner` | West picnic / menu board |
| `SunshineCloseup` | Logo_Hero on the north logo wall |
| `PastryCase` | Chalk menu board at the south-west corner |
| `Exterior` | Wide field: 90×80 m grass + patio |

## Capture PNGs (CLI)

From the project root, with Godot 4.3+ on your PATH:

```bash
godot --path . --rendering-method gl_compatibility --resolution 1280x720 -s res://tools/capture_shop.gd
```

That plays `explore_3d.tscn`, hides the HUD, makes each review camera current,
and writes:

- `export/review/photo_hero.png` (Entrance / storefront-photo match)
- `export/review/Entrance.png` … `Exterior.png`
- `export/review/shop_spawn.png`

Headless / cloud GPUs often save a **clear-color or black** frame. If the PNGs
look empty, capture with a display (`DISPLAY=:1`). The camera nodes are
still valid either way.

Compare the hero to the reference photo:

```bash
python3 tools/compose_still_compare.py
```

That writes `compare_hero.png` next to `assets/reference/storefront-hero.jpg`.
