extends Object
class_name StorefrontPhoto
## Full-bleed 2231 lawn storefront photo for login + main menu.
## Do not swap this for ChatGPT / voxel concept art — those are Explore reference only.
## Current hero is a 9:16 portrait (1152×2048). Landscape fallbacks keep a phone-width slice.

const HERO := "res://assets/branding/storefront-hero.jpg"
const _PHONE_ASPECT := 9.0 / 16.0


static func apply(photo: TextureRect) -> void:
	if photo == null:
		return
	var src := load(HERO) as Texture2D
	if src == null:
		return
	var size := src.get_size()
	var region := _logo_region(size)
	if region.position == Vector2.ZERO and region.size == size:
		photo.texture = src
	else:
		var atlas := AtlasTexture.new()
		atlas.atlas = src
		atlas.region = region
		atlas.filter_clip = true
		photo.texture = atlas
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _logo_region(size: Vector2) -> Rect2:
	if size.x <= 1.0 or size.y <= 1.0:
		return Rect2(Vector2.ZERO, size)
	# Portrait (or already 9:16) — show the whole lawn photo, logo included.
	if size.y >= size.x:
		return Rect2(Vector2.ZERO, size)
	var slice_w := size.y * _PHONE_ASPECT
	if slice_w > size.x:
		return Rect2(Vector2.ZERO, size)
	# Landscape leftover: center the slice so the facade/logo stay in frame.
	var left := (size.x - slice_w) * 0.5
	return Rect2(left, 0.0, slice_w, size.y)
