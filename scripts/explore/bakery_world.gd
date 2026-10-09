extends Node3D
class_name BakeryWorld
## Y-up 3D Models outdoor eating patio is the walkable Explore world.
## Cube lot is fallback only. Identity transform — this mesh is already Godot Y-up.
## Do not apply the old v3/v4 Z-up Basis(−X, Z, Y). Do not instance chatgpt_shop_grass.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const PatioNpcScript := preload("res://scripts/explore/patio_npc.gd")
const MenuPropsLib := preload("res://scripts/explore/menu_props.gd")
const LogoSunScript := preload("res://scripts/explore/logo_sun.gd")
const LogoMoonScript := preload("res://scripts/explore/logo_moon.gd")
const CutePackLib := preload("res://scripts/explore/cute_pack.gd")
const HalloweenPackLib := preload("res://scripts/explore/halloween_pack.gd")
const PumpkinBinScript := preload("res://scripts/explore/pumpkin_bin.gd")
const PatioGhostsScript := preload("res://scripts/explore/patio_ghosts.gd")
const PatioPetsScript := preload("res://scripts/explore/patio_pets.gd")
const GraveyardScript := preload("res://scripts/explore/graveyard.gd")
const GiantPumpkinScript := preload("res://scripts/explore/giant_pumpkin.gd")
const PerimeterWallScript := preload("res://scripts/explore/perimeter_wall.gd")
const LOGO_DISC := "res://assets/branding/sunshine-logo-disc.png"
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"
const STOREFRONT_GLB := "res://assets/explore/sunshine_outdoor_eating_b1.glb"
## Test World only. Already 22.8 × 0.14 × 19.35 — do not scale it again.
const STOREFRONT_EXPAND_GLB := "res://assets/explore/sunshine_outdoor_eating_expand.glb"
## Test World only. Remade patio, already ~22 × 0.15 × 16. Do not scale it.
const STOREFRONT_P2_GLB := "res://assets/explore/sunshine_outdoor_eating_p2.glb"
const PHOTO_BORDERS_GLB := "res://assets/explore/photo_borders.glb"
## Square lot so photo borders at ±109.6 sit 0.4 m inside the edge.
const LOT_SIZE := 220.0
const BORDER_AT := 109.6
## Test world only. Horizontal deck scale about Patio_Island's center.
## Grass_Base, photo borders, and LogoWall stay put. Map Modeler handoff target.
const TEST_ISLAND_SCALE := 1.5
const TEST_GATHER_RADIUS := 3.6
const CONCEPT_HERO := "res://assets/explore/chatgpt_voxel_1.png"
const TEX_GRASS := "res://assets/foss/grass.jpg"
const TEX_LAWN := "res://assets/foss/grass_block.png"
const TEX_LEAF := "res://assets/foss/leaf_block.png"
const TEX_SIDING := "res://assets/foss/clapboard.png"
const TEX_WOOD := "res://assets/foss/wood.jpg"
const TEX_ASPHALT := "res://assets/foss/asphalt.jpg"
const TEX_CONCRETE := "res://assets/foss/concrete.jpg"
const TEX_PLASTER := "res://assets/foss/plaster.jpg"
const TEX_BARK := "res://assets/foss/bark.jpg"
const TEX_ROOF := "res://assets/foss/roof.jpg"
const TEX_METAL := "res://assets/foss/metal.jpg"

const WHITE := Color("f7f4ee")
const PINK := Color("e8b4b8")
const PINK_BRIGHT := Color("f3c4c8")
const WINE := Color("4a1c28")
const ORANGE := Color("e3922e")
const CONCRETE := Color("d8d4cc")
const WOOD := Color("e0c090")
const WOOD_DK := Color("c49a62")
const GREEN := Color("6db84a")
const GREEN_DK := Color("5aa03c")
const SHINGLE := Color("3a3834")
const LEAF := Color("2f6a2c")
const LEAF_DK := Color("245224")
const BARK := Color("4a2e18")
const BLACK := Color("161618")
const GLASS := Color("3a5864")
const GLASS_DK := Color("1a2428")
const PICNIC := Color("c5c8cc")
const NEON_OPEN := Color("7dff9c")
const ROBE_BROWN := Color("8b5a2b")
const ROBE_GREEN := Color("3d6b32")
const ROBE_WINE := Color("6b2d3c")

var _player: PlayerExplorer
var _front_z: float = 1.35
var _shop_w: float = 9.4
var _shop_h: float = 7.15
var _shop_d: float = 5.4
var _wall: float = 0.38
var _deck_y: float = 1.12
var _storefront_path := ""


func setup(player: PlayerExplorer) -> void:
	_player = player
	if get_viewport():
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_build_environment()
	if _attach_chatgpt_storefront():
		_tune_mesh_lighting()
		_expand_grass_base()
		if AppConfig.test_world:
			if _storefront_path == STOREFRONT_P2_GLB or _storefront_path == STOREFRONT_EXPAND_GLB:
				_mark_authored_island()
			else:
				_widen_test_island()
		_build_mesh_lot_colliders()
		if not AppConfig.test_world:
			_soften_authored_furniture()
		_build_expanded_lot()
		_attach_photo_borders()
		if AppConfig.test_world:
			_build_test_world_dressing()
		_spawn_collectibles()
		call_deferred("_spawn_life")
		return
	_build_concept_backdrop()
	_build_ground()
	_build_front_yard()
	_build_bakery()
	_build_green_cottage()
	_build_deck()
	_build_trees()
	_spawn_collectibles()
	call_deferred("_spawn_life")


func _spawn_life() -> void:
	if not OrderClient.menu_loaded.is_connected(_on_catalog_ready):
		OrderClient.menu_loaded.connect(_on_catalog_ready)
	_relayout_catalog_visuals(false)
	call_deferred("_spawn_staff")


func _on_catalog_ready(_payload: Dictionary) -> void:
	_relayout_catalog_visuals(true)


func _relayout_catalog_visuals(refresh_npcs: bool) -> void:
	MenuPropsLib.clear_placed(self)
	MenuPropsLib.place(self)
	_paint_welcome_sign()
	if not refresh_npcs:
		return
	for child in get_children():
		if child.is_in_group("village_npc") and child.has_method("refresh_holds"):
			child.refresh_holds()


const WELCOME_LINE := "Thanks for loading into Sunshine's World"
const WELCOME_LINES := "Thanks for\nloading into\nSunshine's World"
const WELCOME_FONT := "res://assets/fonts/Nunito-Variable.ttf"


