extends Object
class_name MenuProps
## Patio meshes live in assets/models/menu_props/ as prop_<stem>.glb.
## Which mesh is shown comes from the live Square catalog (item id or name),
## not a fixed menu. A missing mesh is a neutral plate — never another item.
## square_coffee.jpg is a specific drink photo and must not fill an empty slot.

const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const DIR := "res://assets/models/menu_props/"
const TEX_WOOD := "res://assets/foss/wood.jpg"
const PHOTO_FALLBACK := "res://assets/generated/menu/no_photo.png"
const PICNIC_Y := 0.83
const BISTRO_Y := 0.775
## Walk-distance display: ~2.35× authored size. Tiny cookies/macarons go higher.
const DISPLAY_SCALE := 2.35
const SMALL_SCALE := 2.85
## Shipped mesh stems. Runtime also scans the folder so a new prop_*.glb
## can match a catalog item without editing this list.
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
	var slots := _patio_slots()
	var matches := matched_catalog_props()
	var count := 0
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var node: Node3D = null
		if i < matches.size():
			node = _instance_glb(str(matches[i].get("stem", "")))
		if node == null:
			node = _neutral_prop()
		var scale := float(slot["scale"])
		if node != null and str(node.name).begins_with("NeutralMenu"):
			scale = DISPLAY_SCALE
		_mount(world, node, slot["pos"], float(slot["yaw"]), scale)
		count += 1
	return count


static func clear_placed(world: Node3D) -> void:
	var drop: Array[Node] = []
	for child in world.get_children():
		if child.is_in_group("menu_prop"):
			drop.append(child)
	for node in drop:
		if is_instance_valid(node):
			world.remove_child(node)
			node.free()


static func matched_catalog_props() -> Array[Dictionary]:
	## Catalog order. A mesh is used only when its stem matches that item's
	## Square id or normalized name. Unmatched items are not given another mesh.
	var stems := _mesh_stems()
	var out: Array[Dictionary] = []
	var used := {}
	var catalog: Array = []
	if OrderClient:
		catalog = OrderClient.drinks()
	for item in catalog:
		if not item is Dictionary:
			continue
		var stem := stem_for_item(item, stems)
		if stem == "" or used.has(stem):
			continue
		used[stem] = true
		out.append({
			"stem": stem,
			"name": str(item.get("name", "")),
			"id": str(item.get("id", "")),
			"category": OrderClient.item_ui_category(item),
		})
		if out.size() >= _patio_slots().size():
			break
	return out


static func stem_for_item(item: Dictionary, stems: Array[String] = []) -> String:
	var have := stems if not stems.is_empty() else _mesh_stems()
	var candidates: Array[String] = []
	for field in ["name", "square_name", "variation_name"]:
		var slug := name_stem(str(item.get(field, "")))
		if slug != "" and not candidates.has(slug):
			candidates.append(slug)
	for field in ["id", "item_id", "catalog_object_id", "square_id", "site_product_id"]:
		var raw := str(item.get(field, "")).strip_edges()
		if raw == "":
			continue
		if not candidates.has(raw):
			candidates.append(raw)
		var slug := name_stem(raw)
		if slug != "" and not candidates.has(slug):
			candidates.append(slug)
	for candidate in candidates:
		if candidate in have and _mesh_exists(candidate):
			return candidate
	return ""


static func name_stem(raw: String) -> String:
	var source := raw.strip_edges().to_lower()
	var out := ""
	var prev_us := false
	for i in source.length():
		var ch := source.substr(i, 1)
		var ok := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if ok:
			out += ch
			prev_us = false
		elif not prev_us and out != "":
			out += "_"
			prev_us = true
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	return out


static func holds_for_npc(index: int) -> Dictionary:
	var foods: Array[String] = []
	var sips: Array[String] = []
	for row in matched_catalog_props():
		var stem := str(row.get("stem", ""))
		if stem == "":
			continue
		if str(row.get("category", "")) == "drink":
			sips.append(stem)
		else:
			foods.append(stem)
	var pastry := foods[posmod(index, foods.size())] if not foods.is_empty() else ""
	var drink := sips[posmod(index, sips.size())] if not sips.is_empty() else ""
	return {"pastry": pastry, "drink": drink}


static func stem_for_kind(kind: String) -> String:
	var want_drink := kind == "drink"
	for row in matched_catalog_props():
		var is_drink := str(row.get("category", "")) == "drink"
		if is_drink == want_drink:
			return str(row.get("stem", ""))
	return ""


