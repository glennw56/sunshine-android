extends Object
class_name MenuProps
## Real Godot .glb menu props in assets/models/menu_props/ (3D Models, textured
## with Sunshine photos). Filenames are prop_<item>.glb. Until a mesh exists,
## that slot shows photo-textured low-poly food — not cartoon drink tiles.

const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const DIR := "res://assets/models/menu_props/"
const TEX_WOOD := "res://assets/foss/wood.jpg"
const PHOTO_FALLBACK := "res://assets/generated/menu/square_coffee.jpg"
const PICNIC_Y := 0.83
const BISTRO_Y := 0.775
const GROUND_Y := 0.07


static func place(world: Node3D) -> int:
	var slots: Array[Dictionary] = _patio_slots()
	var paths: Array = []
	for p in _scan_glbs():
		paths.append(p)
	paths.sort_custom(_path_less)
	var count := 0
	for path in paths:
		var extra := ImportedModelsLib.instantiate_if_real(str(path))
		if extra == null:
			continue
		var slot: Dictionary = slots[count % slots.size()]
		var pos: Vector3 = slot["pos"]
		if count >= slots.size():
			pos += Vector3(0.22 * float(count / slots.size()), 0.0, 0.0)
		_mount(world, extra, pos, float(slot["yaw"]) + 0.05 * float(count))
		count += 1
	if count == 0:
		_photo_food(world, "coffee", PHOTO_FALLBACK, Vector3(0.48, BISTRO_Y, -0.22), 0.0)
		count = 1
	return count


static func _path_less(a: String, b: String) -> bool:
	var ra := _rank(_stem(a.get_file().get_basename()))
	var rb := _rank(_stem(b.get_file().get_basename()))
	if ra == rb:
		return a < b
	return ra < rb


static func _rank(stem: String) -> int:
	if _is_drink(stem):
		return 0
	if stem.contains("croissant"):
		return 1
	if stem.contains("danish") or stem.contains("bloom"):
		return 2
	if stem.contains("bread") or stem.contains("sourdough") or stem.contains("muffin"):
		return 3
	if stem.contains("entremet") or stem.contains("cake") or stem.contains("bento") or stem.contains("tart"):
		return 4
	if stem.contains("roll"):
		return 5
	if stem.contains("cookie"):
		return 6
	if stem.contains("macaron"):
		return 7
	return 5


static func _add_ring(out: Array[Dictionary], origin: Vector3, offsets: Array[Vector3]) -> void:
	for o in offsets:
		out.append({"pos": origin + o, "yaw": o.x * 0.45 + o.z * 0.2})


static func _patio_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Center bistro first so drinks land here (off the spawn walk).
	_add_ring(out, Vector3(0.0, BISTRO_Y, -0.45), [
		Vector3(0.42, 0, -0.18), Vector3(0.48, 0, -0.62),
		Vector3(0.38, 0, 0.22), Vector3(-0.42, 0, -0.18),
	])
	var bistro_off: Array[Vector3] = [
		Vector3(-0.28, 0, 0.28), Vector3(0.28, 0, 0.28),
		Vector3(-0.32, 0, -0.22), Vector3(0.08, 0, -0.35),
		Vector3(-0.18, 0, 0.08), Vector3(0.32, 0, 0.05),
	]
	for t in [
		Vector3(-4.8, BISTRO_Y, 0.8), Vector3(4.8, BISTRO_Y, 0.8),
		Vector3(-4.7, BISTRO_Y, -2.75), Vector3(4.7, BISTRO_Y, -2.75),
	]:
		_add_ring(out, t, bistro_off)
	var picnic_off: Array[Vector3] = [
		Vector3(-0.55, 0, 0.22), Vector3(0.55, 0, 0.22),
		Vector3(-0.55, 0, -0.22), Vector3(0.55, 0, -0.22),
		Vector3(-0.75, 0, 0.08), Vector3(0.75, 0, 0.08),
		Vector3(-0.28, 0, 0.28), Vector3(0.28, 0, -0.28),
	]
	for t in [
		Vector3(-4.8, PICNIC_Y, 3.9), Vector3(4.8, PICNIC_Y, 3.9),
		Vector3(0.0, PICNIC_Y, -4.7),
	]:
		_add_ring(out, t, picnic_off)
	for g in [
		Vector3(-5.85, GROUND_Y, 5.72), Vector3(1.85, GROUND_Y, 6.15),
		Vector3(-6.3, GROUND_Y, 3.2), Vector3(6.3, GROUND_Y, 3.2),
		Vector3(-6.4, GROUND_Y, 0.6), Vector3(6.4, GROUND_Y, 0.6),
		Vector3(-6.2, GROUND_Y, -2.6), Vector3(6.2, GROUND_Y, -2.6),
		Vector3(-3.4, GROUND_Y, -5.9), Vector3(3.4, GROUND_Y, -5.9),
		Vector3(-2.55, GROUND_Y, 6.45), Vector3(3.2, GROUND_Y, 6.4),
	]:
		out.append({"pos": g, "yaw": 0.2})
	return out


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
