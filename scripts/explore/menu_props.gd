extends Object
class_name MenuProps
## Real Godot .glb menu props in assets/models/menu_props/ (3D Models, textured
## with Sunshine photos). Filenames are prop_<item>.glb. Until a mesh exists,
## that slot shows photo-textured low-poly food — not cartoon drink tiles.

const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const DIR := "res://assets/models/menu_props/"
const TEX_WOOD := "res://assets/foss/wood.jpg"
const PICNIC_Y := 0.83
const BISTRO_Y := 0.775
const GROUND_Y := 0.07

## Table / seating / ground slots. `glb` is the stem (with or without prop_).
const SLOTS: Array[Dictionary] = [
	{"id": "picnic_west_croissant", "glb": "croissant", "photo": "res://assets/generated/menu/croissant.png", "pos": Vector3(-4.35, PICNIC_Y, 3.72), "yaw": 0.4},
	{"id": "picnic_west_cookie", "glb": "croissant_cookie", "photo": "res://assets/generated/menu/croissant_cookie.png", "pos": Vector3(-5.22, PICNIC_Y, 4.08), "yaw": -0.35},
	{"id": "picnic_west_lemonade", "glb": "lemonade", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(-4.48, PICNIC_Y, 4.12), "yaw": 0.2},
	{"id": "picnic_east_almond", "glb": "croissant_almond", "photo": "res://assets/generated/menu/croissant_almond.png", "pos": Vector3(4.38, PICNIC_Y, 3.72), "yaw": -0.25},
	{"id": "picnic_east_roll", "glb": "roll", "photo": "res://assets/generated/menu/roll.png", "pos": Vector3(5.22, PICNIC_Y, 4.08), "yaw": 0.5},
	{"id": "picnic_east_fruit", "glb": "fruit_tea", "photo": "res://assets/generated/menu/square_fruit_tea.jpg", "pos": Vector3(4.5, PICNIC_Y, 4.12), "yaw": 0.1},
	{"id": "picnic_north_loaf", "glb": "loaf", "photo": "res://assets/generated/menu/loaf.png", "pos": Vector3(-0.48, PICNIC_Y, -4.52), "yaw": 0.15},
	{"id": "picnic_north_garlic", "glb": "loaf_garlic", "photo": "res://assets/generated/menu/loaf.png", "pos": Vector3(0.52, PICNIC_Y, -4.88), "yaw": -0.4},
	{"id": "picnic_north_milk", "glb": "milk_tea", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(0.38, PICNIC_Y, -4.42), "yaw": 0.0},
	{"id": "bistro_sw_savory", "glb": "savory", "photo": "res://assets/generated/menu/savory.png", "pos": Vector3(-5.08, BISTRO_Y, 0.98), "yaw": 0.3},
	{"id": "bistro_sw_bbq", "glb": "savory_bbq", "photo": "res://assets/generated/menu/savory.png", "pos": Vector3(-4.52, BISTRO_Y, 0.52), "yaw": -0.2},
	{"id": "bistro_sw_matcha", "glb": "matcha_latte", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(-4.98, BISTRO_Y, 0.52), "yaw": 0.15},
	{"id": "bistro_se_cajun", "glb": "savory_cajun", "photo": "res://assets/generated/menu/savory.png", "pos": Vector3(4.52, BISTRO_Y, 0.98), "yaw": -0.18},
	{"id": "bistro_se_fajita", "glb": "savory_fajita", "photo": "res://assets/generated/menu/savory.png", "pos": Vector3(5.08, BISTRO_Y, 0.52), "yaw": 0.22},
	{"id": "bistro_se_viet", "glb": "vietnamese_coffee", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(4.52, BISTRO_Y, 0.52), "yaw": 0.05},
	{"id": "bistro_nw_milk_loaf", "glb": "loaf_milk", "photo": "res://assets/generated/menu/loaf.png", "pos": Vector3(-4.98, BISTRO_Y, -2.52), "yaw": -0.28},
	{"id": "bistro_nw_rosemary", "glb": "loaf_rosemary", "photo": "res://assets/generated/menu/loaf.png", "pos": Vector3(-4.42, BISTRO_Y, -2.98), "yaw": 0.35},
	{"id": "bistro_ne_berry", "glb": "croissant_berry", "photo": "res://assets/generated/menu/croissant_berry.png", "pos": Vector3(4.42, BISTRO_Y, -2.52), "yaw": 0.18},
	{"id": "bistro_ne_pistachio", "glb": "croissant_pistachio", "photo": "res://assets/generated/menu/croissant.png", "pos": Vector3(4.98, BISTRO_Y, -2.98), "yaw": -0.22},
	{"id": "bistro_center_coffee", "glb": "coffee", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(0.48, BISTRO_Y, -0.22), "yaw": 0.0},
	{"id": "bistro_center_biscoff", "glb": "biscoff_coffee", "photo": "res://assets/generated/menu/square_biscoff.jpg", "pos": Vector3(0.52, BISTRO_Y, -0.72), "yaw": 0.25},
	{"id": "menu_board_water", "glb": "water", "photo": "res://assets/generated/menu/square_coffee.jpg", "pos": Vector3(-5.85, GROUND_Y, 5.72), "yaw": 0.35},
	{"id": "cornhole_mushroom", "glb": "savory_mushroom", "photo": "res://assets/generated/menu/savory.png", "pos": Vector3(1.15, GROUND_Y, 5.55), "yaw": 0.2},
]

