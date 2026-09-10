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

`assets/branding/sunshine-bakery-exterior-2231.jpg` documents the real shop at
2231 1st Ave S: white horizontal siding, pink trim, two pink-framed windows,
circular girl logo above a wide orange **SUNSHINE’S BAKERY** sign, picnic
tables on the lawn, stacked **2231**. The 3D exterior is a low-poly
reconstruction of that photo (clapboard, trim, windows, signs, tables).

## Backyard photo / layout

`assets/branding/sunshine-bakery-backyard-good.jpg` is the **primary** rear-yard
reference: open grass, dark picnic tables, wood fence, trees, white+pink
building corner, deck with lattice. Prefer this over any construction or
mess backyard shot. Explore 3D rebuilds that yard behind the shop.

## Procedural 3D textures

`assets/generated/*.png` are code-made (`tools/gen_assets.py`), including
`siding.png` (white clapboard) and `pink_trim.png`.

## Runtime catalog photos

ORDER loads Square item photos from the live `/order/api/menu` JSON (`photo` URLs). Those bytes are not stored in git.

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
