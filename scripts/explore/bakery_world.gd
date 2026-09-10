extends Node3D
class_name BakeryWorld
## Low-poly Sunshine's Bakery from branding photos:
## front = sunshine-bakery-exterior-2231.jpg (white clapboard, pink trim, girl logo).
## rear = sunshine-bakery-backyard-good.jpg (grass, dark tables, fence, trees, lattice deck).
## Circular mark is sunshine-logo-girl.jpg.

const STOREFRONT_PHOTO := "res://assets/branding/sunshine-bakery-exterior-2231.jpg"
const BACKYARD_PHOTO := "res://assets/branding/sunshine-bakery-backyard-good.jpg"
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"
const INTERIOR_PHOTO := ""
const Models := preload("res://scripts/explore/imported_models.gd")

const PINK := Color("f4b6c2")
const ORANGE := Color("e07a45")
const SIDING_WHITE := Color("f4f2ee")

var _player: PlayerExplorer
var _front_z: float = -1.35
var _shop_w: float = 10.0
var _shop_h: float = 6.5
var _shop_d: float = 7.4
var _wall: float = 0.22
var _door_w: float = 1.55
var _door_h: float = 2.28
var _side_door_z: float = 4.55
var _side_door_w: float = 1.5


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_lot()
	if not Models.attach(self, Models.EXTERIOR):
		_build_shop()
		_build_facade_branding()
	else:
		_place_mascot()
	if not Models.attach(self, Models.INTERIOR):
		_build_interior()
	if not Models.attach(self, Models.BACKYARD):
		_build_backyard()
	_spawn_collectibles()


func _tex_mat(path: String, color: Color = Color.WHITE, uv: Vector3 = Vector3(4, 4, 4)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.uv1_scale = uv
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


func _visual_box(size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = mat
	mesh_i.position = pos
	mesh_i.rotation.y = rot_y
	add_child(mesh_i)
	return mesh_i


func _mat_metal(c: Color, rough: float = 0.32) -> StandardMaterial3D:
	var m := _mat_color(c)
	m.metallic = 0.72
	m.roughness = rough
	return m


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = font_size
	lab.modulate = color
	lab.outline_size = 4
	lab.outline_modulate = Color("1a1410")
	lab.position = pos
	lab.rotation_degrees.y = rot_y_deg
	add_child(lab)
	return lab


func _wall_door_along_z(
	thickness: float,
	height: float,
	depth: float,
	wall_x: float,
	z_center: float,
	mat: Material,
	door_z: float,
	door_w: float,
	door_h: float
) -> void:
	var z0 := z_center - depth * 0.5
	var z1 := z_center + depth * 0.5
	var d0 := door_z - door_w * 0.5
	var d1 := door_z + door_w * 0.5
	var front_len := d0 - z0
	if front_len > 0.08:
		_static_box(Vector3(thickness, height, front_len), Vector3(wall_x, height * 0.5, z0 + front_len * 0.5), mat)
	var back_len := z1 - d1
	if back_len > 0.08:
		_static_box(Vector3(thickness, height, back_len), Vector3(wall_x, height * 0.5, d1 + back_len * 0.5), mat)
	var lintel_h := height - door_h
	if lintel_h > 0.08:
		_static_box(
			Vector3(thickness, lintel_h, door_w + 0.08),
			Vector3(wall_x, door_h + lintel_h * 0.5, door_z),
			mat
		)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("7ec4ee")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("fff1dc")
	we.ambient_light_energy = 0.72
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 40, 0)
	sun.light_color = Color("fff1c8")
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)


