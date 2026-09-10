# Review cameras (screenshot feedback)

Explore 3D mounts eight fixed `Camera3D` markers under `ReviewCameras`.
They are **not** current during play (the player camera stays in control).

| Name | Shot |
| --- | --- |
| `Entrance` | Storefront door from the front lawn |
| `Counter` | Indoor service counter |
| `Dining` | Picnic tables on the front lawn |
| `LeftCorner` | Left building / yard corner |
| `RightCorner` | Right building / yard corner |
| `SunshineCloseup` | Walk-up girl mascot |
| `PastryCase` | Indoor glass pastry case |
| `Exterior` | Wide 2231 facade from the street |

## Capture PNGs (CLI)

From the project root, with Godot 4.3+ on your PATH:

```bash
godot --path . --headless -s res://tools/capture_review.gd
```

That plays `explore_3d.tscn`, hides the HUD, makes each review camera current,
and writes:

- `export/review/Entrance.png` … `Exterior.png` (working copy)
- `user://review/` (Godot user data — same files)

Headless / cloud GPUs often save a **clear-color or black** frame. If the PNGs
look empty, capture in the **editor** instead (below). The camera nodes are
still valid either way.

To copy somewhere else:

```bash
cp export/review/*.png ~/Desktop/sunshine-review/
```

## Capture in the Godot editor

1. Open `scenes/explore/explore_3d.tscn` and press **F6** (play this scene).
2. In the **Remote** scene tree: `Explore / ReviewCameras / Entrance` (etc.).
3. Select a camera, enable **Current** in the inspector for a live preview.
   Turn **Current** off when finished (or stop play) so the player camera returns.
4. Viewport menu: **View → Perspective** is independent; use the camera preview
   pane (bottom-right when a `Camera3D` is selected) or a viewport screenshot.
5. Or run **Editor → Run Script** / the same CLI while the project is open.

`export/review/*.png` is gitignored. Keep this doc; attach PNGs in review comments.
