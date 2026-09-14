extends Object
class_name StorefrontPhoto
## Portrait crop of the real 2231 storefront photo so the circular logo stays on-screen.
## Do not swap this for ChatGPT / voxel concept art — those are Explore reference only.
## The hero is 4:3 landscape; a centered COVER crop clips the left of the ring.

const HERO := "res://assets/branding/storefront-hero.jpg"
## Pixel origin of storefront-hero.jpg (1600×1200). Scale if the file is replaced.
const _REF_W := 1600.0
const _REF_H := 1200.0
const _CROP_LEFT := 280.0
const _PHONE_ASPECT := 9.0 / 16.0


static func apply(photo: TextureRect) -> void:
	if photo == null:
		return
	var src := load(HERO) as Texture2D
	if src == null:
		return
	var size := src.get_size()
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = _logo_region(size)
	atlas.filter_clip = true
	photo.texture = atlas
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _logo_region(size: Vector2) -> Rect2:
	if size.x <= 1.0 or size.y <= 1.0:
		return Rect2(Vector2.ZERO, size)
	var left := size.x * (_CROP_LEFT / _REF_W)
	var slice_w := size.y * _PHONE_ASPECT
	if slice_w > size.x:
		slice_w = size.x
		left = 0.0
	left = clampf(left, 0.0, size.x - slice_w)
	return Rect2(left, 0.0, slice_w, size.y)
