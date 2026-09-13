extends Node3D
class_name BakeryWorld
## Voxel remake of the 2231 storefront photo (one hero shot).
## Front yard + white/pink bakery + green neighbor + wood ramp. Boxes only.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"

const WHITE := Color("f7f5f0")
const SIDING := Color("ece9e2")
const PINK := Color("e8b4b8")
const PINK_BRIGHT := Color("f3c4c8")
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
var _shop_w: float = 8.2
var _shop_h: float = 7.85
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


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_y: float = 0.0, rot_x: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _mat(color), collide, rot_y, rot_x)


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	return VoxelKit.add_sign(self, text, pos, font_size, color, rot_y_deg)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("8ec6ee")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("dcead4")
	we.ambient_light_energy = 0.52
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 22, 0)
	sun.light_color = Color("fff6dc")
	sun.light_energy = 1.22
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	_box(Vector3(52, 0.5, 44), Vector3(1.4, -0.25, 2), GRASS)
	_box(Vector3(52, 0.3, 44), Vector3(1.4, -0.7, 2), DIRT, false)
	# Street + sidewalk (photo camera stands here).
	_box(Vector3(24, 0.1, 3.6), Vector3(0.3, 0.05, -13.55), Color("b0aca4"), false)
	_box(Vector3(22, 0.1, 1.9), Vector3(0.3, 0.06, -11.25), SIDEWALK, false)
	# Storm drain in the curb, foreground center.
	_box(Vector3(1.05, 0.05, 0.48), Vector3(0.12, 0.12, -11.15), CHAR, false)
	# Narrow concrete walk to the facade (trash sits on it).
	_box(Vector3(1.28, 0.1, 10.2), Vector3(0.02, 0.06, -5.15), CONCRETE, false)


func _build_front_yard() -> void:
	# Photo pair flanking the walk, plus a third table on the left lawn.
	_picnic(Vector3(-2.95, 0, -3.45))
	_picnic(Vector3(2.25, 0, -3.35))
	_picnic(Vector3(-5.55, 0, -5.15))
	_trash(Vector3(0.02, 0, -1.05))
	_mailbox(Vector3(5.25, 0, -8.55))
	# White SUV peeking on the far left (photo).
	_box(Vector3(1.9, 0.7, 0.95), Vector3(-8.15, 0.52, -6.15), Color("f2f2f0"), false)
	_box(Vector3(0.28, 0.26, 0.12), Vector3(-8.85, 0.36, -6.15), BLACK, false)
	_box(Vector3(0.28, 0.26, 0.12), Vector3(-7.45, 0.36, -6.15), BLACK, false)


func _picnic(pos: Vector3) -> void:
	_box(Vector3(1.95, 0.07, 0.78), pos + Vector3(0, 0.76, 0), PICNIC, false)
	_box(Vector3(0.07, 0.72, 0.07), pos + Vector3(0, 0.36, 0), CHAR, false)
	_box(Vector3(1.72, 0.06, 0.24), pos + Vector3(0, 0.44, -0.66), PICNIC, false)
	_box(Vector3(1.72, 0.06, 0.24), pos + Vector3(0, 0.44, 0.66), PICNIC, false)


func _trash(pos: Vector3) -> void:
	_box(Vector3(0.4, 0.9, 0.4), pos + Vector3(0, 0.47, 0), TRASH, false)
	_box(Vector3(0.44, 0.07, 0.44), pos + Vector3(0, 0.92, 0), Color("6a6e72"), false)


func _mailbox(pos: Vector3) -> void:
	_box(Vector3(0.2, 1.18, 0.18), pos + Vector3(0, 0.59, 0), BLACK)
	_box(Vector3(0.16, 0.12, 0.14), pos + Vector3(0, 0.06, 0), BLACK, false)
	_box(Vector3(0.58, 0.18, 0.12), pos + Vector3(0.08, 0.78, 0), BLACK, false)
	_box(Vector3(0.62, 0.56, 0.4), pos + Vector3(0, 1.32, 0), BLACK)
	_box(Vector3(0.5, 0.1, 0.32), pos + Vector3(0, 1.62, 0), BLACK, false)