func _paint_welcome_sign() -> void:
	## Same counter spot as the old live chalkboard. Names and prices stay off the map.
	var spoken := " ".join(WELCOME_LINES.replace("\n", " ").split(" ", false))
	if spoken != WELCOME_LINE:
		push_error("Welcome sign copy must stay: " + WELCOME_LINE)
	var stale := get_node_or_null("LiveMenuBoard")
	if stale:
		stale.queue_free()
	var existing := get_node_or_null("WelcomeSign")
	if existing:
		existing.queue_free()
	var root := Node3D.new()
	root.name = "WelcomeSign"
	root.position = Vector3(2.35, 0.0, 1.55)
	var post := MeshInstance3D.new()
	post.name = "Post"
	var pole := BoxMesh.new()
	pole.size = Vector3(0.1, 1.15, 0.1)
	post.mesh = pole
	post.material_override = _flat_mat(WOOD)
	post.position = Vector3(0, 0.58, -0.04)
	root.add_child(post)
	var board := MeshInstance3D.new()
	board.name = "Board"
	var quad := QuadMesh.new()
	quad.size = Vector2(3.05, 1.72)
	board.mesh = quad
	board.material_override = _welcome_board_mat()
	board.position = Vector3(0, 1.62, 0.0)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)
	_add_sunflower(root, Vector3(-1.18, 2.22, 0.06))
	var shadow := _welcome_label(Color(0.29, 0.11, 0.16, 0.38), 0)
	shadow.name = "WelcomeShadow"
	shadow.position = Vector3(0.03, 1.52, 0.04)
	root.add_child(shadow)
	var label := _welcome_label(WINE, 14)
	label.name = "WelcomeText"
	label.position = Vector3(0, 1.56, 0.07)
	root.add_child(label)
	add_child(root)


func _welcome_label(color: Color, outline: int) -> Label3D:
	var label := Label3D.new()
	label.text = WELCOME_LINES
	label.font = _welcome_font()
	label.font_size = 64
	label.pixel_size = 0.0047
	label.modulate = color
	label.outline_size = outline
	label.outline_modulate = Color("fff6ea")
	label.shaded = false
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return label


func _welcome_font() -> Font:
	var font := FontFile.new()
	if font.load_dynamic_font(WELCOME_FONT) == OK:
		return font
	return ThemeDB.fallback_font


func _welcome_board_mat() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, shadows_disabled;
float round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r, r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float wood_d = round_box(p, vec2(0.96, 0.94), 0.18);
	if (wood_d > 0.0) {
		discard;
	}
	vec3 wood = vec3(0.769, 0.604, 0.384);
	vec3 cream = vec3(1.0, 0.965, 0.918);
	vec3 blush = vec3(0.910, 0.706, 0.722);
	float cream_d = round_box(p, vec2(0.86, 0.82), 0.14);
	float blush_d = round_box(p, vec2(0.76, 0.70), 0.12);
	vec3 col = wood;
	if (cream_d < 0.0) {
		col = cream;
	}
	if (blush_d < 0.0) {
		col = blush;
	}
	float shade = smoothstep(-0.02, 0.22, -blush_d);
	col = mix(col * vec3(0.93, 0.88, 0.88), col, shade);
	ALBEDO = col;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _add_sunflower(parent: Node3D, pos: Vector3) -> void:
	var sun := Node3D.new()
	sun.name = "Sunflower"
	sun.position = pos
	var petal_mat := _flat_mat(Color("f2c14e"))
	for i in 8:
		var petal := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.09, 0.02)
		petal.mesh = box
		petal.material_override = petal_mat
		var ang := float(i) * TAU / 8.0
		petal.position = Vector3(cos(ang) * 0.16, sin(ang) * 0.16, 0.0)
		petal.rotation.z = ang
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sun.add_child(petal)
	var center := MeshInstance3D.new()
	center.name = "Center"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.03
	center.mesh = disc
	center.rotation.x = PI * 0.5
	center.position = Vector3(0, 0, 0.02)
	center.material_override = _flat_mat(Color("c47a2a"))
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.add_child(center)
	parent.add_child(sun)


func _flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _spawn_staff() -> void:
	_build_staff()
	var shop := get_node_or_null("ChatGPTStorefront")
	if shop:
		call_deferred("_flatten_shop")


func _flatten_shop() -> void:
	var shop := get_node_or_null("ChatGPTStorefront")
	if shop:
		_flatten_glb_materials(shop, AppConfig.test_world)


func _attach_chatgpt_storefront() -> bool:
	var path := STOREFRONT_GLB
	if AppConfig.test_world and ResourceLoader.exists(STOREFRONT_P2_GLB):
		path = STOREFRONT_P2_GLB
	elif AppConfig.test_world and ResourceLoader.exists(STOREFRONT_EXPAND_GLB):
		path = STOREFRONT_EXPAND_GLB
	_storefront_path = path
	var node := ImportedModelsLib.instantiate_if_real(path)
	if node == null:
		return false
	node.name = "ChatGPTStorefront"
	# Patio is already Godot Y-up. Logo wall at z ≈ −6.45 faces +Z (the seating).
	node.basis = Basis.IDENTITY
	node.position = Vector3.ZERO
	node.scale = Vector3.ONE
	add_child(node)
	return true


func _tune_mesh_lighting() -> void:
	## Lot materials are unshaded; keep staff cubes from blowing out under the street sun.
	## Test world night sets its own ambient. Do not lift it back to daytime.
	if AppConfig.test_world:
		for child in get_children():
			var env_node := child as WorldEnvironment
			if env_node and env_node.environment:
				env_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env_node.environment.ambient_light_color = Color("6e7c9a")
				env_node.environment.ambient_light_energy = 0.22
				env_node.environment.tonemap_exposure = 1.0
				env_node.environment.glow_enabled = false
				env_node.environment.ssao_enabled = false
		return
	for child in get_children():
		if child is DirectionalLight3D:
			(child as DirectionalLight3D).light_energy *= 0.82
		var env_node := child as WorldEnvironment
		if env_node and env_node.environment:
			env_node.environment.ambient_light_energy = 0.4
			env_node.environment.tonemap_exposure = 0.95


func _flatten_glb_materials(n: Node, night: bool = false) -> void:
	## Keep authored albedo (grass, wood, blush, embedded Sunshine logo). Only force white when a PNG is bound.
	if n is GeometryInstance3D and not (n as GeometryInstance3D).visible:
		return
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
				var use_vertex := false
				var transparency := BaseMaterial3D.TRANSPARENCY_DISABLED
				var alpha_scissor := 0.0
				if src is BaseMaterial3D:
					var bm := src as BaseMaterial3D
					tex = bm.albedo_texture
					albedo = bm.albedo_color
					use_vertex = bm.vertex_color_use_as_albedo
					transparency = bm.transparency
					alpha_scissor = bm.alpha_scissor_threshold
				if tex != null:
					mat.albedo_texture = tex
					mat.albedo_color = Color.WHITE
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					mat.vertex_color_use_as_albedo = use_vertex
					mat.transparency = transparency
					mat.alpha_scissor_threshold = alpha_scissor
				else:
					mat.albedo_color = albedo
					mat.vertex_color_use_as_albedo = use_vertex
				var gate_glow := src != null and str(src.resource_name) == "M_grand_gate_glow"
				if night and not gate_glow:
					mat.albedo_color *= Color(0.56, 0.62, 0.76)
				if gate_glow:
					mat.emission_enabled = true
					mat.emission = Color("ff8a28")
					mat.emission_energy_multiplier = 1.6
					if mat.albedo_texture:
						mat.emission_texture = mat.albedo_texture
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.metallic = 0.0
				mat.roughness = 1.0
				mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, mat)
	for child in n.get_children():
		_flatten_glb_materials(child, night)


