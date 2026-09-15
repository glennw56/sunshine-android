extends Object
class_name MenuProps
## Drop real Godot .glb menu props in assets/models/menu_props/ (from 3D Models,
## textured with Sunshine photos). Until those land, table/ground slots show
## photo-card standees of the real bakery shots — no cartoon drink tiles.

const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const DIR := "res://assets/models/menu_props/"
const TEX_WOOD := "res://assets/foss/wood.jpg"

## Table / seating slots. `glb` is the preferred filename stem when CoS drops a mesh.
const SLOTS: Array[Dictionary] = [
	{"id": "picnic_west", "glb": "croissant", "photo": "res://assets/generated/menu/croissant.png", "pos": Vector3(-4.8, 0.84, 3.9), "yaw": 0.14},
	{"id": "picnic_east", "glb": "croissant_cookie", "photo": "res://assets/generated/menu/croissant_cookie.png", "pos": Vector3(4.8, 0.84, 3.9), "yaw": -0.14},
	{"id": "picnic_north", "glb": "roll", "photo": "res://assets/generated/menu/roll.png", "pos": Vector3(0.0, 0.84, -4.7), "yaw": 0.0},
	{"id": "bistro_sw", "glb": "croissant_almond", "photo": "res://assets/generated/menu/croissant_almond.png", "pos": Vector3(-4.8, 0.82, 0.8), "yaw": 0.21},
	{"id": "bistro_se", "glb": "savory", "photo": "res://assets/generated/menu/savory.png", "pos": Vector3(4.8, 0.82, 0.8), "yaw": -0.14},
	{"id": "bistro_nw", "glb": "loaf", "photo": "res://assets/generated/menu/loaf.png", "pos": Vector3(-4.7, 0.82, -2.75), "yaw": -0.21},
	{"id": "bistro_ne", "glb": "croissant_berry", "photo": "res://assets/generated/menu/croissant_berry.png", "pos": Vector3(4.7, 0.82, -2.75), "yaw": 0.17},
	{"id": "bistro_center", "glb": "coffee", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(0.55, 0.82, -0.45), "yaw": 0.0},
	{"id": "menu_board_cup", "glb": "biscoff", "photo": "res://assets/generated/menu/square_biscoff.jpg", "pos": Vector3(-5.7, 0.92, 5.55), "yaw": 0.4},
	{"id": "cornhole_snack", "glb": "fruit_tea", "photo": "res://assets/generated/menu/square_fruit_tea.jpg", "pos": Vector3(1.15, 0.52, 5.55), "yaw": 0.2},
]


static func place(world: Node3D) -> int:
	var used: Dictionary = {}
	var count := 0
	for slot in SLOTS:
		var node := _instance_glb(str(slot["glb"]))
		if node:
			used[str(slot["glb"])] = true
			_mount(world, node, slot["pos"], float(slot["yaw"]))
			count += 1
		else:
			_photo_standee(world, str(slot["photo"]), slot["pos"], float(slot["yaw"]))
			count += 1
	for path in _scan_glbs():
		var stem := path.get_file().get_basename().to_lower()
		if used.has(stem):
			continue
		var extra := ImportedModelsLib.instantiate_if_real(path)
		if extra == null:
			continue
		var i := used.size()
		var pos := Vector3(-6.2 + float(i % 3) * 1.4, 0.52, 8.4 + float(i / 3) * 1.1)
		_mount(world, extra, pos, 0.0)
		used[stem] = true
		count += 1
	return count


static func _instance_glb(stem: String) -> Node3D:
	if stem.strip_edges() == "":
		return null
	var path := DIR + stem + ".glb"
	return ImportedModelsLib.instantiate_if_real(path)


static func _scan_glbs() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".glb"):
			out.append(DIR + name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _mount(world: Node3D, node: Node3D, pos: Vector3, yaw: float) -> void:
	node.name = "MenuProp_" + str(node.name)
	node.position = pos
	node.rotation.y = yaw
	node.add_to_group("menu_prop")
	world.add_child(node)


static func _photo_standee(world: Node3D, photo: String, pos: Vector3, yaw: float) -> void:
	if not ResourceLoader.exists(photo):
		return
	var root := Node3D.new()
	root.name = "MenuPhoto_" + photo.get_file().get_basename()
	root.position = pos
	root.rotation.y = yaw
	root.add_to_group("menu_prop")
	var plate := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.18
	cyl.height = 0.03
	cyl.radial_segments = 16
	plate.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("e0c090")
	if ResourceLoader.exists(TEX_WOOD):
		wood.albedo_texture = load(TEX_WOOD)
	wood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate.material_override = wood
	plate.position = Vector3(0, 0.02, 0)
	root.add_child(plate)
	var spr := Sprite3D.new()
	spr.texture = load(photo) as Texture2D
	spr.pixel_size = 0.00072
	spr.position = Vector3(0, 0.22, 0)
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	root.add_child(spr)
	world.add_child(root)
