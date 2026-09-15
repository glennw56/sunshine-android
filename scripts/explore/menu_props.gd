extends Object
class_name MenuProps
## Ronald's 10 top-seller Godot .glb menu props in assets/models/menu_props/.
## Filenames are prop_<item>.glb. Until a mesh exists, that slot shows
## photo-textured low-poly food — not cartoon drink tiles.

const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const DIR := "res://assets/models/menu_props/"
const TEX_WOOD := "res://assets/foss/wood.jpg"
const PHOTO_FALLBACK := "res://assets/generated/menu/square_coffee.jpg"
const PICNIC_Y := 0.83
const BISTRO_Y := 0.775
## Walk-distance display: ~2.35× authored size. Tiny cookies/macarons go higher.
const DISPLAY_SCALE := 2.35
const SMALL_SCALE := 2.85

const KEEP_STEMS: Array[String] = [
	"cream_cheese_danish",
	"vietnamese_coffee",
	"feta_spinach_danish",
	"nutella_croissant",
	"sausage_croissant",
	"mango_entrement",
	"birthday_cake_macaron",
	"fruit_tea",
	"cinnamon_roll",
	"chocolate_chip_cookie",
]


static func place(world: Node3D) -> int:
	var count := 0
	for slot in _patio_slots():
		var stem := str(slot["stem"])
		if stem not in KEEP_STEMS:
			continue
		var extra := _instance_glb(stem)
		if extra == null:
			continue
		_mount(world, extra, slot["pos"], float(slot["yaw"]), float(slot["scale"]))
		count += 1
	if count == 0:
		_photo_food(world, "coffee", PHOTO_FALLBACK, Vector3(0.48, BISTRO_Y, -0.22), 0.0)
		count = 1
	return count


static func _patio_slots() -> Array[Dictionary]:
	# One item per table where possible. Picnic north/east each hold a pair
	# ~1.1 m apart so nothing stacks. Spawn walk (x≈0, z>6) stays clear.
	return [
		{
			"stem": "cream_cheese_danish",
			"pos": Vector3(-4.80, PICNIC_Y, 3.90),
			"yaw": 0.18,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "vietnamese_coffee",
			"pos": Vector3(0.00, BISTRO_Y, -0.45),
			"yaw": 0.08,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "feta_spinach_danish",
			"pos": Vector3(4.25, PICNIC_Y, 3.90),
			"yaw": -0.22,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "nutella_croissant",
			"pos": Vector3(-0.55, PICNIC_Y, -4.70),
			"yaw": 0.55,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "sausage_croissant",
			"pos": Vector3(0.55, PICNIC_Y, -4.70),
			"yaw": -0.40,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "mango_entrement",
			"pos": Vector3(4.70, BISTRO_Y, -2.75),
			"yaw": 0.30,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "birthday_cake_macaron",
			"pos": Vector3(4.80, BISTRO_Y, 0.80),
			"yaw": -0.15,
			"scale": SMALL_SCALE,
		},
		{
			"stem": "fruit_tea",
			"pos": Vector3(-4.80, BISTRO_Y, 0.80),
			"yaw": 0.12,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "cinnamon_roll",
			"pos": Vector3(-4.70, BISTRO_Y, -2.75),
			"yaw": 0.48,
			"scale": DISPLAY_SCALE,
		},
		{
			"stem": "chocolate_chip_cookie",
			"pos": Vector3(5.35, PICNIC_Y, 3.90),
			"yaw": 0.35,
			"scale": SMALL_SCALE,
		},
	]


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


static func _mount(world: Node3D, node: Node3D, pos: Vector3, yaw: float, scale: float) -> void:
	node.name = "MenuProp_" + str(node.name)
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3(scale, scale, scale)
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
	root.scale = Vector3(DISPLAY_SCALE, DISPLAY_SCALE, DISPLAY_SCALE)
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