func _mark_authored_island() -> void:
	## The expand GLB is already the 1.5× island. Scaling it again would
	## push the patio to ~34 m and fight the photo border.
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	var box := _named_aabb(shop, "Patio_Island")
	set_meta("test_island_authored", true)
	set_meta("test_island_after", box.size)
	set_meta("test_island_center", box.get_center())
	print("TEST WORLD authored island after=", box.size, " center=", box.get_center())


func _widen_test_island() -> void:
	## 1.5× walkable deck in XZ. Seating moves out with the island so the
	## middle stays a toss gather. Logo wall, grass, and the photo rim do not scale.
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	if shop == null:
		return
	var before := _named_aabb(shop, "Patio_Island")
	var pivot := before.get_center() if before.size.length() > 0.2 else Vector3.ZERO
	pivot.y = 0.0
	var targets: Array[Node3D] = []
	_collect_scale_targets(shop, targets)
	var roots: Array[Node3D] = []
	for n in targets:
		var nested := false
		for other in targets:
			if other != n and other.is_ancestor_of(n):
				nested = true
				break
		if not nested:
			roots.append(n)
	for n in roots:
		_scale_node_xz_about_center(n, pivot, TEST_ISLAND_SCALE)
	_clear_test_gather(shop, pivot, TEST_GATHER_RADIUS)
	var after := _named_aabb(shop, "Patio_Island")
	set_meta("test_island_before", before.size)
	set_meta("test_island_after", after.size)
	set_meta("test_island_center", after.get_center())
	print("TEST WORLD island scale=", TEST_ISLAND_SCALE, " before=", before.size, " after=", after.size, " center=", after.get_center())


func _collect_scale_targets(n: Node, into: Array[Node3D]) -> void:
	if _is_island_scale_target(str(n.name)) and n is Node3D:
		into.append(n as Node3D)
	for child in n.get_children():
		_collect_scale_targets(child, into)


func _is_island_scale_target(mesh_name: String) -> bool:
	if mesh_name == "Grass_Base" or mesh_name.begins_with("Logo"):
		return false
	if mesh_name == "Patio_Island" or mesh_name == "Menu_Board" or mesh_name == "Trash_Can":
		return true
	if mesh_name == "NorthBorder" or mesh_name == "WestBorder" or mesh_name == "EastBorder":
		return true
	for prefix in ["Picnic_", "Bistro_", "Cornhole_", "Beanbag", "FlowerPlanter", "LightPost"]:
		if mesh_name.begins_with(prefix):
			return true
	return false


func _scale_node_xz_about_center(node: Node3D, pivot: Vector3, scale_xz: float) -> void:
	var before := _union_mesh_aabb(node)
	if before.size.length() < 0.05:
		return
	var center := before.get_center()
	node.scale = Vector3(node.scale.x * scale_xz, node.scale.y, node.scale.z * scale_xz)
	var after := _union_mesh_aabb(node)
	var want := Vector3(
		pivot.x + (center.x - pivot.x) * scale_xz,
		center.y,
		pivot.z + (center.z - pivot.z) * scale_xz
	)
	var delta := want - after.get_center()
	delta.y = 0.0
	node.global_position += delta


func _clear_test_gather(shop: Node3D, pivot: Vector3, radius: float) -> void:
	## Keep a ~7 m circle in the middle of the deck clear for tosses.
	var stack: Array = [shop]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mesh_name := str(n.name)
		var seating := (
			mesh_name.begins_with("Picnic")
			or mesh_name.begins_with("Bistro")
			or mesh_name.begins_with("Beanbag")
			or mesh_name.begins_with("Cornhole")
			or mesh_name == "Menu_Board"
			or mesh_name == "Trash_Can"
		)
		if seating and n is Node3D:
			var box := _union_mesh_aabb(n)
			if box.size.length() > 0.05:
				var center := box.get_center()
				var flat := Vector2(center.x - pivot.x, center.z - pivot.z)
				if flat.length() < radius:
					if flat.length() < 0.15:
						flat = Vector2(0.0, 1.0)
					var target := flat.normalized() * (radius + 0.45)
					var delta := Vector3(pivot.x + target.x - center.x, 0.0, pivot.z + target.y - center.z)
					(n as Node3D).global_position += delta
		for child in n.get_children():
			stack.append(child)


func _build_test_world_dressing() -> void:
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	var island := _named_aabb(shop, "Patio_Island")
	HalloweenPackLib.dress(self, island)
	for pocket in ["HW_NorthLawn", "HW_WestCorner", "HW_DiscoFringe"]:
		var pocket_node := get_node_or_null(pocket)
		if pocket_node:
			_flatten_glb_materials(pocket_node, true)
	var bin: Node3D = PumpkinBinScript.new()
	add_child(bin)
	bin.call("build", Vector3(8.0, 0.0, 31.0))
	_flatten_glb_materials(bin, true)
	var ghosts: Node3D = PatioGhostsScript.new()
	add_child(ghosts)
	var pets: Node3D = PatioPetsScript.new()
	add_child(pets)
	var yard: Node3D = GraveyardScript.new()
	add_child(yard)
	var giant: Node3D = GiantPumpkinScript.new()
	add_child(giant)
	add_child(PerimeterWallScript.new())


func _expand_grass_base() -> void:
	## Absolute 220×220 on the patio grass plane. Do not scale again if it is already there.
	## Patio furniture stays put — only Grass_Base grows so the far borders line up.
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	var grass := _find_named(shop, "Grass_Base") as Node3D
	if grass == null:
		return
	var box := _named_aabb(shop, "Grass_Base")
	if box.size.x < 20.0 or box.size.z < 20.0:
		return
	if box.size.x > 200.0 and box.size.z > 200.0:
		return
	grass.scale.x *= LOT_SIZE / box.size.x
	grass.scale.z *= LOT_SIZE / box.size.z


