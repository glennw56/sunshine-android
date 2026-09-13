extends Node3D
class_name BakeryWorld
## Minecraft-like NPC village (boxes only). Open square first: grass, dirt
## path, chunky cottages, NPCs, pickups. Bakery is the far house, not a hallway.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"

const OAK := Color("8b6234")
const OAK_DARK := Color("5a3214")
const SPRUCE := Color("5c3a22")
const COBBLE := Color("6e6a64")
const GRASS := Color("3f8f28")
const DIRT := Color("7a4a22")
const LEAF := Color("2d5a22")
const BARK := Color("3a2416")
const WATER := Color("2a6a96")
const GLASS := Color("2f4a58")
const WINE := Color("6b2d3c")
const BLUSH := Color("e8b4b8")
const GOLD := Color("c4922a")
const WHEAT := Color("b8862a")
const ROBE_BROWN := Color("8b5a2b")
const ROBE_GREEN := Color("3d6b32")
const ROBE_WINE := Color("6b2d3c")

var _player: PlayerExplorer
var _front_z: float = 0.45
var _shop_w: float = 4.4
var _shop_h: float = 3.4
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
	we.ambient_light_color = Color("c8d8a8")
	we.ambient_light_energy = 0.42
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	# One grass collider. Paths are visual so they never trip the capsule.
	_box(Vector3(48, 0.5, 48), Vector3(0, -0.25, 2), GRASS)
	_box(Vector3(48, 0.35, 48), Vector3(0, -0.7, 2), DIRT, false)
	# Dirt path spawn → square → bakery (+Z).
	_box(Vector3(2.4, 0.1, 20), Vector3(0, 0.06, -0.4), DIRT, false)
	_box(Vector3(11, 0.1, 2.4), Vector3(0, 0.06, -4.6), DIRT, false)
	_box(Vector3(2.2, 0.1, 10), Vector3(-7.4, 0.06, 3.2), DIRT, false)
	_box(Vector3(2.2, 0.1, 8), Vector3(7.6, 0.06, 2.8), DIRT, false)


func _build_square() -> void:
	# Well + bell sit in the open square, off the walk centerline.
	_box(Vector3(1.7, 0.5, 1.7), Vector3(2.15, 0.3, -4.6), COBBLE, false)
	_box(Vector3(1.1, 0.62, 1.1), Vector3(2.15, 0.42, -4.6), WATER, false)
	_box(Vector3(0.16, 1.55, 0.16), Vector3(1.4, 0.95, -5.3), OAK, false)
	_box(Vector3(0.16, 1.55, 0.16), Vector3(2.9, 0.95, -5.3), OAK, false)
	_box(Vector3(0.16, 1.55, 0.16), Vector3(1.4, 0.95, -3.9), OAK, false)
	_box(Vector3(0.16, 1.55, 0.16), Vector3(2.9, 0.95, -3.9), OAK, false)
	_box(Vector3(1.9, 0.14, 1.9), Vector3(2.15, 1.78, -4.6), OAK_DARK, false)
	_sign("WELL", Vector3(2.15, 2.1, -4.6), 22, Color("fff6ea"), 180)
	_box(Vector3(0.22, 2.15, 0.22), Vector3(-2.05, 1.12, -5.0), OAK_DARK, false)
	_box(Vector3(0.75, 0.3, 0.75), Vector3(-2.05, 2.25, -5.0), GOLD, false)
	_sign("BELL", Vector3(-2.05, 2.62, -5.0), 20, Color("fff6ea"), 180)
	_box(Vector3(0.75, 0.75, 0.75), Vector3(-2.4, 0.42, -6.35), GOLD, false)
	_box(Vector3(0.75, 0.75, 0.75), Vector3(-2.4, 1.16, -6.35), GOLD, false)
	_box(Vector3(0.55, 0.55, 0.55), Vector3(1.25, 0.35, -6.55), OAK_DARK, false)
	_lamp(Vector3(-1.5, 0, -6.2))
	_lamp(Vector3(1.5, 0, -3.2))
	for i in 4:
		for j in 3:
			_box(Vector3(0.55, 0.22, 0.55), Vector3(-6.6 + i * 0.62, 0.16, -7.4 + j * 0.62), WHEAT, false)