const EXTRA_GROUND: Array[Vector3] = [
	Vector3(-3.35, GROUND_Y, 4.35),
	Vector3(3.35, GROUND_Y, 4.35),
	Vector3(-6.15, GROUND_Y, 2.4),
	Vector3(6.15, GROUND_Y, 2.4),
	Vector3(-3.5, GROUND_Y, -5.35),
	Vector3(3.5, GROUND_Y, -5.35),
]


static func place(world: Node3D) -> int:
	var used: Dictionary = {}
	var count := 0
	for slot in SLOTS:
		var stem := _stem(str(slot["glb"]))
		var node := _instance_glb(stem)
		if node:
			used[stem] = true
			_mount(world, node, slot["pos"], float(slot["yaw"]))
			count += 1
		else:
			_photo_food(world, stem, str(slot["photo"]), slot["pos"], float(slot["yaw"]))
			count += 1
	var extra_i := 0
	for path in _scan_glbs():
		var stem := _stem(path.get_file().get_basename())
		if used.has(stem):
			continue
		var extra := ImportedModelsLib.instantiate_if_real(path)
		if extra == null:
			continue
		var pos := EXTRA_GROUND[extra_i % EXTRA_GROUND.size()]
		if extra_i >= EXTRA_GROUND.size():
			pos += Vector3(float(extra_i / EXTRA_GROUND.size()) * 0.45, 0.0, 0.0)
		_mount(world, extra, pos, 0.12 * float(extra_i))
		used[stem] = true
		extra_i += 1
		count += 1
	return count


static func _stem(name: String) -> String:
	var s := name.strip_edges().to_lower()
	if s.begins_with("prop_"):
		s = s.substr(5)
	return s


static func _instance_glb(stem: String) -> Node3D:
	if stem.strip_edges() == "":
		return null
	var node := ImportedModelsLib.instantiate_if_real(DIR + "prop_" + stem + ".glb")
	if node:
		return node
	return ImportedModelsLib.instantiate_if_real(DIR + stem + ".glb")


static func instantiate_named(stem: String) -> Node3D:
	return _instance_glb(_stem(stem))


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
	_flatten(node)
	world.add_child(node)


static func flatten_prop(node: Node) -> void:
	_flatten(node)


static func _flatten(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				var mat := StandardMaterial3D.new()
				var tex: Texture2D = null
				var albedo := Color.WHITE
				if src is BaseMaterial3D:
					var bm := src as BaseMaterial3D
					tex = bm.albedo_texture
					albedo = bm.albedo_color
				if tex != null:
					mat.albedo_texture = tex
					mat.albedo_color = Color(1, 1, 1, albedo.a)
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
				else:
					mat.albedo_color = albedo
				if albedo.a < 0.99:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.metallic = 0.0
				mat.roughness = 1.0
				mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, mat)
	for child in n.get_children():
		_flatten(child)


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
	elif stem.begins_with("loaf"):
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.1, 0.14)
		food.mesh = box
		food.position = Vector3(0, 0.07, 0)
	elif stem.begins_with("savory"):
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
	return stem in [
		"coffee", "biscoff", "biscoff_coffee", "fruit_tea", "lemonade",
		"matcha_latte", "milk_tea", "vietnamese_coffee", "water",
	]