func _attach_photo_borders() -> void:
	## World rim only. Patio low fence stays on the storefront (cute-pack stand-in).
	var node := ImportedModelsLib.instantiate_if_real(PHOTO_BORDERS_GLB)
	if node == null:
		return
	node.name = "PhotoBorders"
	node.basis = Basis.IDENTITY
	node.position = Vector3.ZERO
	node.scale = Vector3.ONE
	add_child(node)
	node.add_to_group("photo_borders")
	var height := 1.45
	var y := height * 0.5
	var length := 218.84
	var depth := 0.36
	_border_wall(Vector3(length, height, depth), Vector3(0.0, y, -BORDER_AT))
	_border_wall(Vector3(length, height, depth), Vector3(0.0, y, BORDER_AT))
	_border_wall(Vector3(depth, height, length), Vector3(-BORDER_AT, y, 0.0))
	_border_wall(Vector3(depth, height, length), Vector3(BORDER_AT, y, 0.0))
	var post := 0.36
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_border_wall(Vector3(post, height + 0.18, post), Vector3(sx * BORDER_AT, y, sz * BORDER_AT))


func _border_wall(size: Vector3, pos: Vector3) -> void:
	var body := VoxelKit.add_collider(self, size, pos)
	body.name = "PhotoBorderCol"
	body.add_to_group("photo_border_col")


func _build_mesh_lot_colliders() -> void:
	## Visual ground is Grass_Base after the 220×220 expand. ENV meshes have no physics.
	## Hull furniture / logo wall / patio low fence — not the photo rim (that has its own boxes).
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	var grass := _named_aabb(shop, "Grass_Base")
	var floor_x := LOT_SIZE
	var floor_z := LOT_SIZE
	var floor_c := Vector3(0.0, -0.18, 0.0)
	if grass.size.x > 20.0 and grass.size.z > 20.0:
		floor_x = grass.size.x
		floor_z = grass.size.z
		floor_c = Vector3(grass.get_center().x, -0.18, grass.get_center().z)
	VoxelKit.add_collider(self, Vector3(floor_x, 0.8, floor_z), Vector3(floor_c.x, -0.38, floor_c.z))
	var island := _named_aabb(shop, "Patio_Island")
	if island.size.length() > 0.2:
		var ic := island.get_center()
		VoxelKit.add_collider(self, Vector3(island.size.x, 0.16, island.size.z), Vector3(ic.x, 0.02, ic.z))
	_add_named_hull(shop, "LogoWall")
	_add_named_hull(shop, "Picnic_West")
	_add_named_hull(shop, "Picnic_East")
	_add_named_hull(shop, "Picnic_North")
	_add_named_hull(shop, "Bistro_SW")
	_add_named_hull(shop, "Bistro_SE")
	_add_named_hull(shop, "Bistro_NW")
	_add_named_hull(shop, "Bistro_NE")
	_add_named_hull(shop, "Bistro_Center")
	_add_named_hull(shop, "Menu_Board")
	_add_named_hull(shop, "Trash_Can")
	_add_named_hull(shop, "Cornhole_A")
	_add_named_hull(shop, "Cornhole_B")
	_add_named_hull(shop, "Beanbag00")
	_add_named_hull(shop, "Beanbag01")
	_add_named_hull(shop, "Beanbag02")
	_add_named_hull(shop, "NorthBorder")
	_add_named_hull(shop, "WestBorder")
	_add_named_hull(shop, "EastBorder")
	for i in 6:
		_add_named_hull(shop, "FlowerPlanter%02d" % i)
	for i in 4:
		_add_named_hull(shop, "LightPost%02d" % i)
	_add_named_hull(shop, "Bistro_W2")
	_add_named_hull(shop, "Bistro_W3")
	_add_named_hull(shop, "Bistro_E2")
	_add_named_hull(shop, "Bistro_E3")
	_add_named_hull(shop, "Picnic_SW2")
	_add_named_hull(shop, "Picnic_SE2")
	_add_named_hull(shop, "Bench_W")
	_add_named_hull(shop, "Bench_E")
	_add_named_hull(shop, "Bench_Logo")


func _soften_authored_furniture() -> void:
	## Hide faceted GLB furniture and drop rounded cute-pack stand-ins on the same footprints.
	## Keep Grass_Base, LogoWall, and the island mesh (logo + lawn stay authored).
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	if shop == null:
		return
	var names: PackedStringArray = [
		"Picnic_West", "Picnic_East", "Picnic_North",
		"Bistro_SW", "Bistro_SE", "Bistro_NW", "Bistro_NE", "Bistro_Center",
		"Menu_Board", "Trash_Can", "Cornhole_A", "Cornhole_B",
		"Beanbag00", "Beanbag01", "Beanbag02",
		"NorthBorder", "WestBorder", "EastBorder",
	]
	for i in 6:
		names.append("FlowerPlanter%02d" % i)
	for i in 4:
		names.append("LightPost%02d" % i)
	for mesh_name in names:
		var box := _named_aabb(shop, mesh_name)
		if box.size.length() <= 0.2:
			continue
		var node := _find_named(shop, mesh_name)
		if node:
			_hide_visuals(node)
			node.queue_free()
		CutePackLib.replace_named(self, mesh_name, box)
	_strip_leftover_grids(shop)
	for p in [Vector3(-3.4, 0.0, 8.0), Vector3(-3.4, 0.0, 2.2), Vector3(-3.4, 0.0, -3.2), Vector3(3.4, 0.0, -3.2)]:
		CutePackLib.planter(self, p, WOOD, PINK)


