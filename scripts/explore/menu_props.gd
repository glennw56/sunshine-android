extends Object
class_name MenuProps
## Drop real Godot .glb menu props in assets/models/menu_props/ (from 3D Models,
## textured with Sunshine photos). Until those land, table/ground slots show
## low-poly food using the real bakery / Square photos as albedo — no cartoon
## drink tiles, not Order UI.

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
		var stem := str(slot["glb"])
		var node := _instance_glb(stem)
		if node:
			used[stem] = true
			_mount(world, node, slot["pos"], float(slot["yaw"]))
			count += 1
		else:
			_photo_food(world, stem, str(slot["photo"]), slot["pos"], float(slot["yaw"]))
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


static func _tex_mat(photo: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(photo):
		m.albedo_texture = load(photo) as Texture2D
		m.albedo_color = Color.WHITE
	else:
		m.albedo_color = Color("e6b14a")
	return m


static func _wood_mat() -> StandardMaterial3D:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("e0c090")
	if ResourceLoader.exists(TEX_WOOD):
		wood.albedo_texture = load(TEX_WOOD)
	wood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return wood


static func _photo_food(world: Node3D, stem: String, photo: String, pos: Vector3, yaw: float) -> void:
	if not ResourceLoader.exists(photo):
		return
	var root := Node3D.new()
	root.name = "MenuPhoto_" + stem
	root.position = pos
	root.rotation.y = yaw
	root.add_to_group("menu_prop")
	var plate := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.18
	cyl.height = 0.025
	cyl.radial_segments = 16
	plate.mesh = cyl
	plate.material_override = _wood_mat()
	plate.position = Vector3(0, 0.015, 0)
	root.add_child(plate)
	var food := MeshInstance3D.new()
	food.material_override = _tex_mat(photo)
	if _is_drink(stem):
		var cup := CylinderMesh.new()
		cup.top_radius = 0.055
		cup.bottom_radius = 0.07
		cup.height = 0.14
		cup.radial_segments = 14
		food.mesh = cup
		food.position = Vector3(0, 0.1, 0)
		var lid := MeshInstance3D.new()
		var cap := CylinderMesh.new()
		cap.top_radius = 0.06
		cap.bottom_radius = 0.058
		cap.height = 0.02
		cap.radial_segments = 14
		lid.mesh = cap
		var cream := StandardMaterial3D.new()
		cream.albedo_color = Color("f4ece0")
		cream.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lid.material_override = cream
		lid.position = Vector3(0, 0.18, 0)
		root.add_child(lid)
		var straw := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.008
		stick.bottom_radius = 0.008
		stick.height = 0.12
		straw.mesh = stick
		var blush := StandardMaterial3D.new()
		blush.albedo_color = Color("e8b4b8")
		blush.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		straw.material_override = blush
		straw.position = Vector3(0.02, 0.24, 0)
		straw.rotation.z = 0.18
		root.add_child(straw)
	elif stem == "loaf":
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.1, 0.14)
		food.mesh = box
		food.position = Vector3(0, 0.07, 0)
		food.rotation.y = 0.2
	elif stem == "savory":
		var box := BoxMesh.new()
		box.size = Vector3(0.2, 0.07, 0.16)
		food.mesh = box
		food.position = Vector3(0, 0.055, 0)
	elif stem == "roll":
		var bun := SphereMesh.new()
		bun.radius = 0.09
		bun.height = 0.12
		bun.radial_segments = 12
		bun.rings = 8
		food.mesh = bun
		food.position = Vector3(0, 0.07, 0)
		food.scale = Vector3(1.15, 0.65, 1.0)
	else:
		var pastry := TorusMesh.new()
		pastry.inner_radius = 0.035
		pastry.outer_radius = 0.12
		pastry.rings = 14
		pastry.ring_segments = 10
		food.mesh = pastry
		food.position = Vector3(0, 0.055, 0)
		food.rotation.x = PI * 0.5
		food.scale = Vector3(1.15, 0.85, 0.55)
	root.add_child(food)
	world.add_child(root)


static func _is_drink(stem: String) -> bool:
	return stem in ["coffee", "biscoff", "fruit_tea"]