func _build_bakery() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := fz + d
	var cz := fz + d * 0.5
	var cx := 0.0
	# Solid white box — photo has two windows, no front door.
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, fz + t * 0.5), WHITE)
	_box(Vector3(t, h, d), Vector3(cx - w * 0.5 + t * 0.5, h * 0.5, cz), WHITE)
	# Side wall with a walk-in hole on +X (not visible in the hero shot).
	_box(Vector3(t, h, 1.85), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, fz + 0.95), WHITE)
	_box(Vector3(t, h, 1.55), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, rz - 0.8), WHITE)
	_box(Vector3(t, 2.55, 1.35), Vector3(cx + w * 0.5 - t * 0.5, h - 1.25, cz + 0.15), WHITE)
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, rz - t * 0.5), WHITE)
	_box(Vector3(0.08, 2.2, 1.05), Vector3(cx + w * 0.5 + 0.02, 1.12, cz + 0.15), Color("3a3a3e"), false)
	# Horizontal clapboard (photo landmark).
	for i in 18:
		var y := 0.26 + i * 0.42
		if y >= h - 0.18:
			break
		_box(Vector3(w - 0.1, 0.05, 0.04), Vector3(cx, y, fz - 0.02), SIDING, false)
	# Thin bright pink soffit / eave + corner posts (photo).
	_box(Vector3(w + 0.28, 0.16, 0.28), Vector3(cx, h + 0.02, fz - 0.02), PINK_BRIGHT, false)
	_box(Vector3(0.16, 0.16, d + 0.22), Vector3(cx - w * 0.5 - 0.02, h + 0.02, cz), PINK_BRIGHT, false)
	_box(Vector3(0.16, 0.16, d + 0.22), Vector3(cx + w * 0.5 + 0.02, h + 0.02, cz), PINK_BRIGHT, false)
	_box(Vector3(w + 0.28, 0.16, 0.28), Vector3(cx, h + 0.02, rz + 0.02), PINK_BRIGHT, false)
	_box(Vector3(w + 0.2, 0.14, d + 0.2), Vector3(cx, h + 0.14, cz), WHITE, false)
	_box(Vector3(0.18, h + 0.08, 0.18), Vector3(cx - w * 0.5, h * 0.5, fz), PINK)
	_box(Vector3(0.18, h + 0.08, 0.18), Vector3(cx + w * 0.5, h * 0.5, fz), PINK)
	# Two modest pink-framed windows (left OPEN / right dark).
	_window(Vector3(cx - 2.05, 2.12, fz), false)
	_window(Vector3(cx + 1.85, 2.12, fz), true)
	_sign("OPEN", Vector3(cx - 2.05, 2.1, fz - 0.2), 20, NEON_OPEN, 180)
	_sign("Coffee", Vector3(cx - 2.42, 1.82, fz - 0.18), 12, Color("fff6ea"), 180)
	_sign("Fresh Baked", Vector3(cx - 1.68, 1.82, fz - 0.18), 11, Color("fff6ea"), 180)
	# Vertical 2231 on the right of the facade.
	_sign("2", Vector3(cx + 3.42, 2.58, fz - 0.12), 20, Color("4a4a4e"), 180)
	_sign("2", Vector3(cx + 3.42, 2.32, fz - 0.12), 20, Color("4a4a4e"), 180)
	_sign("3", Vector3(cx + 3.42, 2.06, fz - 0.12), 20, Color("4a4a4e"), 180)
	_sign("1", Vector3(cx + 3.42, 1.8, fz - 0.12), 20, Color("4a4a4e"), 180)
	# Orange SUNSHINE'S BAKERY bar + circular logo-girl.
	_box(Vector3(4.35, 0.58, 0.12), Vector3(cx, 5.18, fz - 0.1), ORANGE, false)
	_sign("SUNSHINE'S BAKERY", Vector3(cx, 5.2, fz - 0.2), 34, WINE, 180)
	_box(Vector3(1.22, 1.22, 0.08), Vector3(cx, 6.28, fz - 0.08), Color("141416"), false)
	VoxelKit.add_box(self, Vector3(1.08, 1.08, 0.1), Vector3(cx, 6.28, fz - 0.14), VoxelKit.tex(LOGO_GIRL), false)
	# Minimal interior.
	_box(Vector3(w - t * 2.4, 0.08, d - 0.9), Vector3(cx, 0.06, cz), Color("e8dfd0"), false)
	_box(Vector3(2.9, 1.0, 0.7), Vector3(cx, 0.55, rz - 1.15), Color("5a3a22"))
	_box(Vector3(2.6, 0.48, 0.38), Vector3(cx, 1.26, rz - 1.2), GLASS, false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, 3.35, cz)
	lamp.light_color = Color("ffe4b8")
	lamp.light_energy = 0.85
	lamp.omni_range = 8
	add_child(lamp)