func _hide_visuals(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visible = false
	for child in n.get_children():
		_hide_visuals(child)


func _strip_leftover_grids(shop: Node3D) -> void:
	## Authored paver joints and walkway chips stay boxy in the default camera.
	var drop: Array[Node] = []
	var stack: Array = [shop]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nm := str(n.name)
		if nm.begins_with("Walkway_Detail") or nm.begins_with("Paver_Joint") or nm.begins_with("PostCap") or nm.begins_with("Menu_Chalk") or nm.begins_with("MenuFrame") or nm.begins_with("MenuPanel") or nm.begins_with("MenuLeg"):
			drop.append(n)
			continue
		for child in n.get_children():
			stack.append(child)
	for n in drop:
		if is_instance_valid(n):
			n.queue_free()


func _build_expanded_lot() -> void:
	## B1 grass plane is the lawn. Props stay on the patio; the 220 slab is Grass_Base.
	CutePackLib.paver_lane(self, Vector3(0.0, 0.0, 28.0), Vector3(1, 0, 0), 8, 2.15)
	_sign("Cookie practice", Vector3(0.0, 1.35, 32.5), 64, WINE, 180.0)
	var practice_west := CutePackLib.practice_target(self, Vector3(-4.2, 0.0, 34.0), WOOD_DK)
	practice_west.name = "PracticeTargetWest"
	var practice_east := CutePackLib.practice_target(self, Vector3(4.2, 0.0, 34.0), WOOD_DK)
	practice_east.name = "PracticeTargetEast"
	var practice_north := CutePackLib.practice_target(self, Vector3(0.0, 0.0, 37.2), WOOD)
	practice_north.name = "PracticeTargetNorth"
	## Small disc on the eating patio, just east of the right picnic table.
	## Face is 0.14 m at about 10 ft (y 3.05). It stays live so another cookie can hit it again.
	var bullseye := preload("res://scripts/explore/disco_bullseye.gd").new()
	bullseye.position = Vector3(4.35, 0.0, -2.4)
	add_child(bullseye)
	## Party zone lives on the open grass beside this disc (see DiscoParty.ZONE).
	var party := preload("res://scripts/explore/disco_party.gd").new()
	add_child(party)
	_sign("Pastry garden", Vector3(-48.0, 1.35, 8.0), 56, WINE, 90.0)
	for i in 5:
		CutePackLib.planter(self, Vector3(-42.0 - (i % 2) * 3.2, 0.0, 2.0 + i * 4.2), WOOD, PINK)
	_sign("Picnic lawn", Vector3(48.0, 1.35, 8.0), 56, WINE, -90.0)
	CutePackLib.picnic_table(self, Vector3(46.0, 0.0, 6.0))
	CutePackLib.picnic_table(self, Vector3(50.5, 0.0, 12.0))
	_sign("Market path", Vector3(0.0, 1.45, -42.0), 56, WINE, 0.0)
	CutePackLib.paver_lane(self, Vector3(0.0, 0.0, -28.0), Vector3(0, 0, 1), 10, 2.35)
	CutePackLib.market_stall(self, Vector3(-6.5, 0.0, -38.0), WOOD_DK)
	CutePackLib.market_stall(self, Vector3(6.5, 0.0, -38.0), WOOD_DK)
	var trees: Array[Vector3] = [
		Vector3(-28.0, 0.0, 18.0), Vector3(28.0, 0.0, 16.0),
		Vector3(-22.0, 0.0, -18.0), Vector3(24.0, 0.0, -16.0),
		Vector3(-38.0, 0.0, 28.0), Vector3(36.0, 0.0, 24.0),
		Vector3(-12.0, 0.0, 42.0), Vector3(14.0, 0.0, 40.0),
	]
	for p in trees:
		CutePackLib.shade_tree(self, p, 3.0 + absf(p.x) * 0.02)


func _add_named_hull(shop: Node3D, mesh_name: String) -> bool:
	var box := _named_aabb(shop, mesh_name)
	if box.size.length() <= 0.2:
		return false
	## Thin authored walls need a walkable thickness. Drop the hull to the lawn
	## so you cannot walk under a floating tabletop or logo board.
	var sz := box.size
	var center := box.get_center()
	sz.x = maxf(sz.x, 0.5)
	sz.z = maxf(sz.z, 0.5)
	var top := center.y + sz.y * 0.5
	var bottom := minf(center.y - sz.y * 0.5, 0.0)
	sz.y = maxf(top - bottom, 0.5)
	center.y = (top + bottom) * 0.5
	VoxelKit.add_collider(self, sz, center)
	return true


func _named_aabb(root: Node, node_name: String) -> AABB:
	var n := _find_named(root, node_name)
	if n == null:
		return AABB()
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		return mi.global_transform * mi.get_aabb()
	return _union_mesh_aabb(n)


func _find_named(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name) == node_name:
			return n
		for child in n.get_children():
			stack.append(child)
	return null


func _union_mesh_aabb(n: Node) -> AABB:
	var box := AABB()
	var any := false
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var piece := mi.global_transform * mi.get_aabb()
			if not any:
				box = piece
				any = true
			else:
				box = box.merge(piece)
		for child in cur.get_children():
			stack.append(child)
	return box if any else AABB()


func _mat(c: Color, glow: float = 0.0) -> StandardMaterial3D:
	return VoxelKit.flat(c, false, glow)


func _tex(path: String, color: Color = Color.WHITE, uv: float = 2.0, nearest: bool = false) -> StandardMaterial3D:
	var use := path
	if not ResourceLoader.exists(path):
		if path == TEX_LAWN or path == TEX_LEAF:
			use = TEX_GRASS
		elif path == TEX_SIDING:
			use = TEX_PLASTER
	return VoxelKit.tex(use, color, uv, nearest)


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_y: float = 0.0, rot_x: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _mat(color), collide, rot_y, rot_x)


func _glow(size: Vector3, pos: Vector3, color: Color, glow: float = 0.28, collide: bool = false) -> Node3D:
	return VoxelKit.add_box(self, size, pos, VoxelKit.accent(color, glow), collide)


func _tbox(
	size: Vector3,
	pos: Vector3,
	path: String,
	color: Color = Color.WHITE,
	uv: float = 2.0,
	collide: bool = true,
	rot_y: float = 0.0,
	rot_x: float = 0.0,
	nearest: bool = false
) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _tex(path, color, uv, nearest), collide, rot_y, rot_x)


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0, px: float = 0.005) -> Label3D:
	return VoxelKit.add_sign(self, text, pos, font_size, color, rot_y_deg, px)


func _build_environment() -> void:
	if AppConfig.test_world:
		_build_night_environment()
		return
	var env := WorldEnvironment.new()
	var we := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d8fe0")
	sky_mat.sky_horizon_color = Color("c8e4f8")
	sky_mat.ground_bottom_color = Color("4a7a32")
	sky_mat.ground_horizon_color = Color("7cb85a")
	sky_mat.sun_angle_max = 0.0
	sky_mat.sun_curve = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	we.background_mode = Environment.BG_SKY
	we.sky = sky
	we.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	we.ambient_light_energy = 0.48
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.tonemap_exposure = 1.02
	we.ssao_enabled = false
	we.glow_enabled = false
	env.environment = we
	add_child(env)
	var logo_sun = LogoSunScript.new()
	logo_sun.name = "LogoSun"
	add_child(logo_sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 40, 0)
	fill.light_color = Color("c8d8f0")
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)


func _build_night_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("070b18")
	sky_mat.sky_horizon_color = Color("1a2744")
	sky_mat.ground_bottom_color = Color("0c1018")
	sky_mat.ground_horizon_color = Color("1a2744")
	sky_mat.sun_angle_max = 0.0
	sky_mat.sun_curve = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	we.background_mode = Environment.BG_SKY
	we.sky = sky
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("6e7c9a")
	we.ambient_light_energy = 0.22
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.tonemap_exposure = 1.0
	we.ssao_enabled = false
	we.glow_enabled = false
	env.environment = we
	add_child(env)
	add_child(LogoMoonScript.new())
	var fill := DirectionalLight3D.new()
	fill.name = "PlayerFill"
	fill.rotation_degrees = Vector3(-35, 160, 0)
	fill.light_color = Color("d7e2f4")
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)


