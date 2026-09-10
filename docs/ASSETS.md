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

## Procedural 3D textures

`assets/generated/*.png` are code-made (`tools/gen_assets.py`), including
`siding.png` (white clapboard) and `pink_trim.png`.

## Runtime catalog photos

ORDER loads Square item photos from the live `/order/api/menu` JSON (`photo` URLs). Those bytes are not stored in git.

## Later interior photo swap

Drop a ≤1-year interior shot in `assets/reference/` and set
`BakeryWorld.INTERIOR_PHOTO`. Keep `sunshine-logo-girl.jpg` as the mascot.
