# Branding assets

## Official circular logo

`assets/branding/sunshine-logo-girl.jpg` is Sunshine’s Bakery’s circular mascot mark:

- Chibi girl, thick black ring, cream sunburst background
- Round black glasses, large shiny black eyes, beauty mark
- Dark brown wavy hair and bangs
- Yellow-orange sun hat, black band, sunflower on the viewer’s right
- Pink top, red collar, grey apron straps
- Orange bar: **SUNSHINE’S BAKERY**

Source: live bakery-drinks brand file
`https://bakery-drinks-k6uuoen7wa-ue.a.run.app/static/order/logo.jpg`
(JPEG 2048², `Last-Modified: Mon, 07 Sep 2026`).

The Explore 3D facade disc and the walk-up chibi both use this mark. Do not swap in a sun-face.

## Storefront photo / layout

`assets/models/sunshine_outdoor_eating.glb` is the **walkable Explore patio**
(Y-up Blender export: picnic and bistro seating, chairs, planters, cornhole,
Sunshine logo wall, and a 90×80 m grass field). The main menu stays the real
storefront photo. Do not use `chatgpt_shop_grass.glb` as the Explore world.
`assets/models/sunshine_bakery_lot.glb` is the previous walkable bakery lot
(Y-up Blender export: bakery with pink trim + sign/logo textures, neighbor
green house, two porches, ADA ramp, street/sidewalk, front and back yard).
`Sunshines_Bakery_Storefront_Godot4.glb` is a copy of that lot file. Named
copies of earlier photo-card meshes live at
`Sunshines_Bakery_Storefront_Godot4_v4.glb` (v4),
`Sunshines_Bakery_Storefront_Godot4_v3.glb` (v3 trimesh), and
`Sunshines_Bakery_Storefront_Godot4_v2.glb` (untextured denser mesh).
`chatgpt_voxel_1.png` and `chatgpt_voxel_2.png` are 2D stills kept as
reference; they are not the main menu.

Explore table props prefer `.glb` files in `assets/models/menu_props/` (real Sunshine
photos as textures). Empty slots use photo-textured plates from `assets/generated/menu/`
and Square drink JPEGs — not cartoon cup tiles and not a second Order menu.

`assets/branding/storefront-hero.jpg` is the **real** 2231 sidewalk photo used
as the phone-login and main-menu full-bleed background — not the ChatGPT still.

`assets/reference/storefront-hero.jpg` is the same real photo kept as reference.

`assets/branding/sunshine-bakery-exterior-2231.jpg` is an extra branding still
of a similar white/pink box shop (clapboard, trim, windows, sign).

## Backyard photo / layout

`assets/branding/sunshine-bakery-backyard-good.jpg` is the **primary** rear-yard
reference: open grass, dark picnic tables, wood fence, trees, white+pink
building corner, deck with lattice. Prefer this over any construction or
mess backyard shot. Explore 3D rebuilds that yard behind the shop.

## Procedural 3D textures

`assets/generated/*.png` are code-made (`tools/gen_assets.py`), including
`siding.png` (white clapboard) and `pink_trim.png`. ORDER never uses those
FOSS pastry doodles as the product photo.

Explore ground / wood / asphalt / plaster / bark use **CC0 ambientCG** maps
in `assets/foss/` (see `NOTICE.md` there). No paid packs.

## Runtime catalog photos

ORDER product photos come from **Square**:

1. Live bakery-drinks `GET /order/api/menu` `photo` field (Square Catalog S3,
   same as drink photos).
2. Square Online store catalog (`/app/store/api/v28/editor/.../products`) for
   FOOD prices (`price.low_subunits` → `price_cents`) plus commerce-links /
   product `og:image` for names/photos the drinks API does not return.
   Refresh photos: `python3 tools/sync_square_photos.py`
   (writes `assets/generated/menu/square_photos.json`). Optional:
   `SQUARE_ACCESS_TOKEN` for Catalog Search.
3. If Square has no image for that item: `assets/generated/menu/no_photo.png`.

Sold-out rows still show the Square photo, muted.

## Indoor shop (stub)

Explore 3D is walkable **inside** through the storefront door (front wall is a
hollow shell with a center opening — not a solid box). A **left-wall yard door**
opens onto the concrete strip that runs beside the building into the backyard
(path: lawn → door → interior → yard). The interior is a low-poly stub (counter,
glass pastry case, espresso, chalkboard, standing ledge) until an interior photo
is available. Collectibles spawn in that stub **and** on the lawn / backyard.
Set `BakeryWorld.INTERIOR_PHOTO` to a ≤1-year shot in `assets/reference/` when
you have one. Keep `sunshine-logo-girl.jpg` as the mascot.

## Optional GLB models

`assets/models/*.glb` — drop Blender (or other) glTF Binary exports over the
stub filenames. See `assets/models/README.md`. Placeholders in git have a
`PLACEHOLDER_*` root and are not drawn.