func _build_concept_backdrop() -> void:
	## ChatGPT voxel street still sits behind the walkable shop (not the main-menu photo).
	var tex := load(CONCEPT_HERO) as Texture2D
	if tex == null:
		return
	var spr := Sprite3D.new()
	spr.name = "ConceptBackdrop"
	spr.texture = tex
	spr.pixel_size = 0.04
	spr.position = Vector3(0.12, 8.95, 16.8)
	spr.rotation_degrees.y = 180.0
	spr.shaded = false
	spr.double_sided = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spr)
	# Yard-sign billboard so the full still is in-world, not only peeking over the roof.
	var board := Sprite3D.new()
	board.name = "ConceptBillboard"
	board.texture = tex
	board.pixel_size = 0.00315
	board.position = Vector3(6.95, 2.22, -8.35)
	board.rotation_degrees.y = 208.0
	board.shaded = false
	board.double_sided = true
	board.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(board)
	_tbox(Vector3(4.18, 2.48, 0.1), Vector3(6.95, 2.22, -8.22), TEX_WOOD, WOOD_DK, 1.2, false, deg_to_rad(28.0))
	_tbox(Vector3(0.12, 2.15, 0.12), Vector3(6.55, 1.08, -8.55), TEX_WOOD, WOOD_DK, 0.6, true)
	_tbox(Vector3(0.12, 2.15, 0.12), Vector3(7.35, 1.08, -8.15), TEX_WOOD, WOOD_DK, 0.6, true)


func _build_ground() -> void:
	# One lawn slab — pixel-block grass, not a speckled photogrammetry carpet.
	_tbox(Vector3(46, 0.46, 36), Vector3(0.15, -0.22, 1.2), TEX_LAWN, Color("9ed06a"), 6.2, true, 0.0, 0.0, true)
	_tbox(Vector3(46, 0.28, 36), Vector3(0.15, -0.62, 1.2), TEX_CONCRETE, Color("7a5a38"), 6.0, false)
	# Street is a thin strip behind the sidewalk, not in the hero lawn.
	_tbox(Vector3(22, 0.1, 2.2), Vector3(0.1, 0.04, -13.85), TEX_ASPHALT, Color("6a6a6e"), 2.2, false)
	# Visual sidewalk + storm drain only — grass is the walkable floor so the curb is not a wall.
	_tbox(Vector3(16, 0.08, 2.35), Vector3(0.05, 0.06, -12.15), TEX_CONCRETE, Color("eae6dc"), 2.2, false)
	_tbox(Vector3(16, 0.12, 0.22), Vector3(0.05, 0.1, -10.95), TEX_CONCRETE, Color("d8d4cc"), 1.4, false)
	_tbox(Vector3(1.22, 0.05, 0.56), Vector3(0.06, 0.12, -12.05), TEX_METAL, Color("3a3c40"), 0.7, false)
	# Center walk to the trash / facade (visual only — grass is the floor).
	_tbox(Vector3(1.18, 0.08, 11.2), Vector3(0.04, 0.05, -5.4), TEX_CONCRETE, Color("e4e0d6"), 2.8, false)


func _build_front_yard() -> void:
	# ChatGPT still: two gray picnic tables on the lawn, trash on the walk, mailbox photo-right.
	_picnic(Vector3(2.55, 0, -3.85))
	_picnic(Vector3(-1.85, 0, -3.7))
	_trash(Vector3(0.04, 0, -1.05))
	_mailbox(Vector3(-6.35, 0, -8.85))
	# Little sandwich board by the left window.
	_tbox(Vector3(0.42, 0.7, 0.08), Vector3(2.85, 0.42, 0.55), TEX_WOOD, WOOD, 0.8, false, 0.18)


func _picnic(pos: Vector3) -> void:
	_tbox(Vector3(1.92, 0.08, 0.78), pos + Vector3(0, 0.78, 0), TEX_METAL, PICNIC, 1.1, false)
	_tbox(Vector3(0.08, 0.74, 0.08), pos + Vector3(0, 0.37, 0), TEX_METAL, Color("2a2c2e"), 0.6, false)
	_tbox(Vector3(1.7, 0.07, 0.22), pos + Vector3(0, 0.45, -0.68), TEX_METAL, PICNIC, 0.9, false)
	_tbox(Vector3(1.7, 0.07, 0.22), pos + Vector3(0, 0.45, 0.68), TEX_METAL, PICNIC, 0.9, false)
	_tbox(Vector3(0.07, 0.42, 0.07), pos + Vector3(-0.72, 0.22, -0.68), TEX_METAL, Color("2a2c2e"), 0.5, false)
	_tbox(Vector3(0.07, 0.42, 0.07), pos + Vector3(0.72, 0.22, -0.68), TEX_METAL, Color("2a2c2e"), 0.5, false)
	_tbox(Vector3(0.07, 0.42, 0.07), pos + Vector3(-0.72, 0.22, 0.68), TEX_METAL, Color("2a2c2e"), 0.5, false)
	_tbox(Vector3(0.07, 0.42, 0.07), pos + Vector3(0.72, 0.22, 0.68), TEX_METAL, Color("2a2c2e"), 0.5, false)


func _trash(pos: Vector3) -> void:
	_tbox(Vector3(0.42, 0.92, 0.42), pos + Vector3(0, 0.48, 0), TEX_METAL, Color("9aa0a6"), 0.9)
	_tbox(Vector3(0.48, 0.08, 0.48), pos + Vector3(0, 0.94, 0), TEX_METAL, Color("5c6064"), 0.7, false)


func _mailbox(pos: Vector3) -> void:
	_tbox(Vector3(0.18, 1.15, 0.18), pos + Vector3(0, 0.58, 0), TEX_METAL, BLACK, 0.6)
	_tbox(Vector3(0.72, 0.58, 0.42), pos + Vector3(0, 1.42, 0), TEX_METAL, BLACK, 0.7)
	_sign("X", pos + Vector3(0, 1.42, -0.24), 42, Color("f4f4f6"), 180, 0.006)