static func _mesh_stems() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("prop_") and file_name.ends_with(".glb"):
				var stem := file_name.trim_prefix("prop_").trim_suffix(".glb")
				if stem != "" and stem not in found:
					found.append(stem)
			file_name = dir.get_next()
		dir.list_dir_end()
	if found.is_empty():
		for stem in KEEP_STEMS:
			if _mesh_exists(stem):
				found.append(stem)
	return found


static func _mesh_exists(stem: String) -> bool:
	return ResourceLoader.exists(DIR + "prop_" + stem + ".glb") or ResourceLoader.exists(DIR + stem + ".glb")


static func _patio_slots() -> Array[Dictionary]:
	# Table positions only. The catalog chooses which mesh sits here.
	# Picnic north/east each hold a pair ~1.1 m apart so nothing stacks.
	# Spawn walk (x≈0, z>6) stays clear.
	return [
		{"pos": Vector3(-4.80, PICNIC_Y, 3.90), "yaw": 0.18, "scale": DISPLAY_SCALE},
		{"pos": Vector3(0.00, BISTRO_Y, -0.45), "yaw": 0.08, "scale": DISPLAY_SCALE},
		{"pos": Vector3(4.25, PICNIC_Y, 3.90), "yaw": -0.22, "scale": DISPLAY_SCALE},
		{"pos": Vector3(-0.55, PICNIC_Y, -4.70), "yaw": 0.55, "scale": DISPLAY_SCALE},
		{"pos": Vector3(0.55, PICNIC_Y, -4.70), "yaw": -0.40, "scale": DISPLAY_SCALE},
		{"pos": Vector3(4.70, BISTRO_Y, -2.75), "yaw": 0.30, "scale": DISPLAY_SCALE},
		{"pos": Vector3(4.80, BISTRO_Y, 0.80), "yaw": -0.15, "scale": SMALL_SCALE},
		{"pos": Vector3(-4.80, BISTRO_Y, 0.80), "yaw": 0.12, "scale": DISPLAY_SCALE},
		{"pos": Vector3(-4.70, BISTRO_Y, -2.75), "yaw": 0.48, "scale": DISPLAY_SCALE},
		{"pos": Vector3(5.35, PICNIC_Y, 3.90), "yaw": 0.35, "scale": SMALL_SCALE},
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


static func instantiate_cookie() -> Node3D:
	## Toss cookie uses a catalog item whose mesh stem says cookie.
	## Otherwise a plain disc — not another product's photo.
	var node := instantiate_named(_cookie_stem_from_catalog())
	if node:
		flatten_prop(node)
		return node
	return _cookie_fallback()


static func _cookie_stem_from_catalog() -> String:
	for row in matched_catalog_props():
		var stem := str(row.get("stem", ""))
		if stem.find("cookie") >= 0:
			return stem
	return ""


static func _neutral_prop() -> Node3D:
	var root := Node3D.new()
	root.name = "NeutralMenu"
	var plate := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.16
	cyl.height = 0.02
	cyl.radial_segments = 16
	plate.mesh = cyl
	plate.material_override = _wood_mat()
	plate.position = Vector3(0, 0.012, 0)
	root.add_child(plate)
	var disc := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.09
	top.bottom_radius = 0.09
	top.height = 0.015
	top.radial_segments = 14
	disc.mesh = top
	disc.material_override = _tex_mat(PHOTO_FALLBACK)
	disc.position = Vector3(0, 0.03, 0)
	root.add_child(disc)
	return root


static func _cookie_fallback() -> Node3D:
	var root := Node3D.new()
	root.name = "CookieFallback"
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.11
	cyl.bottom_radius = 0.11
	cyl.height = 0.04
	cyl.radial_segments = 16
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c4922a")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = mat
	disc.rotation.x = PI * 0.5
	root.add_child(disc)
	for i in 6:
		var chip := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.018
		ball.height = 0.024
		chip.mesh = ball
		var chip_mat := StandardMaterial3D.new()
		chip_mat.albedo_color = Color("3a2418")
		chip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chip.material_override = chip_mat
		var ang := float(i) * TAU / 6.0
		chip.position = Vector3(cos(ang) * 0.055, 0.02, sin(ang) * 0.055)
		root.add_child(chip)
	return root


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
