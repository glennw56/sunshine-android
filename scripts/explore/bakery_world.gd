extends Node3D
class_name BakeryWorld
## MVP voxel bakery: cube shop + yard pad. Walk in the storefront door.
## Flat colors, MeshInstance3D boxes — not a Minecraft engine or photoreal GLB.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"

const CREAM := Color("f4f2ee")
const BLUSH := Color("e8b4b8")
const WINE := Color("6b2d3c")
const ORANGE := Color("e07a45")
const WOOD := Color("c4a06a")
const GRASS := Color("5a9e3a")
const DIRT := Color("8a5a32")
const STONE := Color("c9b49a")
const LEAF := Color("3f6b32")
const BARK := Color("4a3424")
const GOLD := Color("e0b04a")

var _player: PlayerExplorer
var _front_z: float = -1.35
var _shop_w: float = 10.0
var _shop_h: float = 5.0
var _shop_d: float = 7.4
var _wall: float = 0.28
var _door_w: float = 2.2
var _door_h: float = 2.5
var _side_door_z: float = 4.55
var _side_door_w: float = 1.6


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_yard()
	_build_shop()
	_build_interior()
	_build_backyard()
	_spawn_collectibles()


func _mat(c: Color) -> StandardMaterial3D:
	return VoxelKit.flat(c)


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_y: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _mat(color), collide, rot_y)


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	return VoxelKit.add_sign(self, text, pos, font_size, color, rot_y_deg)


func _wall_door_along_z(
	thickness: float,
	height: float,
	depth: float,
	wall_x: float,
	z_center: float,
	color: Color,
	door_z: float,
	door_w: float,
	door_h: float
) -> void:
	var z0 := z_center - depth * 0.5
	var z1 := z_center + depth * 0.5
	var d0 := door_z - door_w * 0.5
	var d1 := door_z + door_w * 0.5
	var front_len := d0 - z0
	if front_len > 0.08:
		_box(Vector3(thickness, height, front_len), Vector3(wall_x, height * 0.5, z0 + front_len * 0.5), color)
	var back_len := z1 - d1
	if back_len > 0.08:
		_box(Vector3(thickness, height, back_len), Vector3(wall_x, height * 0.5, d1 + back_len * 0.5), color)
	var lintel_h := height - door_h
	if lintel_h > 0.08:
		_box(
			Vector3(thickness, lintel_h, door_w + 0.08),
			Vector3(wall_x, door_h + lintel_h * 0.5, door_z),
			color
		)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("7ec4ee")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("fff1dc")
	we.ambient_light_energy = 0.82
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 40, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)


func _build_yard() -> void:
	# Grass pad + dirt lip + street cubes. Player spawns on the lawn facing the door.
	_box(Vector3(22, 0.5, 22), Vector3(0, -0.25, 3.2), GRASS)
	_box(Vector3(22, 0.4, 22), Vector3(0, -0.7, 3.2), DIRT, false)
	_box(Vector3(22, 0.45, 6), Vector3(0, -0.22, -12.2), Color("5a5a5a"))
	# Paver walk to the door (visual only so the opening stays clear).
	_box(Vector3(1.6, 0.12, 3.2), Vector3(0.0, 0.08, -2.85), STONE, false)
	_box(Vector3(1.7, 0.12, 0.55), Vector3(0.0, 0.1, -1.5), STONE, false)
	_box(Vector3(1.6, 0.12, 1.6), Vector3(-5.6, 0.08, 3.6), STONE, false)
	# Block picnic table + sandwich board
	_picnic(Vector3(2.6, 0, -4.0))
	_box(Vector3(0.7, 0.9, 0.12), Vector3(-1.6, 0.5, -2.6), WOOD, false, 0.2)
	_sign("OPEN", Vector3(-1.6, 0.72, -2.52), 36, WINE, 180)
	_tree(Vector3(5.4, 0, -2.2), 3.2)
	_tree(Vector3(-6.2, 0, -3.4), 3.6)
	_sign("2231 1ST AVE S", Vector3(0.0, 0.55, -8.2), 36, Color("fff6ea"), 0.0)


