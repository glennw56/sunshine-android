extends Node3D
class_name BakeryWorld
## Minecraft-like NPC village (boxes only). Dirt paths, oak houses, fences,
## a square with a well, and a walkable bakery house. Not a GLB / not a void.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"

const OAK := Color("c4a06a")
const OAK_DARK := Color("8a5a32")
const COBBLE := Color("8a8580")
const GRASS := Color("5a9e3a")
const DIRT := Color("9a6b3c")
const LEAF := Color("3f6b32")
const BARK := Color("4a3424")
const WATER := Color("3a7ca5")
const GLASS := Color("8ec4d8")
const WINE := Color("6b2d3c")
const BLUSH := Color("e8b4b8")
const GOLD := Color("e0b04a")
const ROBE_BROWN := Color("8b5a2b")
const ROBE_GREEN := Color("3d6b32")
const ROBE_WINE := Color("6b2d3c")

var _player: PlayerExplorer
var _front_z: float = -1.35
var _shop_w: float = 7.2
var _shop_h: float = 3.6
var _shop_d: float = 7.0
var _wall: float = 0.28
var _door_w: float = 2.2
var _door_h: float = 2.4


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_ground()
	_build_square()
	_build_bakery_house()
	_build_neighbor_houses()
	_build_fences_and_trees()
	_build_villagers()
	_spawn_collectibles()


func _mat(c: Color) -> StandardMaterial3D:
	return VoxelKit.flat(c)


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_y: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _mat(color), collide, rot_y)


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	return VoxelKit.add_sign(self, text, pos, font_size, color, rot_y_deg)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("7ec4ee")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("fff4d8")
	we.ambient_light_energy = 0.9
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	# One grass collider. Dirt paths are visual so they never trip the capsule.
	_box(Vector3(42, 0.5, 42), Vector3(0, -0.25, 4), GRASS)
	_box(Vector3(42, 0.35, 42), Vector3(0, -0.7, 4), DIRT, false)
	# Path from spawn → square → bakery door (+Z).
	_box(Vector3(2.2, 0.1, 14), Vector3(0, 0.06, 1.2), DIRT, false)
	_box(Vector3(16, 0.1, 2.2), Vector3(0, 0.06, 1.0), DIRT, false)
	_box(Vector3(2.2, 0.1, 10), Vector3(-8.5, 0.06, 6.0), DIRT, false)
	_box(Vector3(2.2, 0.1, 8), Vector3(8.5, 0.06, 5.0), DIRT, false)


func _build_square() -> void:
	# Village well in the square, off the walk-in centerline.
	_box(Vector3(2.2, 0.45, 2.2), Vector3(3.6, 0.28, 1.1), COBBLE, false)
	_box(Vector3(1.4, 0.7, 1.4), Vector3(3.6, 0.42, 1.1), WATER, false)
	_box(Vector3(0.18, 1.6, 0.18), Vector3(2.7, 1.0, 0.2), OAK, false)
	_box(Vector3(0.18, 1.6, 0.18), Vector3(4.5, 1.0, 0.2), OAK, false)
	_box(Vector3(0.18, 1.6, 0.18), Vector3(2.7, 1.0, 2.0), OAK, false)
	_box(Vector3(0.18, 1.6, 0.18), Vector3(4.5, 1.0, 2.0), OAK, false)
	_box(Vector3(2.4, 0.16, 2.4), Vector3(3.6, 1.85, 1.1), OAK_DARK, false)
	_sign("WELL", Vector3(3.6, 2.15, 1.1), 22, Color("fff6ea"), 180)
	# Hay / crate stacks
	_box(Vector3(0.7, 0.7, 0.7), Vector3(-2.4, 0.4, -2.8), GOLD, false)
	_box(Vector3(0.7, 0.7, 0.7), Vector3(-2.4, 1.1, -2.8), GOLD, false)
	_box(Vector3(0.55, 0.55, 0.55), Vector3(2.2, 0.35, -3.4), OAK_DARK, false)


