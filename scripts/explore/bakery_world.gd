extends Node3D
class_name BakeryWorld
## Low-poly stand-in for Sunshine's Bakery at 2231 1st Ave S, Irondale AL:
## small 1-story shop on 1st Ave, outdoor tables out front, porch out back,
## railroad across the street. Swap real photos later via STOREFRONT_PHOTO.

const STOREFRONT_PHOTO := ""  # later: drop a ≤1-year storefront shot in assets/reference/
const INTERIOR_PHOTO := ""

var _player: PlayerExplorer


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_lot()
	_build_shop()
	_build_interior()
	_build_logo_and_mascot()
	_spawn_collectibles()


func _tex_mat(path: String, color: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.uv1_scale = Vector3(4, 4, 4)
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.roughness = 0.85
	return m


func _static_box(size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = mat
	body.add_child(mesh_i)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("b8d4e8")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("fff1dc")
	we.ambient_light_energy = 0.55
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("ffe6b8")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)


func _build_lot() -> void:
	var asphalt := _tex_mat("res://assets/generated/asphalt.png")
	var sidewalk := _tex_mat("res://assets/generated/sidewalk.png", Color("ddd8d0"))
	var grass := _tex_mat("res://assets/generated/grass.png")
	var wood := _tex_mat("res://assets/generated/wood.png")
	# 1st Ave S in front of the shop (negative Z)
	_static_box(Vector3(40, 0.1, 10), Vector3(0, -0.05, -10), asphalt)
	_static_box(Vector3(40, 0.12, 3.2), Vector3(0, 0.0, -4.2), sidewalk)
	_static_box(Vector3(40, 0.1, 18), Vector3(0, -0.06, 8), grass)
	# Neighbor buildings
	_static_box(Vector3(8, 5, 8), Vector3(-12, 2.5, 3), _tex_mat("res://assets/generated/brick.png"))
	_static_box(Vector3(7, 4.2, 7), Vector3(12.5, 2.1, 2.5), _tex_mat("res://assets/generated/plaster.png", Color("efe4d4")))
	# Railroad across 1st Ave (Irondale tracks)
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color("3a3a40")
	_static_box(Vector3(40, 0.12, 0.12), Vector3(0, 0.08, -14.2), rail)
	_static_box(Vector3(40, 0.12, 0.12), Vector3(0, 0.08, -14.8), rail)
	for i in 16:
		_static_box(Vector3(0.18, 0.08, 1.1), Vector3(-18 + i * 2.4, 0.04, -14.5), wood)
	# Outdoor bistro tables (reviews: seating out front)
	for x in [-2.4, 0.0, 2.4]:
		_static_box(Vector3(0.9, 0.08, 0.9), Vector3(x, 0.72, -2.4), wood)
		_static_box(Vector3(0.12, 0.72, 0.12), Vector3(x, 0.36, -2.4), wood)


func _build_shop() -> void:
	var plaster := _tex_mat("res://assets/generated/plaster.png", Color("f3e6d4"))
	var brick := _tex_mat("res://assets/generated/brick.png")
	var awning := _tex_mat("res://assets/generated/awning.png")
	awning.uv1_scale = Vector3(2, 1, 1)
	var wood := _tex_mat("res://assets/generated/wood.png")
	# Main volume ~12m x 8m x 4.2m — small Irondale storefront
	_static_box(Vector3(12.2, 4.2, 8.0), Vector3(0, 2.1, 2.2), plaster)
	_static_box(Vector3(12.4, 0.35, 8.2), Vector3(0, 4.3, 2.2), brick)
	# Door opening: a darker inset
	_static_box(Vector3(1.4, 2.4, 0.2), Vector3(0, 1.2, -1.85), _mat_color(Color("4a2c2a")))
	# Display windows
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.75, 0.85, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	_static_box(Vector3(3.2, 2.0, 0.12), Vector3(-3.2, 1.8, -1.82), glass)
	_static_box(Vector3(3.2, 2.0, 0.12), Vector3(3.2, 1.8, -1.82), glass)
	# Rose/cream awning
	_static_box(Vector3(8.5, 0.12, 1.8), Vector3(0, 3.15, -2.4), awning)
	# Back porch (reviews: covered porch seating out back)
	_static_box(Vector3(6.0, 0.15, 3.5), Vector3(0, 0.2, 7.4), wood)
	_static_box(Vector3(6.2, 0.12, 3.6), Vector3(0, 2.6, 7.4), wood)
	_static_box(Vector3(0.15, 2.4, 0.15), Vector3(-2.8, 1.3, 6.0), wood)
	_static_box(Vector3(0.15, 2.4, 0.15), Vector3(2.8, 1.3, 6.0), wood)
	_static_box(Vector3(0.15, 2.4, 0.15), Vector3(-2.8, 1.3, 8.8), wood)
	_static_box(Vector3(0.15, 2.4, 0.15), Vector3(2.8, 1.3, 8.8), wood)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, -1.5)
	lamp.light_color = Color("ffd7a8")
	lamp.light_energy = 1.4
	lamp.omni_range = 8
	add_child(lamp)
	var addr := Label3D.new()
	addr.text = "2231 1ST AVE S  ·  IRONDALE"
	addr.font_size = 28
	addr.position = Vector3(0, 3.55, -1.9)
	addr.modulate = Color("4a2c2a")
	add_child(addr)
	if STOREFRONT_PHOTO != "" and ResourceLoader.exists(STOREFRONT_PHOTO):
		var photo := _tex_mat(STOREFRONT_PHOTO)
		photo.uv1_scale = Vector3.ONE
		_static_box(Vector3(4.0, 2.4, 0.04), Vector3(0, 1.8, -1.88), photo)


