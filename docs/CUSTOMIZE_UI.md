# Customize look — design notes (0.1.89 test branch)

Locked: the A1 head mesh is unchanged. Chrome colors are blush `#e8b4b8`, wine `#722F37`, and cream `#FFF8F0`.

The screen is still `scenes/explore/customize.tscn`. Smoke still finds Save and Username, and the script still contains the slot names "Bottoms" and "Pants". Visible labels are Top color, Bottom style, and Pants color.

## Layout

- **One intro line.** "Pick a slot, then a piece." Display name and username sit behind **Edit profile** so the picker can use that space. Guests are not mentioned on this card.
- **Preview.** The baker is framed to about 80% of the portrait height (tap the portrait for a closer look, tap again to step back). Loyalty keeps the wider camera.
- **Slots stay put.** Skin, hair, hair color, top color, bottom style, pants color, apron, hat, and accessory are a 3-column chip grid outside the scroller. The open slot's pieces start at the top of the scroller, so Skin is on screen without scrolling past the chips. Apron, hat, and accessory stay in that fixed grid instead of being clipped inside the scroll.
- **Pants color** shows in the chip grid only when bottom style is pants.
- **Color vs selection.** Skin, hair color, top color, pants color, and apron use the real swatch as the button fill. The selected piece gets a wine outline and a check. The blush fill is not mixed into the color.
- **Thumbnails.** Hair, hat, and accessory buttons draw a small glyph above the name.
- **Footer.** Save is the only primary button. Edit profile, Explore 3D, and Menu are flat, with no drop shadow. Choice and chip shadows are flat too.

## Save

The status well above the footer has a fixed height, so the banner cannot push Explore 3D off the screen. There is one line of copy (the old banner repeated the same sentence).

- **Unsaved** after a change
- **Saving…** while the account write is in flight
- **Saved to account** when the bakery accepts it
- **Saved on this phone. Account sync pending.** plus **Retry** when the phone has the look but the account did not answer

Leaving with unsaved changes asks **Save**, **Discard**, or **Keep editing**. A clean look goes straight to Explore or the menu.

## Touch size

The project canvas is 720×1280. On a phone about 360dp wide, 48dp is 96 canvas pixels, and every button and text field on this screen is at least that tall. If the device dpi makes 48dp larger than 96 canvas pixels, the floor grows. `touch_targets_ok()` checks that floor. This VM is not a handset; the check is the same scale the stretch mode uses on device.

Screenshots: `docs/screenshots/customize-review/`.