func _build_lot() -> void:
	var grass := _tex_mat("res://assets/generated/grass.png", Color("7dae5e"), Vector3(8, 8, 8))
	var walk := _tex_mat("res://assets/generated/sidewalk.png", Color("d8d2c6"), Vector3(2, 8, 2))
	var asphalt := _tex_mat("res://assets/generated/asphalt.png")
	var pavers := _tex_mat("res://assets/generated/pavers.png", Color("c9b49a"), Vector3(4, 1, 8))
	# Lawn wraps the shop: front picnic lawn + PRIMARY backyard (BACKYARD_PHOTO).
	_static_box(Vector3(36, 0.08, 34), Vector3(0, -0.04, 4), grass)
	# Street further forward (1st Ave S)
	_static_box(Vector3(36, 0.1, 8), Vector3(0, -0.05, -14), asphalt)
	# Concrete strip along the LEFT of the building, front lawn → backyard (photo).
	_static_box(Vector3(1.7, 0.1, 24), Vector3(-5.75, 0.03, 3.6), walk)
	_static_box(Vector3(10, 0.1, 1.8), Vector3(-1.0, 0.02, -3.4), walk)
	# Paver walk from spawn up to the storefront door
	_visual_box(Vector3(1.55, 0.04, 3.4), Vector3(0.0, 0.05, -2.9), pavers)
	_visual_box(Vector3(1.7, 0.05, 0.55), Vector3(0.0, 0.06, -1.55), pavers)
	# Neighbor: grey clapboard + dusty rose metal roof (left)
	var grey := _tex_mat("res://assets/generated/siding.png", Color("b7b6b2"), Vector3(3, 8, 3))
	var rose_roof := _mat_color(Color("c97b84"))
	_static_box(Vector3(7.5, 3.6, 8), Vector3(-13.2, 1.8, 1.5), grey)
	_static_box(Vector3(8.2, 0.18, 8.6), Vector3(-13.2, 3.7, 1.5), rose_roof, 0.12)
	_window(Vector3(-13.2, 2.0, -2.55), Vector3(1.6, 1.3, 0.08), _tex_mat("res://assets/generated/pink_trim.png", PINK, Vector3.ONE))
	# Neighbor right
	var tan := _tex_mat("res://assets/generated/siding.png", Color("d5cfc4"), Vector3(3, 8, 3))
	_static_box(Vector3(6.5, 3.8, 7), Vector3(13.0, 1.9, 2.0), tan)
	_window(Vector3(13.0, 2.1, -1.55), Vector3(1.5, 1.2, 0.08), _mat_color(Color("8a6a45")))
	# Picnic tables
	_picnic_table(Vector3(2.7, 0, -4.15), -0.18)
	_picnic_table(Vector3(-7.4, 0, -7.2), 0.05)
	_picnic_table(Vector3(-6.6, 0, -9.1), 0.0)
	# Beige trash can — off the door centerline so the walk-up stays clear
	_static_box(Vector3(0.42, 0.9, 0.42), Vector3(1.95, 0.48, -2.55), _mat_color(Color("cbb79a")))
	_static_box(Vector3(0.46, 0.08, 0.46), Vector3(1.95, 0.94, -2.55), _mat_color(Color("3a3a3a")))
	# Sandwich board on the lawn, beside the path
	_sandwich_board(Vector3(-1.55, 0.0, -2.7))
	# Corner shrubs / flowers
	_shrub(Vector3(5.3, 0.35, -1.6), Color("6a9a4a"))
	_shrub(Vector3(5.8, 0.28, -0.6), Color("d98ab0"))
	_shrub(Vector3(-5.1, 0.3, -1.5), Color("5e8c3e"))
	_shrub(Vector3(-4.4, 0.22, -0.4), Color("e08ab0"))
	_sign("2231 1ST AVE S", Vector3(0.0, 0.42, -8.4), 42, Color("fff6ea"), 0.0)