func _build_bakery() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := fz + d
	var cz := fz + d * 0.5
	var cx := 0.12
	# Invisible hull so the hero facade stays white + pink, but you cannot walk through it.
	VoxelKit.add_collider(self, Vector3(w - 0.02, h, 0.34), Vector3(cx, h * 0.5, fz + 0.12))
	# Photo-right / back / photo-left walls. Walk-in hole on photo-left side (+X).
	_tbox(Vector3(t, h, d), Vector3(cx - w * 0.5 + t * 0.5, h * 0.5, cz), TEX_PLASTER, WHITE, 2.0)
	_tbox(Vector3(t, h, 1.7), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, fz + 0.88), TEX_PLASTER, WHITE, 1.8)
	_tbox(Vector3(t, h, 1.45), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, rz - 0.75), TEX_PLASTER, WHITE, 1.8)
	_tbox(Vector3(t, 2.4, 1.4), Vector3(cx + w * 0.5 - t * 0.5, h - 1.2, cz + 0.1), TEX_PLASTER, WHITE, 1.6)
	_tbox(Vector3(w, h, t), Vector3(cx, h * 0.5, rz - t * 0.5), TEX_PLASTER, WHITE, 2.0)
	_box(Vector3(0.08, 2.15, 1.02), Vector3(cx + w * 0.5 + 0.02, 1.1, cz + 0.1), Color("3a3a3e"), false)
	# Smooth Minecraft-white facade (ChatGPT still), not photo clapboard grooves.
	_tbox(Vector3(w - 0.02, h - 0.12, 0.22), Vector3(cx, (h - 0.12) * 0.5, fz - 0.04), TEX_PLASTER, Color("fbf8f3"), 0.35, false)
	# Thick blush roof cap + corner posts like the voxel still.
	_glow(Vector3(w + 0.42, 0.62, 0.55), Vector3(cx, h + 0.08, fz - 0.08), PINK_BRIGHT)
	_glow(Vector3(w + 0.55, 0.34, d + 0.55), Vector3(cx, h + 0.28, cz), PINK_BRIGHT)
	_glow(Vector3(0.42, h + 0.28, 0.42), Vector3(cx - w * 0.5, h * 0.5 + 0.08, fz - 0.04), PINK_BRIGHT, 0.0, true)
	_glow(Vector3(0.42, h + 0.28, 0.42), Vector3(cx + w * 0.5, h * 0.5 + 0.08, fz - 0.04), PINK_BRIGHT, 0.0, true)
	# OPEN neon + cups on photo-left; darker window photo-right; stacked 2231.
	_window(Vector3(cx + 2.18, 2.05, fz), false)
	_window(Vector3(cx - 2.08, 2.05, fz), true)
	_sign("OPEN", Vector3(cx + 2.18, 2.22, fz - 0.3), 36, NEON_OPEN, 180, 0.007)
	_sign("☕  ☕", Vector3(cx + 2.18, 1.62, fz - 0.28), 28, Color("fff6ea"), 180, 0.006)
	_sign("2\n2\n3\n1", Vector3(cx - 4.28, 2.15, fz - 0.18), 40, Color("2e2e32"), 180, 0.007)
	_glow(Vector3(5.55, 0.95, 0.28), Vector3(cx, 4.72, fz - 0.22), ORANGE)
	_sign("SUNSHINE'S BAKERY", Vector3(cx, 4.74, fz - 0.38), 72, WINE, 180, 0.0074)
	_logo_disc(Vector3(cx, 6.05, fz - 0.18))
	_tbox(Vector3(w - t * 2.2, 0.08, d - 0.85), Vector3(cx, 0.06, cz), TEX_WOOD, Color("eadfc8"), 2.8, false)
	_tbox(Vector3(3.05, 1.02, 0.72), Vector3(cx, 0.56, rz - 1.2), TEX_WOOD, Color("5a3a22"), 1.4)
	VoxelKit.add_box(self, Vector3(2.7, 0.5, 0.36), Vector3(cx, 1.28, rz - 1.24), VoxelKit.glass(GLASS), false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, 3.2, cz)
	lamp.light_color = Color("ffe6c0")
	lamp.light_energy = 0.7
	lamp.omni_range = 8
	add_child(lamp)


func _logo_disc(pos: Vector3) -> void:
	var sprite := Sprite3D.new()
	var path := LOGO_DISC if ResourceLoader.exists(LOGO_DISC) else LOGO_GIRL
	sprite.texture = load(path) as Texture2D
	sprite.pixel_size = 0.00172
	sprite.position = pos
	sprite.rotation_degrees.y = 180
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	# Cream backing disc so the circle pops off the white panel.
	_glow(Vector3(1.35, 1.35, 0.05), pos + Vector3(0, 0, 0.06), Color("f3e2c4"), 0.1)


func _window(pos: Vector3, dark: bool) -> void:
	_glow(Vector3(2.05, 1.58, 0.18), pos + Vector3(0, 0, -0.04), PINK)
	VoxelKit.add_box(
		self,
		Vector3(1.62, 1.18, 0.1),
		pos + Vector3(0, 0, -0.14),
		VoxelKit.glass(GLASS_DK if dark else GLASS, dark),
		false
	)
	_box(Vector3(0.08, 1.12, 0.04), pos + Vector3(0, 0, -0.16), Color("d8e0e4"), false)
	_box(Vector3(1.56, 0.08, 0.04), pos + Vector3(0, 0, -0.16), Color("d8e0e4"), false)


func _build_green_cottage() -> void:
	var o := Vector3(-9.15, 0, 2.15)
	_tbox(Vector3(5.55, 4.85, 4.35), o + Vector3(0, 2.45, 0), TEX_PLASTER, Color("4e8c3c"), 0.4)
	_tbox(Vector3(5.85, 0.32, 4.65), o + Vector3(0, 5.02, 0), TEX_ROOF, Color("3d6e30"), 0.8, false)
	_box(Vector3(0.86, 0.86, 0.08), o + Vector3(1.35, 3.15, -2.2), WHITE, false)
	VoxelKit.add_box(self, Vector3(0.6, 0.6, 0.06), o + Vector3(1.35, 3.15, -2.26), VoxelKit.glass(GLASS), false)
	_box(Vector3(0.78, 1.55, 0.1), o + Vector3(-1.45, 0.92, -2.2), Color("6b3d22"), false)


func _build_deck() -> void:
	var rx := -5.85
	_tbox(Vector3(2.35, 0.14, 6.5), Vector3(rx, 0.55, 0.15), TEX_WOOD, WOOD, 2.6, true, 0.0, deg_to_rad(-10.5))
	for i in 14:
		_tbox(
			Vector3(2.2, 0.04, 0.16),
			Vector3(rx, 0.18 + i * 0.07, -2.65 + i * 0.42),
			TEX_WOOD,
			WOOD_DK,
			1.6,
			false,
			0.0,
			deg_to_rad(-10.5)
		)
	_tbox(Vector3(0.1, 1.02, 6.3), Vector3(rx + 1.18, 0.98, 0.15), TEX_WOOD, WOOD, 2.0, true, 0.0, deg_to_rad(-10.5))
	_tbox(Vector3(0.1, 1.02, 6.3), Vector3(rx - 1.18, 0.98, 0.15), TEX_WOOD, WOOD, 2.0, true, 0.0, deg_to_rad(-10.5))
	_tbox(Vector3(3.5, 0.16, 2.65), Vector3(-7.7, _deck_y, 2.85), TEX_WOOD, WOOD, 1.8)
	_tbox(Vector3(3.4, 0.9, 0.1), Vector3(-7.7, _deck_y + 0.52, 1.55), TEX_WOOD, WOOD, 1.4, false)
	_tbox(Vector3(0.1, 0.9, 2.5), Vector3(-6.05, _deck_y + 0.52, 2.85), TEX_WOOD, WOOD, 1.4, false)