func _window(pos: Vector3, dark: bool) -> void:
	_box(Vector3(1.62, 1.28, 0.14), pos + Vector3(0, 0, -0.02), PINK, false)
	_box(Vector3(1.32, 0.98, 0.07), pos + Vector3(0, 0, -0.1), GLASS_DK if dark else GLASS, false)


func _build_green_cottage() -> void:
	# One-story green neighbor to the right of 2231 (photo).
	var o := Vector3(8.15, 0, 1.35)
	_box(Vector3(4.85, 2.65, 3.5), o + Vector3(0, 1.32, 0), GREEN)
	for i in 7:
		_box(Vector3(4.8, 0.05, 3.45), o + Vector3(0, 0.34 + i * 0.34, 0.04), GREEN_STRIPE, false)
	_box(Vector3(5.35, 0.22, 3.95), o + Vector3(0, 2.78, 0), SHINGLE)
	_box(Vector3(3.6, 0.16, 2.7), o + Vector3(0, 2.98, 0), SHINGLE, false)
	_box(Vector3(0.72, 0.72, 0.08), o + Vector3(-1.05, 1.72, -1.78), Color("f4f2ea"), false)
	_box(Vector3(0.52, 0.52, 0.06), o + Vector3(-1.05, 1.72, -1.84), GLASS, false)


func _build_deck() -> void:
	# Wooden accessibility ramp + small landing on the green house (photo right).
	var rx := 5.45
	_box(Vector3(2.15, 0.14, 6.15), Vector3(rx, 0.52, 0.05), WOOD, true, 0.0, deg_to_rad(-11.0))
	for i in 11:
		_box(Vector3(2.0, 0.04, 0.18), Vector3(rx, 0.16 + i * 0.08, -2.45 + i * 0.46), WOOD_DK, false, 0.0, deg_to_rad(-11.0))
	_box(Vector3(0.1, 0.95, 6.0), Vector3(rx - 1.1, 0.92, 0.05), WOOD, true, 0.0, deg_to_rad(-11.0))
	_box(Vector3(0.1, 0.95, 6.0), Vector3(rx + 1.1, 0.92, 0.05), WOOD, true, 0.0, deg_to_rad(-11.0))
	_box(Vector3(3.4, 0.16, 2.55), Vector3(7.25, _deck_y, 2.65), WOOD)
	_box(Vector3(3.3, 0.85, 0.1), Vector3(7.25, _deck_y + 0.5, 1.4), WOOD, false)
	_box(Vector3(0.1, 0.85, 2.4), Vector3(5.6, _deck_y + 0.5, 2.65), WOOD, false)


func _build_trees() -> void:
	# Forest wall behind the shop — keep the front lawn clear.
	_tree(Vector3(-6.6, 0, 5.4), 5.4)
	_tree(Vector3(-3.2, 0, 6.8), 4.9)
	_tree(Vector3(0.2, 0, 7.2), 5.3)
	_tree(Vector3(3.4, 0, 6.9), 4.8)
	_tree(Vector3(10.6, 0, 5.6), 4.6)
	_tree(Vector3(12.2, 0, 2.2), 4.2)
	_tree(Vector3(-9.6, 0, 3.4), 4.0)
	_tree(Vector3(-8.4, 0, 6.2), 4.4)


func _tree(pos: Vector3, height: float) -> void:
	_box(Vector3(0.55, height * 0.45, 0.55), pos + Vector3(0, height * 0.22, 0), BARK, false)
	_box(Vector3(2.55, 2.2, 2.55), pos + Vector3(0, height * 0.64, 0), LEAF, false)
	_box(Vector3(1.7, 1.45, 1.7), pos + Vector3(0.35, height * 0.9, 0.2), LEAF_DK, false)


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
	# Keep staff off the hero lawn so the photo read stays clean.
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
		_place_pickup(Vector3(2.35, 0.55, -6.15), "drink", true)


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
