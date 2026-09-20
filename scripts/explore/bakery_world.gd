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
const LOGO_DISC := "res://assets/branding/sunshine-logo-disc.png"
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"
const STOREFRONT_GLB := "res://assets/models/sunshine_outdoor_eating.glb"
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


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	if _attach_chatgpt_storefront():
		_tune_mesh_lighting()
		_build_mesh_lot_colliders()
		_build_expanded_lot()
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
	MenuPropsLib.place(self)
	call_deferred("_spawn_staff")


func _spawn_staff() -> void:
	_build_staff()
	var shop := get_node_or_null("ChatGPTStorefront")
	if shop:
		call_deferred("_flatten_shop")


func _flatten_shop() -> void:
	var shop := get_node_or_null("ChatGPTStorefront")
	if shop:
		_flatten_glb_materials(shop)


func _attach_chatgpt_storefront() -> bool:
	var node := ImportedModelsLib.instantiate_if_real(STOREFRONT_GLB)
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
	for child in get_children():
		if child is DirectionalLight3D:
			(child as DirectionalLight3D).light_energy *= 0.82
		var env_node := child as WorldEnvironment
		if env_node and env_node.environment:
			env_node.environment.ambient_light_energy = 0.4
			env_node.environment.tonemap_exposure = 0.95


func _flatten_glb_materials(n: Node) -> void:
	## Keep authored albedo (grass, wood, blush, embedded Sunshine logo). Only force white when a PNG is bound.
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
				if src is BaseMaterial3D:
					var bm := src as BaseMaterial3D
					tex = bm.albedo_texture
					albedo = bm.albedo_color
					use_vertex = bm.vertex_color_use_as_albedo
				if tex != null:
					mat.albedo_texture = tex
					mat.albedo_color = Color.WHITE
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
				else:
					mat.albedo_color = albedo
					mat.vertex_color_use_as_albedo = use_vertex
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.metallic = 0.0
				mat.roughness = 1.0
				mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, mat)
	for child in n.get_children():
		_flatten_glb_materials(child)


func _build_mesh_lot_colliders() -> void:
	## Visual ground is the GLB Grass_Base (90×80 m); ENV meshes have no physics.
	## Hull furniture / logo wall / borders — not all 442 trimeshes.
	var shop := get_node_or_null("ChatGPTStorefront") as Node3D
	var grass := _named_aabb(shop, "Grass_Base")
	var floor_x := 90.0
	var floor_z := 80.0
	var floor_c := Vector3(0.0, -0.18, 0.0)
	if grass.size.x > 20.0 and grass.size.z > 20.0:
		floor_x = grass.size.x
		floor_z = grass.size.z
		floor_c = Vector3(grass.get_center().x, -0.18, grass.get_center().z)
	VoxelKit.add_collider(self, Vector3(floor_x, 0.8, floor_z), Vector3(floor_c.x, -0.38, floor_c.z))
	## 4× playable lawn around the authored 90×80 patio (180×160). Same ground height.
	VoxelKit.add_collider(self, Vector3(180.0, 0.8, 160.0), Vector3(0.0, -0.38, 20.0))
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
	_add_named_hull(shop, "NorthBorder")
	_add_named_hull(shop, "WestBorder")
	_add_named_hull(shop, "EastBorder")
	for i in 6:
		_add_named_hull(shop, "FlowerPlanter%02d" % i)
	for i in 4:
		_add_named_hull(shop, "LightPost%02d" % i)