func _shrub(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.7
	mi.mesh = mesh
	mi.material_override = _mat_color(color)
	mi.position = pos
	add_child(mi)


func _sandwich_board(pos: Vector3) -> void:
	var wood := _tex_mat("res://assets/generated/wood.png", Color("c4a06a"), Vector3(1, 1, 1))
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = 0.22
	add_child(root)
	_local_box(root, Vector3(0.72, 0.9, 0.08), Vector3(0, 0.55, 0.05), wood)
	_local_box(root, Vector3(0.72, 0.9, 0.08), Vector3(0, 0.55, -0.12), wood)
	var lab := Label3D.new()
	lab.text = "OPEN\nCOME IN"
	lab.font_size = 42
	lab.modulate = Color("6b2d3c")
	lab.position = Vector3(0, 0.62, 0.1)
	lab.rotation_degrees.y = 180
	root.add_child(lab)


func _flower_box(pos: Vector3) -> void:
	_visual_box(Vector3(1.7, 0.22, 0.38), pos, _tex_mat("res://assets/generated/wood.png", Color("8a5a32"), Vector3.ONE))
	_shrub(pos + Vector3(-0.45, 0.28, 0), Color("d98ab0"))
	_shrub(pos + Vector3(0.05, 0.32, 0), Color("6a9a4a"))
	_shrub(pos + Vector3(0.45, 0.26, 0), Color("e07a9a"))


func _awning(pos: Vector3, width: float) -> void:
	var stripe := _tex_mat("res://assets/generated/awning.png", Color.WHITE, Vector3(3, 1, 1))
	_visual_box(Vector3(width, 0.08, 1.15), pos, stripe)
	_visual_box(Vector3(0.06, 0.55, 0.06), pos + Vector3(-width * 0.42, -0.28, 0.45), _mat_color(Color("6b2d3c")))
	_visual_box(Vector3(0.06, 0.55, 0.06), pos + Vector3(width * 0.42, -0.28, 0.45), _mat_color(Color("6b2d3c")))


func _picnic_table(pos: Vector3, rot_y: float, dark: bool = false) -> void:
	var wood := _tex_mat(
		"res://assets/generated/wood.png",
		Color("2c322c") if dark else Color("ddd4c4"),
		Vector3(2, 1, 1)
	)
	var metal := _mat_color(Color("1c1e22") if dark else Color("2e3340"))
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	var top := _local_box(root, Vector3(1.85, 0.07, 0.82), Vector3(0, 0.76, 0), wood)
	top.visible = true
	_local_box(root, Vector3(1.85, 0.06, 0.28), Vector3(0, 0.46, 0.62), wood)
	_local_box(root, Vector3(1.85, 0.06, 0.28), Vector3(0, 0.46, -0.62), wood)
	for x in [-0.7, 0.7]:
		_local_box(root, Vector3(0.07, 0.76, 0.07), Vector3(x, 0.38, 0.28), metal)
		_local_box(root, Vector3(0.07, 0.76, 0.07), Vector3(x, 0.38, -0.28), metal)
		_local_box(root, Vector3(0.07, 0.46, 0.07), Vector3(x, 0.23, 0.62), metal)
		_local_box(root, Vector3(0.07, 0.46, 0.07), Vector3(x, 0.23, -0.62), metal)


func _local_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return mi


func _build_shop() -> void:
	var siding := _tex_mat("res://assets/generated/siding.png", SIDING_WHITE, Vector3(3, 10, 3))
	var pink := _tex_mat("res://assets/generated/pink_trim.png", PINK, Vector3(1, 1, 1))
	var cinder := _tex_mat("res://assets/generated/cinder.png", Color("b8b6b0"), Vector3(6, 2, 6))
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := _front_z + d
	var cx := 0.0
	var cz := fz + d * 0.5
	# Hollow shell so the player can walk in the storefront door.
	# Left wall splits around the yard door (through-shop path). Right wall solid.
	_wall_door_along_z(t, h, d, -w * 0.5 + t * 0.5, cz, siding, _side_door_z, _side_door_w, _door_h)
	_static_box(Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, cz), siding)
	_static_box(Vector3(w, h, t), Vector3(cx, h * 0.5, rz - t * 0.5), siding)
	# Front wall split around the door
	var wing := (w - _door_w) * 0.5
	_static_box(Vector3(wing, h, t), Vector3(-(_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), siding)
	_static_box(Vector3(wing, h, t), Vector3((_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), siding)
	# Lintel over the door
	var lintel_h := h - _door_h
	_static_box(Vector3(_door_w + 0.08, lintel_h, t), Vector3(0, _door_h + lintel_h * 0.5, fz + t * 0.5), siding)
	# Pink picture-frame trim (bottom kick splits around the door so you can walk in)
	_static_box(Vector3(w + 0.18, 0.16, 0.18), Vector3(0, h - 0.02, fz), pink)
	_static_box(Vector3(wing, 0.16, 0.18), Vector3(-(_door_w + wing) * 0.5, 0.12, fz), pink)
	_static_box(Vector3(wing, 0.16, 0.18), Vector3((_door_w + wing) * 0.5, 0.12, fz), pink)
	_static_box(Vector3(0.16, h, 0.18), Vector3(-w * 0.5, h * 0.5, fz), pink)
	_static_box(Vector3(0.16, h, 0.18), Vector3(w * 0.5, h * 0.5, fz), pink)
	_static_box(Vector3(0.16, 0.16, d + 0.1), Vector3(w * 0.5, h - 0.02, cz), pink)
	_static_box(Vector3(0.16, 0.16, d + 0.1), Vector3(-w * 0.5, h - 0.02, cz), pink)
	_static_box(Vector3(0.16, h, 0.16), Vector3(-w * 0.5, h * 0.5, rz), pink)
	_static_box(Vector3(0.16, h, 0.16), Vector3(-w * 0.5, h * 0.5, fz + 0.08), pink)
	# Pink door frame
	_static_box(Vector3(0.1, _door_h, 0.12), Vector3(-_door_w * 0.5, _door_h * 0.5, fz - 0.02), pink)
	_static_box(Vector3(0.1, _door_h, 0.12), Vector3(_door_w * 0.5, _door_h * 0.5, fz - 0.02), pink)
	_static_box(Vector3(_door_w + 0.12, 0.1, 0.12), Vector3(0, _door_h, fz - 0.02), pink)
	# Side yard-door frame (left wall)
	var lx := -w * 0.5 - 0.02
	_static_box(Vector3(0.12, _door_h, 0.1), Vector3(lx, _door_h * 0.5, _side_door_z - _side_door_w * 0.5), pink)
	_static_box(Vector3(0.12, _door_h, 0.1), Vector3(lx, _door_h * 0.5, _side_door_z + _side_door_w * 0.5), pink)
	_static_box(Vector3(0.12, 0.1, _side_door_w + 0.12), Vector3(lx, _door_h, _side_door_z), pink)
	# Door leaf swung inward (visual only — collision would pinch the opening)
	var door := _mat_color(Color("6b3e32"))
	_visual_box(Vector3(0.06, _door_h - 0.12, _door_w * 0.72), Vector3(_door_w * 0.42, (_door_h - 0.12) * 0.5, fz + 0.55), door, 0.7)
	_visual_box(Vector3(_side_door_w * 0.7, _door_h - 0.12, 0.06), Vector3(lx + 0.55, (_door_h - 0.12) * 0.5, _side_door_z + 0.42), door, 0.2)
	# Awning + flower boxes (2231 storefront)
	_awning(Vector3(0.0, _door_h + 0.28, fz - 0.55), 2.6)
	_flower_box(Vector3(-2.35, 0.55, fz - 0.28))
	_flower_box(Vector3(2.35, 0.55, fz - 0.28))
	# Two windows on the front wings
	_window(Vector3(-2.35, 2.15, fz - 0.02), Vector3(2.2, 2.05, 0.1), pink)
	_window(Vector3(2.35, 2.15, fz - 0.02), Vector3(2.2, 2.05, 0.1), pink)
	# Rear window looks onto the backyard
	_window(Vector3(1.6, 2.05, rz + 0.02), Vector3(2.0, 1.6, 0.1), pink)
	# Perimeter CMU foundation with gaps at the front door and yard door
	var found_h := 0.72
	_static_box(Vector3(wing, found_h, 0.28), Vector3(-(_door_w + wing) * 0.5, found_h * 0.5, fz + 0.02), cinder)
	_static_box(Vector3(wing, found_h, 0.28), Vector3((_door_w + wing) * 0.5, found_h * 0.5, fz + 0.02), cinder)
	_wall_door_along_z(0.28, found_h, d, -w * 0.5 + 0.08, cz, cinder, _side_door_z, _side_door_w, found_h)
	_static_box(Vector3(0.28, found_h, d), Vector3(w * 0.5 - 0.08, found_h * 0.5, cz), cinder)
	_static_box(Vector3(w, found_h, 0.28), Vector3(0, found_h * 0.5, rz - 0.05), cinder)
	# Ceiling (keeps the tall false-front outside, cozy inside)
	var plaster := _tex_mat("res://assets/generated/plaster.png", Color("f3e6d4"), Vector3(2, 2, 2))
	_static_box(Vector3(w - t * 2, 0.12, d - t * 2), Vector3(0, 3.28, cz), plaster)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.0, fz + 0.8)
	lamp.light_color = Color("ffe0b0")
	lamp.light_energy = 1.1
	lamp.omni_range = 9
	add_child(lamp)


func _window(pos: Vector3, size: Vector3, pink: Material) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.42, 0.58, 0.68, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic = 0.15
	_static_box(size, pos, glass)
	var t := 0.08
	_static_box(Vector3(size.x + t, t, 0.12), pos + Vector3(0, size.y * 0.5, -0.02), pink)
	_static_box(Vector3(size.x + t, t, 0.12), pos + Vector3(0, -size.y * 0.5, -0.02), pink)
	_static_box(Vector3(t, size.y, 0.12), pos + Vector3(-size.x * 0.5, 0, -0.02), pink)
	_static_box(Vector3(t, size.y, 0.12), pos + Vector3(size.x * 0.5, 0, -0.02), pink)
	# Light muntin
	_static_box(Vector3(0.04, size.y, 0.04), pos + Vector3(0, 0, -0.03), pink)
	_static_box(Vector3(size.x, 0.04, 0.04), pos + Vector3(0, 0, -0.03), pink)


func _build_interior() -> void:
	# Stub indoor shop (no interior photos yet): counter, pastry case, standing area.
	var tile := _tex_mat("res://assets/generated/tile.png", Color.WHITE, Vector3(6, 6, 6))
	var wood := _tex_mat("res://assets/generated/wood.png")
	var plaster := _tex_mat("res://assets/generated/plaster.png", Color("fff6ea"), Vector3(3, 3, 3))
	var blush_stripe := _tex_mat("res://assets/generated/pink_trim.png", PINK, Vector3.ONE)
	var runner := _tex_mat("res://assets/generated/pavers.png", Color("e8b4b8"), Vector3(1, 1, 4))
	var cz := _front_z + _shop_d * 0.5
	var inner_w := _shop_w - _wall * 2
	var inner_d := _shop_d - _wall * 2
	_static_box(Vector3(inner_w, 0.06, inner_d), Vector3(0, 0.06, cz), tile)
	# Path: front door → left aisle → yard door
	_visual_box(Vector3(1.35, 0.03, inner_d * 0.45), Vector3(0.0, 0.1, _front_z + 1.6), runner)
	_visual_box(Vector3(2.4, 0.03, 1.15), Vector3(-2.4, 0.1, _side_door_z), runner)
	_wall_door_along_z(0.04, 3.1, inner_d, -inner_w * 0.5 + 0.06, cz, plaster, _side_door_z, _side_door_w, _door_h)
	_static_box(Vector3(0.04, 3.1, inner_d), Vector3(inner_w * 0.5 - 0.06, 1.6, cz), plaster)
	_static_box(Vector3(inner_w, 3.1, 0.04), Vector3(0, 1.6, _front_z + _shop_d - _wall - 0.04), plaster)
	_visual_box(Vector3(inner_w - 0.2, 0.18, 0.05), Vector3(0, 2.55, _front_z + _shop_d - _wall - 0.08), blush_stripe)
	# Service counter — shortened on the left so the yard-door aisle stays clear
	_static_box(Vector3(4.5, 1.05, 0.78), Vector3(0.15, 0.58, 4.55), wood)
	_visual_box(Vector3(4.5, 0.08, 0.82), Vector3(0.15, 0.12, 4.55), _mat_color(Color("6b2d3c")))
	var brass := _mat_metal(Color("c9a24a"))
	_visual_box(Vector3(4.4, 0.04, 0.04), Vector3(0.15, 1.12, 4.18), brass)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.72, 0.88, 0.92, 0.32)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	_static_box(Vector3(4.3, 0.72, 0.58), Vector3(0.15, 1.42, 4.5), glass)
	_static_box(Vector3(4.3, 0.05, 0.58), Vector3(0.15, 1.8, 4.5), wood)
	_fill_pastry_case(Vector3(0.15, 1.22, 4.42))
	# Drink / espresso station — copper + cream, not a gray box
	_static_box(Vector3(1.25, 1.2, 0.7), Vector3(3.35, 0.66, 4.5), _mat_color(Color("5c3a32")))
	_visual_box(Vector3(0.7, 0.55, 0.48), Vector3(3.35, 1.48, 4.5), _mat_metal(Color("b87333"), 0.28))
	_visual_box(Vector3(0.18, 0.28, 0.18), Vector3(3.12, 1.85, 4.42), _mat_metal(Color("d8d8d8"), 0.2))
	_visual_box(Vector3(0.22, 0.08, 0.22), Vector3(3.55, 1.78, 4.42), _mat_color(Color("3d1f24")))
	# Small standing area: open floor + a high ledge near the window
	_static_box(Vector3(1.6, 1.05, 0.4), Vector3(-3.2, 0.58, 0.35), wood)
	_visual_box(Vector3(0.35, 0.72, 0.35), Vector3(-3.7, 0.4, 0.55), _mat_color(Color("c45c6a")))
	_visual_box(Vector3(0.35, 0.72, 0.35), Vector3(-2.7, 0.4, 0.55), _mat_color(Color("c45c6a")))
	# Menu chalkboard
	var board := _tex_mat("res://assets/generated/chalkboard.png", Color("2c3a30"), Vector3.ONE)
	_visual_box(Vector3(2.4, 1.35, 0.05), Vector3(-1.1, 2.15, 5.55), board)
	_sign("TODAY · FRESH BATCH\nCROISSANTS · DRINKS", Vector3(-1.1, 2.15, 5.48), 28, Color("fff6ea"), 180)
	_sign("PICK UP · STANDING ROOM", Vector3(0, 2.42, 4.95), 26, Color("4a2c2a"), 180)
	_sign("YARD →", Vector3(-3.9, 2.15, _side_door_z), 36, Color("6b2d3c"), 90)
	_sign("COME IN", Vector3(0.0, 2.55, _front_z + 0.55), 32, Color("6b2d3c"), 0)
	if INTERIOR_PHOTO != "" and ResourceLoader.exists(INTERIOR_PHOTO):
		var photo := _tex_mat(INTERIOR_PHOTO, Color.WHITE, Vector3.ONE)
		_static_box(Vector3(3.2, 2.0, 0.04), Vector3(0, 2.0, _front_z + _shop_d - _wall - 0.08), photo)
	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 2.9, 2.2)
	interior.light_color = Color("ffe6c8")
	interior.light_energy = 1.85
	interior.omni_range = 11
	add_child(interior)
	var case_light := OmniLight3D.new()
	case_light.position = Vector3(0.15, 2.1, 4.3)
	case_light.light_color = Color("fff2d0")
	case_light.light_energy = 0.95
	case_light.omni_range = 4
	add_child(case_light)
	_pendant(Vector3(-1.6, 2.85, 2.4))
	_pendant(Vector3(1.6, 2.85, 2.4))


