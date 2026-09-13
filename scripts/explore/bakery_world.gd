extends Node3D
class_name BakeryWorld
## Voxel remake of the 2231 storefront photo (one hero shot).
## Facing +Z, screen-right is world -X (player yaw 180). Layout matches the photo.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"
const TEX_GRASS := "res://assets/foss/grass.jpg"
const TEX_WOOD := "res://assets/foss/wood.jpg"
const TEX_ASPHALT := "res://assets/foss/asphalt.jpg"
const TEX_CONCRETE := "res://assets/foss/concrete.jpg"
const TEX_PLASTER := "res://assets/foss/plaster.jpg"
const TEX_BARK := "res://assets/foss/bark.jpg"
const TEX_ROOF := "res://assets/foss/roof.jpg"
const TEX_METAL := "res://assets/foss/metal.jpg"

const WHITE := Color("f7f5f0")
const SIDING := Color("ece9e2")
const PINK := Color("e8b4b8")
const PINK_BRIGHT := Color("f4b8be")
const WINE := Color("6b2d3c")
const ORANGE := Color("e89a3c")
const GRASS := Color("4f9c38")
const DIRT := Color("6a4a28")
const CONCRETE := Color("d4d0c8")
const SIDEWALK := Color("c8c4b8")
const WOOD := Color("e2c48a")
const WOOD_DK := Color("c8a86a")
const GREEN := Color("6fbf4e")
const GREEN_STRIPE := Color("5eaa40")
const SHINGLE := Color("3a3632")
const LEAF := Color("2a5e28")
const LEAF_DK := Color("1e4a1c")
const BARK := Color("3a2416")
const BLACK := Color("1a1a1c")
const CHAR := Color("3c3c40")
const GLASS := Color("5a7a86")
const GLASS_DK := Color("2a3438")
const TRASH := Color("8a8e92")
const PICNIC := Color("b8bcc0")
const NEON_OPEN := Color("7cff9a")
const ROBE_BROWN := Color("8b5a2b")
const ROBE_GREEN := Color("3d6b32")
const ROBE_WINE := Color("6b2d3c")

var _player: PlayerExplorer
var _front_z: float = 1.15
var _shop_w: float = 8.15
var _shop_h: float = 7.7
var _shop_d: float = 5.2
var _wall: float = 0.32
var _deck_y: float = 1.08


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_ground()
	_build_front_yard()
	_build_bakery()
	_build_green_cottage()
	_build_deck()
	_build_trees()
	_build_staff()
	_spawn_collectibles()


func _mat(c: Color) -> StandardMaterial3D:
	return VoxelKit.flat(c)


func _tex(path: String, color: Color = Color.WHITE, uv: float = 2.0) -> StandardMaterial3D:
	return VoxelKit.tex(path, color, uv)


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_y: float = 0.0, rot_x: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _mat(color), collide, rot_y, rot_x)


func _tbox(size: Vector3, pos: Vector3, path: String, color: Color = Color.WHITE, uv: float = 2.0, collide: bool = true, rot_y: float = 0.0, rot_x: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _tex(path, color, uv), collide, rot_y, rot_x)


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	return VoxelKit.add_sign(self, text, pos, font_size, color, rot_y_deg)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4e9ad8")
	sky_mat.sky_horizon_color = Color("c8dff0")
	sky_mat.ground_bottom_color = Color("2f4a22")
	sky_mat.ground_horizon_color = Color("7a9158")
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	we.background_mode = Environment.BG_SKY
	we.sky = sky
	we.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	we.ambient_light_energy = 0.38
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.tonemap_exposure = 0.92
	we.ssao_enabled = false
	we.glow_enabled = false
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, 28, 0)
	sun.light_color = Color("fff1d2")
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)


