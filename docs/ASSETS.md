# Branding assets

## Official circular logo (in-repo)

`assets/branding/sunshine-logo-girl.jpg` is Sunshine’s Bakery’s circular mascot mark:

- Chibi girl, thick black ring, cream sunburst background
- Round black glasses, large shiny black eyes, beauty mark
- Dark brown wavy hair and bangs
- Yellow-orange sun hat, black band, sunflower on the viewer’s right
- Pink top, red collar, grey apron straps
- Orange bar: **SUNSHINE’S BAKERY**

Source: live bakery-drinks brand file
`https://bakery-drinks-k6uuoen7wa-ue.a.run.app/static/order/logo.jpg`
(JPEG 2048², `Last-Modified: Mon, 07 Sep 2026` — well within the ≤1 year photo rule).
Same artwork Ronald attached as the 3D mascot reference.

The 3D shop sign uses this texture. The walkable mascot is a low-poly chibi built to match those features (not a different sun-face).

## Procedural 3D textures

`assets/generated/*.png` are code-made (see `tools/gen_assets.py`). No storefront photographs are committed.

## Runtime catalog photos

ORDER loads Square item photos from the live `/order/api/menu` JSON (`photo` URLs). Those bytes are not stored in git.

## Later photo swap (storefront / interior)

When you have fresh (≤1 year) photos of 2231 1st Ave S:

1. Drop them in `assets/reference/` (create the folder; it is gitignored of secrets, not of images — commit only photos you have rights to).
2. In `scripts/explore/bakery_world.gd`, set `STOREFRONT_PHOTO` / `INTERIOR_PHOTO` to those paths.
3. Keep `sunshine-logo-girl.jpg` as the mascot/sign unless the brand mark itself changes.