func _picnic(pos: Vector3, dark: bool = false) -> void:
	var top := Color("3a4038") if dark else WOOD
	_box(Vector3(1.8, 0.18, 0.8), pos + Vector3(0, 0.78, 0), top, false)
	_box(Vector3(0.18, 0.78, 0.18), pos + Vector3(-0.7, 0.39, 0.25), BARK, false)
	_box(Vector3(0.18, 0.78, 0.18), pos + Vector3(0.7, 0.39, 0.25), BARK, false)
	_box(Vector3(0.18, 0.78, 0.18), pos + Vector3(-0.7, 0.39, -0.25), BARK, false)
	_box(Vector3(0.18, 0.78, 0.18), pos + Vector3(0.7, 0.39, -0.25), BARK, false)


func _tree(pos: Vector3, height: float) -> void:
	_box(Vector3(0.45, height * 0.45, 0.45), pos + Vector3(0, height * 0.22, 0), BARK, false)
	_box(Vector3(1.6, 1.6, 1.6), pos + Vector3(0, height * 0.62, 0), LEAF, false)


func _build_shop() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := _front_z + d
	var cz := fz + d * 0.5
	_wall_door_along_z(t, h, d, -w * 0.5 + t * 0.5, cz, CREAM, _side_door_z, _side_door_w, _door_h)
	_box(Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, cz), CREAM)
	_box(Vector3(w, h, t), Vector3(0, h * 0.5, rz - t * 0.5), CREAM)
	var wing := (w - _door_w) * 0.5
	# Facade wings + lintel are visual; collision lives on the thin inner jambs
	# so the storefront opening stays walkable (capsule 0.36r).
	_box(Vector3(wing, h, t), Vector3(-(_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), CREAM, false)
	_box(Vector3(wing, h, t), Vector3((_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), CREAM, false)
	var lintel_h := h - _door_h
	_box(Vector3(_door_w + 0.08, lintel_h, t), Vector3(0, _door_h + lintel_h * 0.5, fz + t * 0.5), CREAM, false)
	var jam := 0.22
	_box(Vector3(jam, _door_h, t), Vector3(-_door_w * 0.5 - jam * 0.5, _door_h * 0.5, fz + t * 0.5), CREAM)
	_box(Vector3(jam, _door_h, t), Vector3(_door_w * 0.5 + jam * 0.5, _door_h * 0.5, fz + t * 0.5), CREAM)
	# Blush block trim
	_box(Vector3(w + 0.2, 0.35, 0.35), Vector3(0, h - 0.05, fz), BLUSH)
	_box(Vector3(0.35, h, 0.35), Vector3(-w * 0.5, h * 0.5, fz), BLUSH)
	_box(Vector3(0.35, h, 0.35), Vector3(w * 0.5, h * 0.5, fz), BLUSH)
	_box(Vector3(0.22, _door_h, 0.22), Vector3(-_door_w * 0.5, _door_h * 0.5, fz - 0.02), WINE, false)
	_box(Vector3(0.22, _door_h, 0.22), Vector3(_door_w * 0.5, _door_h * 0.5, fz - 0.02), WINE, false)
	_box(Vector3(_door_w + 0.22, 0.22, 0.22), Vector3(0, _door_h, fz - 0.02), WINE, false)
	# Swung door leaf (visual only)
	_box(Vector3(0.12, _door_h - 0.2, _door_w * 0.55), Vector3(_door_w * 0.62, (_door_h - 0.2) * 0.5, fz + 0.8), WOOD, false, 1.1)
	# Window cubes
	_box(Vector3(1.8, 1.6, 0.12), Vector3(-2.5, 2.1, fz - 0.02), Color(0.55, 0.75, 0.88, 1), false)
	_box(Vector3(1.8, 1.6, 0.12), Vector3(2.5, 2.1, fz - 0.02), Color(0.55, 0.75, 0.88, 1), false)
	_box(Vector3(w - t * 2, 0.35, d - t * 2), Vector3(0, 3.35, cz), Color("f3e6d4"))
	# Facade logo cube + orange bar
	VoxelKit.add_box(self, Vector3(1.4, 1.4, 0.2), Vector3(0, 4.15, fz - 0.12), VoxelKit.tex(LOGO_GIRL), false)
	_box(Vector3(6.4, 0.7, 0.2), Vector3(0, 3.2, fz - 0.08), ORANGE, false)
	_sign("SUNSHINE'S BAKERY", Vector3(0, 3.2, fz - 0.2), 42, Color("1a1410"), 180)
	_sign("COME IN", Vector3(0.0, 2.55, fz + 0.55), 28, WINE, 0)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.0, fz + 0.8)
	lamp.light_color = Color("ffe0b0")
	lamp.light_energy = 1.05
	lamp.omni_range = 9
	add_child(lamp)


func _build_interior() -> void:
	var cz := _front_z + _shop_d * 0.5
	var inner_w := _shop_w - _wall * 2
	var inner_d := _shop_d - _wall * 2
	# Visual only — grass already carries collision. A thick floor box
	# clips the player capsule (bottom ≈ 0.12m) and blocks the door.
	_box(Vector3(inner_w, 0.08, inner_d - 0.4), Vector3(0, 0.06, cz + 0.15), Color("d8c4a8"), false)
	_box(Vector3(1.4, 0.08, inner_d * 0.42), Vector3(0.0, 0.22, _front_z + 1.6), BLUSH, false)
	_box(Vector3(2.2, 0.08, 1.1), Vector3(-2.3, 0.22, _side_door_z), BLUSH, false)
	# Counter + glass pastry case as cubes
	_box(Vector3(4.4, 1.05, 0.8), Vector3(0.2, 0.62, 4.55), WOOD)
	_box(Vector3(4.2, 0.7, 0.55), Vector3(0.2, 1.45, 4.5), Color(0.72, 0.88, 0.92), false)
	_box(Vector3(4.2, 0.12, 0.58), Vector3(0.2, 1.82, 4.5), WOOD, false)
	for i in 4:
		_box(Vector3(0.28, 0.2, 0.28), Vector3(-1.2 + i * 0.85, 1.22, 4.42), [GOLD, BLUSH, Color("f3d9a8"), Color("8a5a32")][i], false)
	_box(Vector3(1.2, 1.15, 0.7), Vector3(3.3, 0.68, 4.5), WINE)
	_box(Vector3(0.55, 0.45, 0.4), Vector3(3.3, 1.48, 4.5), Color("b87333"), false)
	_box(Vector3(1.5, 1.0, 0.4), Vector3(-3.2, 0.58, 0.4), WOOD)
	_sign("TODAY · CUBES", Vector3(-1.1, 2.2, 5.45), 26, Color("fff6ea"), 180)
	_sign("YARD →", Vector3(-3.7, 2.1, _side_door_z), 32, WINE, 90)
	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 2.8, 2.2)
	interior.light_color = Color("ffe6c8")
	interior.light_energy = 1.6
	interior.omni_range = 10
	add_child(interior)


