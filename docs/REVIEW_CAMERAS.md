# Review cameras (screenshot feedback)

Explore 3D mounts eight fixed `Camera3D` markers under `ReviewCameras`.
They are **not** current during play (the player camera stays in control).

| Name | Shot |
| --- | --- |
| `Entrance` | Hero spawn: street looking −Z at the bakery facade |
| `Counter` | Side porch / ramp looking at the bakery wall |
| `Dining` | Front lawn looking at the bakery |
| `LeftCorner` | Neighbor green house |
| `RightCorner` | Photo-right bakery lawn |
| `SunshineCloseup` | Logo disc + SUNSHINE’S BAKERY sign |
| `PastryCase` | Side porch looking toward the bakery door |
| `Exterior` | Wide lot: bakery + neighbor + street |

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