func _pendant(pos: Vector3) -> void:
	_visual_box(Vector3(0.04, 0.45, 0.04), pos + Vector3(0, 0.2, 0), _mat_metal(Color("c9a24a")))
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = 0.22
	cone.height = 0.18
	shade.mesh = cone
	shade.material_override = _mat_color(Color("fff1dc"))
	shade.position = pos
	add_child(shade)
	var glow := OmniLight3D.new()
	glow.position = pos + Vector3(0, -0.15, 0)
	glow.light_color = Color("ffe0b0")
	glow.light_energy = 0.55
	glow.omni_range = 4.5
	add_child(glow)


func _fill_pastry_case(origin: Vector3) -> void:
	var colors := [Color("e6b14a"), Color("c45c6a"), Color("f3d9a8"), Color("8a5a32"), Color("e08a5e")]
	for i in 5:
		var pastry := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.11
		sph.height = 0.09
		pastry.mesh = sph
		pastry.material_override = _mat_color(colors[i])
		pastry.position = origin + Vector3(-1.6 + i * 0.8, 0.0, 0.0)
		add_child(pastry)


func _mat_color(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


func _build_facade_branding() -> void:
	var fz := _front_z - 0.08
	# Official circular girl mark (not a generated face).
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.92
	cyl.bottom_radius = 0.92
	cyl.height = 0.04
	cyl.radial_segments = 32
	disc.mesh = cyl
	var logo_mat := StandardMaterial3D.new()
	logo_mat.albedo_texture = load(LOGO_GIRL)
	logo_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	logo_mat.roughness = 0.65
	disc.material_override = logo_mat
	disc.position = Vector3(0, 5.12, fz)
	disc.rotation_degrees = Vector3(90, 0, 0)
	add_child(disc)
	# Orange SUNSHINE'S BAKERY bar under the circle
	_static_box(Vector3(7.15, 0.72, 0.1), Vector3(0, 4.08, fz), _mat_color(ORANGE))
	var title := Label3D.new()
	title.text = "SUNSHINE'S BAKERY"
	title.font_size = 64
	title.outline_size = 4
	title.outline_modulate = Color("1a1a1a")
	title.modulate = Color("1a1410")
	title.position = Vector3(0, 4.08, fz - 0.07)
	title.rotation_degrees.y = 180
	add_child(title)
	# Vertical 2231 on the right of the facade
	var addr := Label3D.new()
	addr.text = "2\n2\n3\n1"
	addr.font_size = 40
	addr.modulate = Color("2a2a2a")
	addr.position = Vector3(4.55, 2.45, fz - 0.06)
	addr.rotation_degrees.y = 180
	add_child(addr)
	_sign("YARD THIS WAY →", Vector3(-5.35, 1.55, _side_door_z), 28, Color("fff6ea"), 90)
	# Walk-up 3D chibi matching the circular girl (front lawn, not in the backyard)
	_place_mascot()


func _place_mascot() -> void:
	# GLB is meter-authored (~1.5m standing; Hat world Y ≈1.35). No attach scale.
	if Models.attach(self, Models.GIRL, Vector3(-4.6, 0.0, -2.8), deg_to_rad(-12)):
		return
	var greeter := SunshineMascot.new()
	greeter.show_emblem = false
	greeter.show_girl = true
	greeter.position = Vector3(-4.6, 0.0, -2.8)
	greeter.rotation_degrees.y = -12
	add_child(greeter)


func _build_backyard() -> void:
	# PRIMARY rear-yard layout from sunshine-bakery-backyard-good.jpg
	# (clean grass, dark tables, wood fence, trees, lattice deck — no construction pile).
	var _ref := BACKYARD_PHOTO
	if _ref == "":
		return
	var fence_mat := _tex_mat("res://assets/generated/fence.png", Color("8a6a45"), Vector3(8, 2, 1))
	var walk := _tex_mat("res://assets/generated/sidewalk.png", Color("d8d2c6"), Vector3(2, 4, 2))
	var rear_z := 6.1
	# Concrete strip along the left building wall
	_static_box(Vector3(1.5, 0.1, 8.5), Vector3(-5.7, 0.04, rear_z + 0.4), walk)
	# Dark picnic tables in the grass
	_picnic_table(Vector3(0.6, 0, 9.3), 0.04, true)
	_picnic_table(Vector3(-3.1, 0, 12.5), -0.08, true)
	_picnic_table(Vector3(1.4, 0, 12.8), 0.12, true)
	# Privacy fence wrapping the back of the lot
	_static_box(Vector3(16.5, 1.85, 0.12), Vector3(0.4, 0.95, 16.4), fence_mat)
	_static_box(Vector3(0.12, 1.85, 8.5), Vector3(-7.8, 0.95, 12.2), fence_mat)
	_static_box(Vector3(0.12, 1.85, 6.2), Vector3(8.5, 0.95, 13.4), fence_mat)
	# Lattice deck on the right
	_lattice_deck(Vector3(6.6, 0, 9.4))
	# Trees along and behind the fence
	for i in 7:
		var x := -6.5 + i * 2.35
		_tree(Vector3(x, 0, 17.2 + (i % 2) * 0.8), 5.5 + (i % 3) * 0.8)
	_tree(Vector3(-5.2, 0, 14.6), 6.2)
	_tree(Vector3(4.8, 0, 15.8), 7.0)
	# Warm sun through the back trees (photo flare)
	var yard_sun := DirectionalLight3D.new()
	yard_sun.rotation_degrees = Vector3(-28, 170, 0)
	yard_sun.light_color = Color("ffe6a8")
	yard_sun.light_energy = 0.45
	yard_sun.shadow_enabled = false
	add_child(yard_sun)


func _lattice_deck(pos: Vector3) -> void:
	var lumber := _tex_mat("res://assets/generated/wood.png", Color("c4a06a"), Vector3(2, 2, 2))
	var lattice := _tex_mat("res://assets/generated/lattice.png", Color("c8aa78"), Vector3(6, 4, 1))
	lattice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_local_box(root, Vector3(3.3, 0.12, 3.6), Vector3(0, 0.95, 0), lumber)
	# Lattice skirting
	_local_box(root, Vector3(3.3, 0.9, 0.06), Vector3(0, 0.45, 1.82), lattice)
	_local_box(root, Vector3(3.3, 0.9, 0.06), Vector3(0, 0.45, -1.82), lattice)
	_local_box(root, Vector3(0.06, 0.9, 3.6), Vector3(1.65, 0.45, 0), lattice)
	_local_box(root, Vector3(0.06, 0.9, 3.6), Vector3(-1.65, 0.45, 0), lattice)
	# Simple rail
	_local_box(root, Vector3(3.3, 0.08, 0.08), Vector3(0, 1.55, 1.75), lumber)
	_local_box(root, Vector3(3.3, 0.08, 0.08), Vector3(0, 1.55, -1.75), lumber)
	_local_box(root, Vector3(0.08, 0.62, 0.08), Vector3(1.5, 1.25, 1.75), lumber)
	_local_box(root, Vector3(0.08, 0.62, 0.08), Vector3(-1.5, 1.25, 1.75), lumber)
	# HVAC box
	_local_box(root, Vector3(0.9, 0.55, 0.7), Vector3(0.6, 1.28, -0.4), _mat_color(Color("c5c8cc")))


func _tree(pos: Vector3, height: float) -> void:
	var bark := _mat_color(Color("4a3424"))
	var leaf := _mat_color(Color("3f6b32"))
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.28
	cyl.height = height * 0.45
	trunk.mesh = cyl
	trunk.material_override = bark
	trunk.position = pos + Vector3(0, cyl.height * 0.5, 0)
	add_child(trunk)
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.35 + height * 0.08
	sph.height = sph.radius * 1.7
	canopy.mesh = sph
	canopy.material_override = leaf
	canopy.position = pos + Vector3(0, height * 0.62, 0)
	add_child(canopy)


func _spawn_collectibles() -> void:
	var spots: Array[Vector3] = [
		# Outdoors — front lawn
		Vector3(2.7, 0.95, -4.15),
		Vector3(-7.4, 0.95, -7.2),
		Vector3(-6.6, 0.95, -9.1),
		Vector3(0.4, 0.45, -2.8),
		Vector3(-3.2, 0.4, -3.2),
		Vector3(4.4, 0.4, -3.6),
		# Indoors — in front of pastry case / espresso, standing ledge, open floor
		Vector3(-2.2, 1.35, 4.05),
		Vector3(-0.4, 1.35, 4.05),
		Vector3(1.3, 1.35, 4.05),
		Vector3(3.15, 1.55, 4.05),
		Vector3(-3.2, 1.25, 0.35),
		Vector3(1.6, 0.45, 1.8),
		Vector3(-3.6, 0.45, 4.2),
		# Outdoors — backyard
		Vector3(0.6, 0.95, 9.3),
		Vector3(-3.1, 0.95, 12.5),
		Vector3(1.4, 0.95, 12.8),
		Vector3(6.4, 1.15, 9.2),
	]
	spots.shuffle()
	for i in spots.size():
		_place_pickup(spots[i], "croissant" if i % 2 == 0 else "drink", false)
	if GameSave.is_fresh_batch_active():
		_spawn_fresh_batch_extras()


func _spawn_fresh_batch_extras() -> void:
	var extras: Array[Vector3] = [
		# Indoor standing floor + extra case slots
		Vector3(-1.3, 1.35, 4.05),
		Vector3(0.5, 1.35, 4.05),
		Vector3(2.4, 0.45, 2.6),
		Vector3(-2.4, 0.45, 2.2),
		# Outdoor front lawn
		Vector3(3.5, 0.45, -5.4),
		Vector3(-5.2, 0.4, -4.8),
		# Outdoor backyard
		Vector3(-1.2, 0.95, 10.6),
		Vector3(3.4, 0.95, 11.2),
	]
	extras.shuffle()
	for i in extras.size():
		_place_pickup(extras[i], "drink" if i % 2 == 0 else "croissant", true)


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