func _oak_house(origin: Vector3, w: float, d: float, h: float, door_front: bool = true) -> void:
	var t := 0.32
	var cz := origin.z
	var cx := origin.x
	# Closed shell (neighbors are not walk-through).
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, cz - d * 0.5), OAK)
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, cz + d * 0.5), OAK)
	_box(Vector3(t, h, d), Vector3(cx - w * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(t, h, d), Vector3(cx + w * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(w + 0.5, 0.35, d + 0.5), Vector3(cx, h + 0.1, cz), OAK_DARK)
	_box(Vector3(w * 0.55, 0.35, d * 0.55), Vector3(cx, h + 0.42, cz), OAK_DARK, false)
	if door_front:
		_box(Vector3(0.9, 1.7, 0.08), Vector3(cx, 0.9, cz - d * 0.5 - 0.06), OAK_DARK, false)
	_box(Vector3(0.7, 0.7, 0.08), Vector3(cx - w * 0.22, 1.8, cz - d * 0.5 - 0.05), GLASS, false)
	_box(Vector3(0.7, 0.7, 0.08), Vector3(cx + w * 0.22, 1.8, cz - d * 0.5 - 0.05), GLASS, false)


func _build_bakery_house() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := _front_z + d
	var cz := fz + d * 0.5
	# Side + back walls (oak). Front is split around a walkable door.
	_box(Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(w, h, t), Vector3(0, h * 0.5, rz - t * 0.5), OAK)
	var wing := (w - _door_w) * 0.5
	_box(Vector3(wing, h, t), Vector3(-(_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), OAK, false)
	_box(Vector3(wing, h, t), Vector3((_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), OAK, false)
	var lintel_h := h - _door_h
	_box(Vector3(_door_w + 0.08, lintel_h, t), Vector3(0, _door_h + lintel_h * 0.5, fz + t * 0.5), OAK, false)
	var jam := 0.2
	_box(Vector3(jam, _door_h, t), Vector3(-_door_w * 0.5 - jam * 0.5, _door_h * 0.5, fz + t * 0.5), OAK)
	_box(Vector3(jam, _door_h, t), Vector3(_door_w * 0.5 + jam * 0.5, _door_h * 0.5, fz + t * 0.5), OAK)
	_box(Vector3(0.12, _door_h - 0.2, _door_w * 0.5), Vector3(_door_w * 0.55, (_door_h - 0.2) * 0.5, fz + 0.7), OAK_DARK, false, 1.05)
	_box(Vector3(0.9, 0.9, 0.1), Vector3(-2.1, 2.05, fz - 0.04), GLASS, false)
	_box(Vector3(0.9, 0.9, 0.1), Vector3(2.1, 2.05, fz - 0.04), GLASS, false)
	_box(Vector3(w + 0.6, 0.4, d + 0.6), Vector3(0, h + 0.12, cz), OAK_DARK)
	_box(Vector3(w * 0.5, 0.35, d * 0.5), Vector3(0, h + 0.45, cz), OAK_DARK, false)
	VoxelKit.add_box(self, Vector3(0.9, 0.9, 0.16), Vector3(0, 3.15, fz - 0.12), VoxelKit.tex(LOGO_GIRL), false)
	_box(Vector3(3.4, 0.45, 0.16), Vector3(0, 2.55, fz - 0.1), WINE, false)
	_sign("BAKERY", Vector3(0, 2.55, fz - 0.2), 32, Color("fff6ea"), 180)
	# Interior furniture — floor is visual only (grass carries collision).
	_box(Vector3(w - t * 2, 0.08, d - 0.8), Vector3(0, 0.06, cz + 0.2), OAK, false)
	_box(Vector3(3.2, 1.0, 0.7), Vector3(0.1, 0.58, 4.4), OAK_DARK)
	_box(Vector3(3.0, 0.55, 0.45), Vector3(0.1, 1.35, 4.35), GLASS, false)
	for i in 3:
		_box(Vector3(0.26, 0.2, 0.26), Vector3(-0.9 + i * 0.85, 1.18, 4.28), [GOLD, BLUSH, Color("f3d9a8")][i], false)
	_sign("FRESH CUBES", Vector3(0.1, 2.05, 4.55), 22, Color("fff6ea"), 180)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.7, 2.0)
	lamp.light_color = Color("ffe0b0")
	lamp.light_energy = 1.15
	lamp.omni_range = 9
	add_child(lamp)


func _build_neighbor_houses() -> void:
	_oak_house(Vector3(-8.6, 0, -1.2), 5.2, 5.0, 3.2)
	_oak_house(Vector3(8.8, 0, -0.6), 5.0, 4.8, 3.1)
	_oak_house(Vector3(-8.2, 0, 8.6), 5.4, 5.2, 3.4, false)
	_oak_house(Vector3(8.4, 0, 8.8), 4.8, 4.6, 3.0, false)
	_oak_house(Vector3(0.2, 0, 12.4), 6.0, 5.0, 3.3, false)


func _build_fences_and_trees() -> void:
	for i in 8:
		var x := -7.0 + i * 2.0
		if absf(x) < 1.4:
			continue
		_box(Vector3(0.14, 1.05, 0.14), Vector3(x, 0.55, -6.4), OAK, false)
		_box(Vector3(1.7, 0.1, 0.1), Vector3(x + 0.85, 0.85, -6.4), OAK, false)
	for i in 6:
		_box(Vector3(0.14, 1.05, 0.14), Vector3(-11.2, 0.55, -2.0 + i * 1.8), OAK, false)
		_box(Vector3(0.1, 0.1, 1.6), Vector3(-11.2, 0.85, -1.1 + i * 1.8), OAK, false)
		_box(Vector3(0.14, 1.05, 0.14), Vector3(11.4, 0.55, -1.6 + i * 1.8), OAK, false)
		_box(Vector3(0.1, 0.1, 1.6), Vector3(11.4, 0.85, -0.7 + i * 1.8), OAK, false)
	_tree(Vector3(-5.4, 0, -5.6), 3.4)
	_tree(Vector3(5.8, 0, -5.2), 3.6)
	_tree(Vector3(-12.2, 0, 3.0), 4.0)
	_tree(Vector3(12.4, 0, 4.2), 3.8)
	_tree(Vector3(-4.8, 0, 14.6), 4.2)
	_tree(Vector3(5.2, 0, 15.0), 4.0)


func _tree(pos: Vector3, height: float) -> void:
	_box(Vector3(0.45, height * 0.45, 0.45), pos + Vector3(0, height * 0.22, 0), BARK, false)
	_box(Vector3(1.7, 1.7, 1.7), pos + Vector3(0, height * 0.62, 0), LEAF, false)
	_box(Vector3(1.1, 1.1, 1.1), pos + Vector3(0.35, height * 0.85, 0.15), LEAF, false)


func _villager(pos: Vector3, robe: Color, rot_y: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	root.add_to_group("village_npc")
	add_child(root)
	VoxelKit.add_box(root, Vector3(0.38, 0.7, 0.24), Vector3(0, 0.55, 0), VoxelKit.flat(robe), false)
	VoxelKit.add_box(root, Vector3(0.32, 0.32, 0.32), Vector3(0, 1.05, 0), VoxelKit.flat(Color("e6c8a0")), false)
	VoxelKit.add_box(root, Vector3(0.14, 0.45, 0.14), Vector3(-0.16, 0.22, 0), VoxelKit.flat(OAK_DARK), false)
	VoxelKit.add_box(root, Vector3(0.14, 0.45, 0.14), Vector3(0.16, 0.22, 0), VoxelKit.flat(OAK_DARK), false)


func _build_villagers() -> void:
	_villager(Vector3(-2.8, 0, -3.1), ROBE_BROWN, 0.4)
	_villager(Vector3(2.4, 0, -2.4), ROBE_GREEN, -0.5)
	_villager(Vector3(-4.4, 0, 2.2), ROBE_WINE, 1.2)
	_villager(Vector3(5.2, 0, 3.4), ROBE_BROWN, 3.4)


func _spawn_collectibles() -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector3(2.0, 0.55, -3.6), "kind": "croissant"},
		{"pos": Vector3(-1.0, 0.55, 3.4), "kind": "croissant"},
		{"pos": Vector3(1.2, 0.5, 1.8), "kind": "drink"},
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