func _build_ground() -> void:
	_tbox(Vector3(52, 0.5, 44), Vector3(0.2, -0.25, 2), TEX_GRASS, Color.WHITE, 16.0)
	_tbox(Vector3(52, 0.3, 44), Vector3(0.2, -0.7, 2), TEX_CONCRETE, Color("8a6a48"), 8.0, false)
	_tbox(Vector3(24, 0.1, 3.6), Vector3(0.1, 0.05, -13.7), TEX_ASPHALT, Color.WHITE, 5.0, false)
	_tbox(Vector3(22, 0.1, 1.9), Vector3(0.1, 0.06, -11.4), TEX_CONCRETE, Color.WHITE, 4.0, false)
	_tbox(Vector3(1.05, 0.05, 0.48), Vector3(0.05, 0.12, -11.35), TEX_METAL, Color("3a3a3e"), 1.0, false)
	_tbox(Vector3(1.22, 0.1, 10.4), Vector3(0.02, 0.06, -5.25), TEX_CONCRETE, Color.WHITE, 3.0, false)


func _build_front_yard() -> void:
	# Screen-left = world +X. Photo: table left of walk, table right of walk, third further left.
	_picnic(Vector3(2.85, 0, -3.45))
	_picnic(Vector3(-2.35, 0, -3.35))
	_picnic(Vector3(5.45, 0, -5.05))
	_trash(Vector3(0.02, 0, -1.05))
	_mailbox(Vector3(-3.65, 0, -7.55))
	# White SUV peeking far screen-left (world +X).
	_tbox(Vector3(1.9, 0.7, 0.95), Vector3(8.05, 0.52, -6.15), TEX_METAL, Color("f2f2f0"), 1.2, false)
	_tbox(Vector3(0.28, 0.26, 0.12), Vector3(8.75, 0.36, -6.15), TEX_METAL, Color("1a1a1c"), 0.6, false)
	_tbox(Vector3(0.28, 0.26, 0.12), Vector3(7.35, 0.36, -6.15), TEX_METAL, Color("1a1a1c"), 0.6, false)


func _picnic(pos: Vector3) -> void:
	_tbox(Vector3(1.95, 0.07, 0.78), pos + Vector3(0, 0.76, 0), TEX_CONCRETE, Color("d0d2d4"), 1.4, false)
	_tbox(Vector3(0.07, 0.72, 0.07), pos + Vector3(0, 0.36, 0), TEX_METAL, Color("2a2a2c"), 0.8, false)
	_tbox(Vector3(1.72, 0.06, 0.24), pos + Vector3(0, 0.44, -0.66), TEX_CONCRETE, Color("d0d2d4"), 1.2, false)
	_tbox(Vector3(1.72, 0.06, 0.24), pos + Vector3(0, 0.44, 0.66), TEX_CONCRETE, Color("d0d2d4"), 1.2, false)


func _trash(pos: Vector3) -> void:
	_tbox(Vector3(0.4, 0.9, 0.4), pos + Vector3(0, 0.47, 0), TEX_METAL, Color("9aa0a4"), 1.0, false)
	_tbox(Vector3(0.44, 0.07, 0.44), pos + Vector3(0, 0.92, 0), TEX_METAL, Color("6a6e72"), 0.8, false)


func _mailbox(pos: Vector3) -> void:
	_tbox(Vector3(0.2, 1.18, 0.18), pos + Vector3(0, 0.59, 0), TEX_METAL, Color("1c1c1e"), 0.8)
	_tbox(Vector3(0.16, 0.12, 0.14), pos + Vector3(0, 0.06, 0), TEX_METAL, Color("1c1c1e"), 0.6, false)
	_tbox(Vector3(0.58, 0.16, 0.12), pos + Vector3(-0.08, 0.78, 0), TEX_METAL, Color("1c1c1e"), 0.6, false)
	_tbox(Vector3(0.62, 0.56, 0.4), pos + Vector3(0, 1.32, 0), TEX_METAL, Color("1c1c1e"), 0.9)
	_tbox(Vector3(0.5, 0.1, 0.32), pos + Vector3(0, 1.62, 0), TEX_METAL, Color("1c1c1e"), 0.6, false)


