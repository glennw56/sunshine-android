extends Node3D
class_name BakeryWorld
## ChatGPT Godot bakery GLB is the walkable storefront. Cube lot is fallback only.
## Facade faces −Z; player walks +Z from the street. Screen-right is world −X.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const ImportedModelsLib := preload("res://scripts/explore/imported_models.gd")
const LOGO_DISC := "res://assets/branding/sunshine-logo-disc.png"
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"
const STOREFRONT_GLB := "res://assets/models/Sunshines_Bakery_Storefront_Godot4.glb"
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
		_build_staff()
		_spawn_collectibles()
		return
	_build_concept_backdrop()
	_build_ground()
	_build_front_yard()
	_build_bakery()
	_build_green_cottage()
	_build_deck()
	_build_trees()
	_build_staff()
	_spawn_collectibles()


func _attach_chatgpt_storefront() -> bool:
	var node := ImportedModelsLib.instantiate_if_real(STOREFRONT_GLB)
	if node == null:
		return false
	node.name = "ChatGPTStorefront"
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO
	node.scale = Vector3.ONE
	add_child(node)
	return true


func _tune_mesh_lighting() -> void:
	## GLB albedos are already bright; the cube-lot sun washes them to white.
	for child in get_children():
		if child is DirectionalLight3D:
			(child as DirectionalLight3D).light_energy *= 0.52
		var env_node := child as WorldEnvironment
		if env_node and env_node.environment:
			env_node.environment.ambient_light_energy = 0.26
			env_node.environment.tonemap_exposure = 0.7


func _build_mesh_lot_colliders() -> void:
	## Visual ground is the GLB; this floor is the walkable lawn (ENV meshes have no physics).
	VoxelKit.add_collider(self, Vector3(32.0, 0.4, 26.0), Vector3(0.0, -0.2, 0.5))
	# Bakery hull with a photo-right (−X) door hole so you can walk in.
	VoxelKit.add_collider(self, Vector3(12.0, 7.2, 0.5), Vector3(0.0, 3.6, 0.05))
	VoxelKit.add_collider(self, Vector3(12.0, 7.2, 0.45), Vector3(0.0, 3.6, 8.12))
	VoxelKit.add_collider(self, Vector3(0.42, 7.2, 8.2), Vector3(5.9, 3.6, 4.1))
	VoxelKit.add_collider(self, Vector3(0.42, 7.2, 0.95), Vector3(-5.9, 3.6, 0.28))
	VoxelKit.add_collider(self, Vector3(0.42, 7.2, 5.9), Vector3(-5.9, 3.6, 5.2))
	VoxelKit.add_collider(self, Vector3(0.42, 3.9, 1.4), Vector3(-5.9, 5.25, 1.35))
	# Neighbor cottage so you walk around it. Mailbox/ramp/tables are the GLB mesh.
	VoxelKit.add_collider(self, Vector3(7.1, 5.2, 7.4), Vector3(-11.0, 2.6, 4.85))
	VoxelKit.add_collider(self, Vector3(1.3, 2.3, 0.95), Vector3(-9.65, 1.15, -5.45))


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
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.15
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
	# Sun behind the camera so the facade is lit like the sidewalk photo.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 172, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 1.22
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.72
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
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


func _villager(pos: Vector3, robe: Color, rot_y: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	root.add_to_group("village_npc")
	add_child(root)
	VoxelKit.add_box(root, Vector3(0.55, 1.0, 0.34), Vector3(0, 0.72, 0), VoxelKit.flat(robe), false)
	VoxelKit.add_box(root, Vector3(0.46, 0.46, 0.46), Vector3(0, 1.42, 0), VoxelKit.flat(Color("e6c8a0")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(-0.2, 0.28, 0), VoxelKit.flat(Color("3a2416")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(0.2, 0.28, 0), VoxelKit.flat(Color("3a2416")), false)


func _build_staff() -> void:
	_villager(Vector3(-2.15, 0, 4.15), ROBE_BROWN, 2.6)
	_villager(Vector3(1.55, 0, 4.45), ROBE_GREEN, 3.5)
	_villager(Vector3(0.1, 0, 5.85), ROBE_WINE, 3.2)


func _spawn_collectibles() -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector3(-1.15, 0.55, 3.25), "kind": "croissant"},
		{"pos": Vector3(1.05, 0.5, 2.85), "kind": "croissant"},
		{"pos": Vector3(0.15, 0.52, 4.15), "kind": "drink"},
	]
	for row in spots:
		_place_pickup(row["pos"], str(row["kind"]), false)
	if GameSave.is_fresh_batch_active():
		_place_pickup(Vector3(-1.55, 0.55, 4.45), "croissant", true)
		_place_pickup(Vector3(-2.45, 0.55, -6.15), "drink", true)


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