func _lamp(pos: Vector3) -> void:
	_box(Vector3(0.14, 1.7, 0.14), pos + Vector3(0, 0.9, 0), OAK, false)
	_box(Vector3(0.28, 0.22, 0.28), pos + Vector3(0, 1.82, 0), GOLD, false)
	var glow := OmniLight3D.new()
	glow.position = pos + Vector3(0, 1.85, 0)
	glow.light_color = Color("ffd080")
	glow.light_energy = 0.55
	glow.omni_range = 4.5
	add_child(glow)


func _oak_house(origin: Vector3, w: float, d: float, h: float, door_front: bool = true) -> void:
	var t := 0.32
	var cz := origin.z
	var cx := origin.x
	_box(Vector3(w + 0.2, 0.22, d + 0.2), Vector3(cx, 0.12, cz), COBBLE, false)
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, cz - d * 0.5), OAK)
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, cz + d * 0.5), OAK)
	_box(Vector3(t, h, d), Vector3(cx - w * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(t, h, d), Vector3(cx + w * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(0.3, h + 0.12, 0.3), Vector3(cx - w * 0.5, h * 0.5, cz - d * 0.5), BARK, false)
	_box(Vector3(0.3, h + 0.12, 0.3), Vector3(cx + w * 0.5, h * 0.5, cz - d * 0.5), BARK, false)
	_box(Vector3(w + 0.7, 0.34, d + 0.7), Vector3(cx, h + 0.1, cz), OAK_DARK)
	_box(Vector3(w * 0.66, 0.34, d * 0.66), Vector3(cx, h + 0.42, cz), OAK_DARK, false)
	_box(Vector3(w * 0.32, 0.3, d * 0.32), Vector3(cx, h + 0.7, cz), OAK_DARK, false)
	if door_front:
		_box(Vector3(0.95, 1.75, 0.08), Vector3(cx, 0.92, cz - d * 0.5 - 0.06), OAK_DARK, false)
	_box(Vector3(0.72, 0.72, 0.08), Vector3(cx - w * 0.22, 1.78, cz - d * 0.5 - 0.05), GLASS, false)
	_box(Vector3(0.72, 0.72, 0.08), Vector3(cx + w * 0.22, 1.78, cz - d * 0.5 - 0.05), GLASS, false)


func _build_bakery_house() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := _front_z + d
	var cz := fz + d * 0.5
	_box(Vector3(w + 0.25, 0.2, d + 0.25), Vector3(0, 0.12, cz), COBBLE, false)
	_box(Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, cz), OAK)
	_box(Vector3(w, h, t), Vector3(0, h * 0.5, rz - t * 0.5), SPRUCE)
	var wing := (w - _door_w) * 0.5
	_box(Vector3(wing, h, t), Vector3(-(_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), OAK, false)
	_box(Vector3(wing, h, t), Vector3((_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), OAK, false)
	var lintel_h := h - _door_h
	_box(Vector3(_door_w + 0.08, lintel_h, t), Vector3(0, _door_h + lintel_h * 0.5, fz + t * 0.5), OAK, false)
	var jam := 0.2
	_box(Vector3(jam, _door_h, t), Vector3(-_door_w * 0.5 - jam * 0.5, _door_h * 0.5, fz + t * 0.5), OAK)
	_box(Vector3(jam, _door_h, t), Vector3(_door_w * 0.5 + jam * 0.5, _door_h * 0.5, fz + t * 0.5), OAK)
	_box(Vector3(1.05, 2.15, 0.08), Vector3(0.0, 1.1, fz - 0.02), OAK_DARK, false)
	_box(Vector3(0.12, 0.12, 0.12), Vector3(0.38, 1.1, fz - 0.08), GOLD, false)
	_box(Vector3(0.85, 0.85, 0.1), Vector3(-1.4, 2.05, fz - 0.04), GLASS, false)
	_box(Vector3(0.85, 0.85, 0.1), Vector3(1.4, 2.05, fz - 0.04), GLASS, false)
	_box(Vector3(w + 0.7, 0.36, d + 0.7), Vector3(0, h + 0.1, cz), OAK_DARK)
	_box(Vector3(w * 0.55, 0.32, d * 0.55), Vector3(0, h + 0.42, cz), OAK_DARK, false)
	_box(Vector3(w + 0.9, 0.22, 0.7), Vector3(0, h + 0.02, fz - 0.28), OAK_DARK, false)
	VoxelKit.add_box(self, Vector3(0.85, 0.85, 0.16), Vector3(0, 3.05, fz - 0.18), VoxelKit.tex(LOGO_GIRL), false)
	_box(Vector3(2.8, 0.42, 0.16), Vector3(0, 2.48, fz - 0.16), WINE, false)
	_sign("BAKERY", Vector3(0, 2.48, fz - 0.26), 28, Color("fff6ea"), 180)
	_box(Vector3(w - t * 2, 0.08, d - 0.8), Vector3(0, 0.06, cz + 0.2), SPRUCE, false)
	_box(Vector3(3.0, 1.0, 0.7), Vector3(0.1, 0.58, fz + 5.1), OAK_DARK)
	_box(Vector3(2.8, 0.55, 0.45), Vector3(0.1, 1.35, fz + 5.05), GLASS, false)
	for i in 3:
		_box(Vector3(0.26, 0.2, 0.26), Vector3(-0.85 + i * 0.8, 1.18, fz + 4.98), [GOLD, BLUSH, Color("f3d9a8")][i], false)
	_sign("FRESH CUBES", Vector3(0.1, 2.05, fz + 5.25), 22, Color("fff6ea"), 180)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.7, fz + 2.2)
	lamp.light_color = Color("ffe0b0")
	lamp.light_energy = 1.15
	lamp.omni_range = 9
	add_child(lamp)


func _build_neighbor_houses() -> void:
	# Cottages sit beside the square (not a corridor around the camera).
	_oak_house(Vector3(-5.4, 0, -3.8), 4.0, 3.6, 3.2)
	_oak_house(Vector3(5.6, 0, -3.5), 4.0, 3.6, 3.1)
	_oak_house(Vector3(-7.6, 0, 6.8), 5.0, 4.8, 3.2, false)
	_oak_house(Vector3(7.8, 0, 7.0), 4.6, 4.4, 3.0, false)
	_oak_house(Vector3(0.2, 0, 13.2), 5.6, 4.8, 3.25, false)


func _build_fences_and_trees() -> void:
	for i in 8:
		var x := -7.2 + i * 2.05
		if absf(x) < 1.4:
			continue
		_box(Vector3(0.14, 1.05, 0.14), Vector3(x, 0.55, -9.4), OAK, false)
		_box(Vector3(1.7, 0.1, 0.1), Vector3(x + 0.85, 0.85, -9.4), OAK, false)
	for i in 5:
		_box(Vector3(0.14, 1.05, 0.14), Vector3(-8.4, 0.55, -8.2 + i * 1.5), OAK, false)
		_box(Vector3(0.1, 0.1, 1.3), Vector3(-8.4, 0.85, -7.5 + i * 1.5), OAK, false)
		_box(Vector3(0.14, 1.05, 0.14), Vector3(8.6, 0.55, -7.8 + i * 1.5), OAK, false)
		_box(Vector3(0.1, 0.1, 1.3), Vector3(8.6, 0.85, -7.1 + i * 1.5), OAK, false)
	_tree(Vector3(-7.2, 0, -7.0), 3.4)
	_tree(Vector3(7.4, 0, -6.6), 3.5)
	_tree(Vector3(-6.8, 0, 1.6), 3.8)
	_tree(Vector3(7.0, 0, 2.0), 3.6)
	_tree(Vector3(-4.6, 0, 14.8), 4.0)
	_tree(Vector3(5.0, 0, 15.0), 3.9)


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
	VoxelKit.add_box(root, Vector3(0.55, 1.0, 0.34), Vector3(0, 0.72, 0), VoxelKit.flat(robe), false)
	VoxelKit.add_box(root, Vector3(0.46, 0.46, 0.46), Vector3(0, 1.42, 0), VoxelKit.flat(Color("e6c8a0")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(-0.2, 0.28, 0), VoxelKit.flat(OAK_DARK), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(0.2, 0.28, 0), VoxelKit.flat(OAK_DARK), false)


func _build_villagers() -> void:
	_villager(Vector3(-1.7, 0, -6.35), ROBE_BROWN, 0.4)
	_villager(Vector3(1.55, 0, -5.95), ROBE_GREEN, -0.45)
	_villager(Vector3(-2.7, 0, -4.4), ROBE_WINE, 1.1)
	_villager(Vector3(2.85, 0, -3.4), ROBE_BROWN, 3.2)
	_villager(Vector3(-2.2, 0, -1.2), ROBE_GREEN, 2.8)


func _spawn_collectibles() -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector3(1.15, 0.62, -6.7), "kind": "croissant"},
		{"pos": Vector3(-1.0, 0.55, 3.6), "kind": "croissant"},
		{"pos": Vector3(1.2, 0.5, 2.1), "kind": "drink"},
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