func _build_bakery() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := fz + d
	var cz := fz + d * 0.5
	var cx := 0.0
	_tbox(Vector3(w, h, t), Vector3(cx, h * 0.5, fz + t * 0.5), TEX_PLASTER, Color("f4f1ea"), 2.6)
	_tbox(Vector3(t, h, d), Vector3(cx - w * 0.5 + t * 0.5, h * 0.5, cz), TEX_PLASTER, Color("f4f1ea"), 2.6)
	# Walk-in hole on screen-left side wall (world +X), not in the hero.
	_tbox(Vector3(t, h, 1.85), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, fz + 0.95), TEX_PLASTER, Color("f4f1ea"), 2.2)
	_tbox(Vector3(t, h, 1.55), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, rz - 0.8), TEX_PLASTER, Color("f4f1ea"), 2.2)
	_tbox(Vector3(t, 2.55, 1.35), Vector3(cx + w * 0.5 - t * 0.5, h - 1.25, cz + 0.15), TEX_PLASTER, Color("f4f1ea"), 2.0)
	_tbox(Vector3(w, h, t), Vector3(cx, h * 0.5, rz - t * 0.5), TEX_PLASTER, Color("f4f1ea"), 2.6)
	_box(Vector3(0.08, 2.2, 1.05), Vector3(cx + w * 0.5 + 0.02, 1.12, cz + 0.15), Color("3a3a3e"), false)
	for i in 18:
		var y := 0.26 + i * 0.41
		if y >= h - 0.2:
			break
		_tbox(Vector3(w - 0.08, 0.05, 0.04), Vector3(cx, y, fz - 0.02), TEX_PLASTER, SIDING, 6.0, false)
	# Thick bright pink soffit so the eave reads from the sidewalk.
	_box(Vector3(w + 0.42, 0.28, 0.42), Vector3(cx, h + 0.08, fz - 0.04), PINK_BRIGHT, false)
	_box(Vector3(0.28, 0.28, d + 0.36), Vector3(cx - w * 0.5 - 0.04, h + 0.08, cz), PINK_BRIGHT, false)
	_box(Vector3(0.28, 0.28, d + 0.36), Vector3(cx + w * 0.5 + 0.04, h + 0.08, cz), PINK_BRIGHT, false)
	_box(Vector3(w + 0.42, 0.28, 0.36), Vector3(cx, h + 0.08, rz + 0.04), PINK_BRIGHT, false)
	_box(Vector3(w + 0.18, 0.12, d + 0.18), Vector3(cx, h + 0.26, cz), WHITE, false)
	_box(Vector3(0.22, h + 0.12, 0.22), Vector3(cx - w * 0.5, h * 0.5, fz), PINK)
	_box(Vector3(0.22, h + 0.12, 0.22), Vector3(cx + w * 0.5, h * 0.5, fz), PINK)
	# Photo: OPEN / Coffee window on the left (world +X), dark window right (world -X).
	_window(Vector3(cx + 1.95, 2.18, fz), false)
	_window(Vector3(cx - 1.85, 2.18, fz), true)
	_sign("OPEN", Vector3(cx + 1.95, 2.16, fz - 0.2), 22, NEON_OPEN, 180)
	_sign("Coffee", Vector3(cx + 2.32, 1.86, fz - 0.18), 13, Color("fff6ea"), 180)
	_sign("Fresh Baked", Vector3(cx + 1.58, 1.86, fz - 0.18), 12, Color("fff6ea"), 180)
	# Vertical 2231 on the photo-right (world -X) of the facade.
	_sign("2", Vector3(cx - 3.38, 2.62, fz - 0.12), 22, Color("4a4a4e"), 180)
	_sign("2", Vector3(cx - 3.38, 2.34, fz - 0.12), 22, Color("4a4a4e"), 180)
	_sign("3", Vector3(cx - 3.38, 2.06, fz - 0.12), 22, Color("4a4a4e"), 180)
	_sign("1", Vector3(cx - 3.38, 1.78, fz - 0.12), 22, Color("4a4a4e"), 180)
	_box(Vector3(4.55, 0.62, 0.12), Vector3(cx, 5.05, fz - 0.1), ORANGE, false)
	_sign("SUNSHINE'S BAKERY", Vector3(cx, 5.07, fz - 0.22), 56, WINE, 180)
	_logo_disc(Vector3(cx, 6.28, fz - 0.16))
	_tbox(Vector3(w - t * 2.4, 0.08, d - 0.9), Vector3(cx, 0.06, cz), TEX_WOOD, Color("e8dfd0"), 3.0, false)
	_tbox(Vector3(2.9, 1.0, 0.7), Vector3(cx, 0.55, rz - 1.15), TEX_WOOD, Color("5a3a22"), 1.6)
	VoxelKit.add_box(self, Vector3(2.6, 0.48, 0.38), Vector3(cx, 1.26, rz - 1.2), VoxelKit.glass(GLASS), false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, 3.35, cz)
	lamp.light_color = Color("ffe4b8")
	lamp.light_energy = 0.85
	lamp.omni_range = 8
	add_child(lamp)