func _build_interior() -> void:
	var tile := _tex_mat("res://assets/generated/tile.png")
	tile.uv1_scale = Vector3(6, 6, 6)
	var wood := _tex_mat("res://assets/generated/wood.png")
	# Floor inside (thin, sits on ground)
	_static_box(Vector3(11.4, 0.08, 7.2), Vector3(0, 0.08, 2.2), tile)
	# Counter / pastry case
	_static_box(Vector3(5.5, 1.1, 0.8), Vector3(-1.2, 0.7, 0.4), wood)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 0.9, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_static_box(Vector3(5.4, 0.7, 0.6), Vector3(-1.2, 1.45, 0.4), glass)
	# Drink station
	_static_box(Vector3(1.4, 1.2, 0.7), Vector3(3.4, 0.7, 0.5), _mat_color(Color("3d2a28")))
	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 3.2, 2.2)
	interior.light_color = Color("ffe6c8")
	interior.light_energy = 1.6
	interior.omni_range = 10
	add_child(interior)
	if INTERIOR_PHOTO != "" and ResourceLoader.exists(INTERIOR_PHOTO):
		var photo := _tex_mat(INTERIOR_PHOTO)
		photo.uv1_scale = Vector3.ONE
		_static_box(Vector3(3.5, 2.2, 0.04), Vector3(0, 2.0, 5.9), photo)


func _mat_color(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


func _build_logo_and_mascot() -> void:
	# Pixel-perfect circular mark on the facade (the reference JPEG).
	var sign := SunshineMascot.new()
	sign.show_emblem = true
	sign.show_girl = false
	sign.position = Vector3(0, 3.55, -1.98)
	sign.scale = Vector3(0.72, 0.72, 0.72)
	add_child(sign)
	# Walk-up 3D chibi matching that girl (glasses, hat, sunflower, pink top).
	var greeter := SunshineMascot.new()
	greeter.show_emblem = false
	greeter.show_girl = true
	greeter.position = Vector3(3.35, 0.0, -2.55)
	greeter.rotation_degrees.y = 18
	add_child(greeter)


func _spawn_collectibles() -> void:
	var spots: Array[Vector3] = [
		Vector3(-2.4, 0.95, -2.4),
		Vector3(0.0, 0.95, -2.4),
		Vector3(2.4, 0.95, -2.4),
		Vector3(-4.5, 0.4, -3.5),
		Vector3(4.2, 0.4, -3.2),
		Vector3(-1.8, 1.9, 0.4),
		Vector3(0.2, 1.9, 0.4),
		Vector3(3.4, 1.5, 0.5),
		Vector3(-2.0, 0.5, 7.2),
		Vector3(1.6, 0.5, 7.6),
		Vector3(5.5, 0.4, -1.0),
		Vector3(-6.0, 0.4, -1.2),
	]
	spots.shuffle()
	for i in spots.size():
		var item := CollectiblePickup.new()
		item.kind = "croissant" if i % 2 == 0 else "drink"
		item.position = spots[i]
		item.collected.connect(_on_collected)
		add_child(item)


func _on_collected(kind: String) -> void:
	var hud := get_tree().get_first_node_in_group("explore_hud")
	if hud and hud.has_method("on_collected"):
		hud.on_collected(kind)