func _build_trees() -> void:
	var xs := [-14.0, -11.2, -8.4, -5.5, -2.6, 0.2, 3.0, 5.8, 8.6, 11.5]
	for i in xs.size():
		_tree(Vector3(xs[i], 0, 7.15 + float(i % 3) * 0.5), 5.4 + float(i % 4) * 0.32)
	# Cube canopy behind the roof, matching the ChatGPT street still.
	_tree(Vector3(-2.6, 0, 8.2), 7.6)
	_tree(Vector3(0.15, 0, 8.55), 8.1)
	_tree(Vector3(2.7, 0, 8.15), 7.4)
	_tree(Vector3(-1.15, 0, 9.15), 7.2)
	_tree(Vector3(1.4, 0, 9.05), 7.0)
	_tree(Vector3(-3.8, 0, 8.6), 6.6)
	_tree(Vector3(-13.2, 0, 2.55), 4.6)
	_tree(Vector3(11.2, 0, 2.9), 4.4)
	_tree(Vector3(-10.4, 0, 4.2), 5.0)


func _tree(pos: Vector3, height: float) -> void:
	_tbox(Vector3(0.58, height * 0.48, 0.58), pos + Vector3(0, height * 0.24, 0), TEX_BARK, BARK, 1.1, false)
	_tbox(Vector3(2.85, 2.45, 2.85), pos + Vector3(0, height * 0.66, 0), TEX_LEAF, Color("3a7a34"), 1.6, false, 0.0, 0.0, true)
	_tbox(Vector3(1.95, 1.55, 1.95), pos + Vector3(0.28, height * 0.92, 0.12), TEX_LEAF, Color("2f6230"), 1.3, false, 0.0, 0.0, true)


func _guest(
	pos: Vector3,
	yaw: float,
	outfit: String,
	hair: String,
	pose: int,
	stroll_to: Vector3 = Vector3.ZERO,
	look: String = "bangs",
	pastry: String = "",
	drink: String = ""
) -> void:
	var npc = PatioNpcScript.new()
	npc.outfit = outfit
	npc.hair = hair
	npc.pose = pose
	npc.look = look
	npc.pastry_stem = pastry
	npc.drink_stem = drink
	npc.position = pos
	npc.rotation.y = yaw
	npc.waypoint_b = stroll_to
	add_child(npc)


func _build_staff() -> void:
	# Everyone stands on grass/patio ground (not tabletops). Keep spawn axis (x≈0, z>6) clear.
	## Hands pick a live catalog mesh (or a neutral plate). No fixed pastry list.
	_guest(Vector3(-6.6, 0.0, 6.35), 0.55, "staff", "dark", 0, Vector3.ZERO, "visor")
	_guest(Vector3(-6.55, 0.0, 3.15), 1.15, "blush", "brown", 0, Vector3.ZERO, "bangs")
	_guest(Vector3(6.55, 0.0, 3.15), -1.05, "cream", "wine", 0, Vector3.ZERO, "bun")
	_guest(Vector3(1.85, 0.0, -5.55), 3.4, "wine", "dark", 0, Vector3.ZERO, "glasses")
	_guest(Vector3(-6.5, 0.0, -0.2), 1.25, "orange", "brown", 0, Vector3.ZERO, "pony")
	_guest(Vector3(6.5, 0.0, -0.35), -1.15, "blush", "wine", 0, Vector3.ZERO, "hat")
	_guest(Vector3(3.85, 0.0, -5.85), 0.2, "cream", "dark", 0, Vector3.ZERO, "bangs")
	_guest(Vector3(-16.5, 0.0, 14.0), 0.4, "wine", "brown", 2, Vector3(-16.5, 0.0, 6.5), "pony")
	_guest(Vector3(18.0, 0.0, 4.5), -0.6, "blush", "dark", 2, Vector3(14.5, 0.0, -10.0), "hat")
	_guest(Vector3(-18.5, 0.0, -2.0), 1.1, "orange", "wine", 2, Vector3(-12.0, 0.0, 12.5), "bun")
	_guest(Vector3(9.4, 0.0, 14.8), 3.5, "cream", "brown", 0, Vector3.ZERO, "glasses")
	_guest(Vector3(-9.2, 0.0, 16.2), 2.8, "staff", "brown", 0, Vector3.ZERO, "visor")
	_guest(Vector3(-8.6, 0.0, 10.2), 0.55, "blush", "brown", 0, Vector3.ZERO, "hat")
	_guest(Vector3(8.4, 0.0, 9.8), -0.45, "wine", "dark", 0, Vector3.ZERO, "bangs")
	_guest(Vector3(-22.0, 0.0, 12.0), 0.25, "cream", "wine", 2, Vector3(-8.0, 0.0, 18.0), "pixie")


func _spawn_collectibles() -> void:
	## Seeded scatter across the lawn. Same layout every visit, not three fixed spots.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	var kinds: PackedStringArray = PackedStringArray(["croissant", "drink", "croissant"])
	var placed: Array[Vector3] = []
	var guard := 0
	while placed.size() < 12 and guard < 80:
		guard += 1
		var x := rng.randf_range(-34.0, 34.0)
		var z := rng.randf_range(-6.0, 50.0)
		if absf(x) < 3.4 and z > 6.0 and z < 18.5:
			continue
		if z > 30.5 and z < 39.5 and absf(x) < 8.0:
			continue
		if absf(x - 4.35) < 1.4 and absf(z + 2.4) < 1.4:
			continue
		var pos := Vector3(x, 0.54, z)
		var crowded := false
		for other in placed:
			if other.distance_to(pos) < 4.6:
				crowded = true
				break
		if crowded:
			continue
		placed.append(pos)
		_place_pickup(pos, kinds[placed.size() % kinds.size()])


func _place_pickup(pos: Vector3, kind: String) -> void:
	var item := CollectiblePickup.new()
	item.kind = kind
	item.position = pos
	item.collected.connect(_on_collected)
	add_child(item)


func _on_collected(kind: String) -> void:
	var hud := get_tree().get_first_node_in_group("explore_hud")
	if hud and hud.has_method("on_collected"):
		hud.on_collected(kind)