func _logo_disc(pos: Vector3) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load(LOGO_GIRL) as Texture2D
	sprite.pixel_size = 0.00082
	sprite.position = pos
	sprite.rotation_degrees.y = 180
	sprite.shaded = false
	sprite.double_sided = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	add_child(sprite)


func _window(pos: Vector3, dark: bool) -> void:
	_box(Vector3(1.72, 1.38, 0.16), pos + Vector3(0, 0, -0.02), PINK, false)
	VoxelKit.add_box(
		self,
		Vector3(1.38, 1.04, 0.08),
		pos + Vector3(0, 0, -0.1),
		VoxelKit.glass(GLASS_DK if dark else GLASS, dark),
		false
	)


func _build_green_cottage() -> void:
	# Photo-right neighbor (world -X).
	var o := Vector3(-8.25, 0, 1.45)
	_tbox(Vector3(4.7, 2.55, 3.4), o + Vector3(0, 1.28, 0), TEX_PLASTER, GREEN, 2.4)
	for i in 7:
		_tbox(Vector3(4.65, 0.05, 3.35), o + Vector3(0, 0.34 + i * 0.32, 0.04), TEX_PLASTER, GREEN_STRIPE, 3.0, false)
	_tbox(Vector3(5.2, 0.22, 3.85), o + Vector3(0, 2.68, 0), TEX_ROOF, SHINGLE, 2.2)
	_tbox(Vector3(3.4, 0.16, 2.6), o + Vector3(0, 2.88, 0), TEX_ROOF, SHINGLE, 1.6, false)
	_tbox(Vector3(0.7, 0.7, 0.08), o + Vector3(1.05, 1.68, -1.72), TEX_PLASTER, Color("f4f2ea"), 1.0, false)
	VoxelKit.add_box(self, Vector3(0.5, 0.5, 0.06), o + Vector3(1.05, 1.68, -1.78), VoxelKit.glass(GLASS), false)