func _build_backyard() -> void:
	_box(Vector3(1.5, 0.12, 8.0), Vector3(-5.6, 0.08, 7.2), STONE, false)
	_picnic(Vector3(0.6, 0, 9.2), true)
	_picnic(Vector3(-2.8, 0, 11.6), true)
	_box(Vector3(14, 1.6, 0.4), Vector3(0.2, 0.85, 14.6), WOOD)
	_box(Vector3(0.4, 1.6, 7.0), Vector3(-6.8, 0.85, 11.2), WOOD)
	_box(Vector3(0.4, 1.6, 5.4), Vector3(6.6, 0.85, 12.0), WOOD)
	_tree(Vector3(-5.0, 0, 13.4), 4.2)
	_tree(Vector3(3.8, 0, 13.8), 4.6)


func _spawn_collectibles() -> void:
	# MVP: three cube pastries (1 yard + 2 indoor). Fresh Batch extras stay stubbed.
	var spots: Array[Dictionary] = [
		{"pos": Vector3(2.2, 0.55, -3.5), "kind": "croissant"},
		{"pos": Vector3(-1.2, 0.55, 3.6), "kind": "croissant"},
		{"pos": Vector3(1.4, 0.45, 1.6), "kind": "drink"},
	]
	for row in spots:
		_place_pickup(row["pos"], str(row["kind"]), false)


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