func _build_expanded_lot() -> void:
	## Keep the authored patio; grow the walkable lawn to ~4× area with bakery rooms.
	_tbox(Vector3(180.0, 0.08, 160.0), Vector3(0.0, -0.04, 20.0), TEX_GRASS, Color("6db84a"), 10.0, false)
	_tbox(Vector3(18.0, 0.06, 3.2), Vector3(0.0, 0.03, 28.0), TEX_CONCRETE, Color("e4e0d6"), 2.4, false)
	_sign("Cookie practice", Vector3(0.0, 1.35, 32.5), 64, WINE, 180.0)
	_box(Vector3(0.9, 0.95, 0.9), Vector3(-4.2, 0.48, 34.0), WOOD_DK, true)
	_box(Vector3(0.9, 0.95, 0.9), Vector3(4.2, 0.48, 34.0), WOOD_DK, true)
	_box(Vector3(0.9, 0.95, 0.9), Vector3(0.0, 0.48, 37.2), WOOD, true)
	_sign("Pastry garden", Vector3(-48.0, 1.35, 8.0), 56, WINE, 90.0)
	for i in 5:
		_tbox(Vector3(2.2, 0.45, 2.2), Vector3(-42.0 - (i % 2) * 3.2, 0.22, 2.0 + i * 4.2), TEX_WOOD, WOOD, 1.2, true)
		_glow(Vector3(1.4, 0.35, 1.4), Vector3(-42.0 - (i % 2) * 3.2, 0.55, 2.0 + i * 4.2), PINK, 0.12, false)
	_sign("Picnic lawn", Vector3(48.0, 1.35, 8.0), 56, WINE, -90.0)
	_tbox(Vector3(3.6, 0.12, 1.6), Vector3(46.0, 0.08, 6.0), TEX_WOOD, WOOD, 1.4, true)
	_tbox(Vector3(3.6, 0.12, 1.6), Vector3(50.5, 0.08, 12.0), TEX_WOOD, WOOD, 1.4, true)
	_sign("Market path", Vector3(0.0, 1.45, -42.0), 56, WINE, 0.0)
	_tbox(Vector3(4.0, 0.07, 28.0), Vector3(0.0, 0.03, -28.0), TEX_CONCRETE, Color("e4e0d6"), 3.0, false)
	_tbox(Vector3(2.4, 1.6, 2.4), Vector3(-6.5, 0.8, -38.0), TEX_WOOD, WOOD_DK, 1.1, true)
	_tbox(Vector3(2.4, 1.6, 2.4), Vector3(6.5, 0.8, -38.0), TEX_WOOD, WOOD_DK, 1.1, true)


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
	_guest(Vector3(-6.6, 0.0, 6.35), 0.55, "staff", "dark", 0, Vector3.ZERO, "visor", "cinnamon_roll", "vietnamese_coffee")
	_guest(Vector3(-6.55, 0.0, 3.15), 1.15, "blush", "brown", 0, Vector3.ZERO, "bangs", "cream_cheese_danish", "fruit_tea")
	_guest(Vector3(6.55, 0.0, 3.15), -1.05, "cream", "wine", 0, Vector3.ZERO, "bun", "feta_spinach_danish", "")
	_guest(Vector3(1.85, 0.0, -5.55), 3.4, "wine", "dark", 0, Vector3.ZERO, "glasses", "nutella_croissant", "vietnamese_coffee")
	_guest(Vector3(-6.5, 0.0, -0.2), 1.25, "orange", "brown", 0, Vector3.ZERO, "pony", "", "fruit_tea")
	_guest(Vector3(6.5, 0.0, -0.35), -1.15, "blush", "wine", 0, Vector3.ZERO, "hat", "sausage_croissant", "vietnamese_coffee")
	_guest(Vector3(3.85, 0.0, -5.85), 0.2, "cream", "dark", 0, Vector3.ZERO, "bangs", "mango_entrement", "")
	_guest(Vector3(-16.5, 0.0, 14.0), 0.4, "wine", "brown", 2, Vector3(-16.5, 0.0, 6.5), "pony", "chocolate_chip_cookie", "fruit_tea")
	_guest(Vector3(18.0, 0.0, 4.5), -0.6, "blush", "dark", 2, Vector3(14.5, 0.0, -10.0), "hat", "birthday_cake_macaron", "")
	_guest(Vector3(-18.5, 0.0, -2.0), 1.1, "orange", "wine", 2, Vector3(-12.0, 0.0, 12.5), "bun", "cinnamon_roll", "vietnamese_coffee")
	_guest(Vector3(9.4, 0.0, 14.8), 3.5, "cream", "brown", 0, Vector3.ZERO, "glasses", "nutella_croissant", "fruit_tea")
	_guest(Vector3(-9.2, 0.0, 16.2), 2.8, "staff", "brown", 0, Vector3.ZERO, "visor", "", "vietnamese_coffee")
	_guest(Vector3(-8.6, 0.0, 10.2), 0.55, "blush", "brown", 0, Vector3.ZERO, "hat", "cream_cheese_danish", "")
	_guest(Vector3(8.4, 0.0, 9.8), -0.45, "wine", "dark", 0, Vector3.ZERO, "bangs", "feta_spinach_danish", "fruit_tea")
	_guest(Vector3(-22.0, 0.0, 12.0), 0.25, "cream", "wine", 2, Vector3(-8.0, 0.0, 18.0), "pixie", "sausage_croissant", "vietnamese_coffee")


func _spawn_collectibles() -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector3(-3.4, 0.55, 13.4), "kind": "croissant"},
		{"pos": Vector3(3.4, 0.55, 13.2), "kind": "croissant"},
		{"pos": Vector3(-2.2, 0.52, 16.6), "kind": "drink"},
	]
	for row in spots:
		_place_pickup(row["pos"], str(row["kind"]), false)
	if GameSave.is_fresh_batch_active():
		_place_pickup(Vector3(-5.4, 0.55, 15.1), "croissant", true)
		_place_pickup(Vector3(5.2, 0.55, 15.4), "drink", true)


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