func _build_deck() -> void:
	# Long wooden accessibility ramp on the photo-right (world -X).
	var rx := -5.55
	_tbox(Vector3(2.2, 0.14, 6.35), Vector3(rx, 0.52, 0.05), TEX_WOOD, WOOD, 3.2, true, 0.0, deg_to_rad(-11.0))
	for i in 12:
		_tbox(Vector3(2.05, 0.04, 0.18), Vector3(rx, 0.16 + i * 0.075, -2.55 + i * 0.44), TEX_WOOD, WOOD_DK, 2.0, false, 0.0, deg_to_rad(-11.0))
	_tbox(Vector3(0.1, 0.98, 6.15), Vector3(rx + 1.12, 0.94, 0.05), TEX_WOOD, WOOD, 2.4, true, 0.0, deg_to_rad(-11.0))
	_tbox(Vector3(0.1, 0.98, 6.15), Vector3(rx - 1.12, 0.94, 0.05), TEX_WOOD, WOOD, 2.4, true, 0.0, deg_to_rad(-11.0))
	_tbox(Vector3(3.35, 0.16, 2.5), Vector3(-7.35, _deck_y, 2.7), TEX_WOOD, WOOD, 2.0)
	_tbox(Vector3(3.25, 0.85, 0.1), Vector3(-7.35, _deck_y + 0.5, 1.48), TEX_WOOD, WOOD, 1.6, false)
	_tbox(Vector3(0.1, 0.85, 2.35), Vector3(-5.75, _deck_y + 0.5, 2.7), TEX_WOOD, WOOD, 1.6, false)


func _build_trees() -> void:
	# Dense canopy behind the lot so the sky reads like the photo.
	var xs := [-13.0, -10.5, -8.0, -5.2, -2.4, 0.4, 3.2, 6.0, 8.8, 11.4]
	for i in xs.size():
		_tree(Vector3(xs[i], 0, 6.6 + float(i % 3) * 0.55), 5.1 + float(i % 4) * 0.35)
	_tree(Vector3(-12.4, 0, 2.4), 4.4)
	_tree(Vector3(10.6, 0, 2.8), 4.2)


func _tree(pos: Vector3, height: float) -> void:
	_tbox(Vector3(0.55, height * 0.45, 0.55), pos + Vector3(0, height * 0.22, 0), TEX_BARK, BARK, 1.4, false)
	_tbox(Vector3(2.7, 2.35, 2.7), pos + Vector3(0, height * 0.64, 0), TEX_GRASS, LEAF, 2.2, false)
	_tbox(Vector3(1.85, 1.5, 1.85), pos + Vector3(0.3, height * 0.9, 0.15), TEX_GRASS, LEAF_DK, 1.8, false)


func _villager(pos: Vector3, robe: Color, rot_y: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	root.add_to_group("village_npc")
	add_child(root)
	VoxelKit.add_box(root, Vector3(0.55, 1.0, 0.34), Vector3(0, 0.72, 0), VoxelKit.flat(robe), false)
	VoxelKit.add_box(root, Vector3(0.46, 0.46, 0.46), Vector3(0, 1.42, 0), VoxelKit.flat(Color("e6c8a0")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(-0.2, 0.28, 0), VoxelKit.flat(Color("3a2416")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(0.2, 0.28, 0), VoxelKit.flat(Color("3a2416")), false)


func _build_staff() -> void:
	_villager(Vector3(-2.4, 0, 3.55), ROBE_BROWN, 2.6)
	_villager(Vector3(1.35, 0, 3.75), ROBE_GREEN, 3.5)
	_villager(Vector3(0.15, 0, 4.55), ROBE_WINE, 3.2)


func _spawn_collectibles() -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector3(-1.15, 0.55, 3.15), "kind": "croissant"},
		{"pos": Vector3(1.05, 0.5, 2.75), "kind": "croissant"},
		{"pos": Vector3(0.15, 0.52, 4.05), "kind": "drink"},
	]
	for row in spots:
		_place_pickup(row["pos"], str(row["kind"]), false)
	if GameSave.is_fresh_batch_active():
		_place_pickup(Vector3(-1.55, 0.55, 4.35), "croissant", true)
		_place_pickup(Vector3(-2.45, 0.55, -6.15), "drink", true)


func _place_pickup(pos: Vector3, kind: String, fresh: bool) -> void:
	var item := CollectiblePickup.new()
	item.kind = kind
	item.is_fresh_batch = fresh
	item.position = pos
	item.collected.connect(_on_collected)
	add_child(item)


func _on_collected(kind: String) -> void:
	var hud := get_tree().get_first_node_in_group("explore_hud")
	if hud and hud.has_method("on_collected"):
		hud.on_collected(kind)
