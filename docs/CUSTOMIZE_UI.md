# Customize look — design notes (0.1.89 test branch)

Locked: the A1 head mesh is unchanged. Colors used for the new chrome are blush `#e8b4b8`, wine `#722F37`, and cream `#FFF8F0`.

The screen is still one scene (`scenes/explore/customize.tscn`): title, portrait, names, slot picker, save. Smoke still finds Save, Username, Bottoms, and Pants, and `_pick` / `_on_save` behave the same.

## What changed

- **Portrait frame.** The baker sits in a cream panel with a 4 px blush border instead of a bare viewport on the storefront photo. Portrait height is 240 px so the slot picker can share the phone without shrinking the head mesh.
- **One slot at a time.** Skin, hair, hair color, outfit, bottoms, pants, apron, hat, and accessory are chips in a 3-column grid (64 px tall). The open slot’s pieces are a 2- or 3-column grid of 72 px buttons. The old layout put every option in one horizontal row, so labels ran off the card.
- **Selected state.** The active chip and the active piece use a blush fill and a wine border. Other pieces stay cream with a blush border. Skin, hair color, outfit, pants, and apron tints mix a little of the real swatch into the button so color choices read before you tap.
- **Spacing.** Card padding and the column gap are larger (about 14–20 px). Body type stays on the bakery sizes (captions 24, body 26) so the labels stay readable.
- **Save confirm.** Saving fills a blush banner (`SaveConfirm`) and the existing status line. Copy is unchanged: “Look saved on your Sunshine account.” or the phone-only fallback when the bakery does not answer. There is no second modal.

Screenshots for review live under `/opt/cursor/artifacts/screenshots/customize-before/` (previous layout) and `/opt/cursor/artifacts/screenshots/customize-review/` (this layout).
