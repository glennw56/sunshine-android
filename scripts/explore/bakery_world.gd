extends Node3D
class_name BakeryWorld
## Low-poly Sunshine's Bakery exterior from assets/branding/sunshine-bakery-exterior-2231.jpg:
## white clapboard, pink trim, two windows, circular girl logo, orange text sign,
## picnic tables on grass, vertical 2231. Circular mark is sunshine-logo-girl.jpg.

const STOREFRONT_PHOTO := "res://assets/branding/sunshine-bakery-exterior-2231.jpg"
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"
const INTERIOR_PHOTO := ""

const PINK := Color("f4b6c2")
const ORANGE := Color("e07a45")
const SIDING_WHITE := Color("f4f2ee")

var _player: PlayerExplorer
var _front_z: float = -1.35


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_lot()
	_build_shop()
	_build_interior()
	_build_facade_branding()
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


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("6eb7e8")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("fff4e4")
	we.ambient_light_energy = 0.62
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
	# Lawn in front of the shop (photo: picnic tables on grass)
	_static_box(Vector3(36, 0.08, 22), Vector3(0, -0.04, 2), grass)
	# Street further forward
	_static_box(Vector3(36, 0.1, 8), Vector3(0, -0.05, -14), asphalt)
	# Concrete sidewalk from the photo (left-front toward the building)
	_static_box(Vector3(2.2, 0.1, 16), Vector3(-5.6, 0.02, -6.5), walk)
	_static_box(Vector3(10, 0.1, 1.8), Vector3(-1.0, 0.02, -3.4), walk)
	# Neighbor: grey house + dusty rose metal roof (left)
	var grey := _mat_color(Color("b7b6b2"))
	var rose_roof := _mat_color(Color("c97b84"))
	_static_box(Vector3(7.5, 3.6, 8), Vector3(-13.2, 1.8, 1.5), grey)
	_static_box(Vector3(8.2, 0.18, 8.6), Vector3(-13.2, 3.7, 1.5), rose_roof, 0.12)
	# Neighbor right: darker house mass
	_static_box(Vector3(6.5, 3.8, 7), Vector3(13.0, 1.9, 2.0), _mat_color(Color("d5cfc4")))
	# Picnic tables
	_picnic_table(Vector3(2.7, 0, -4.15), -0.18)
	_picnic_table(Vector3(-7.4, 0, -7.2), 0.05)
	_picnic_table(Vector3(-6.6, 0, -9.1), 0.0)
	# Beige trash can
	_static_box(Vector3(0.42, 0.9, 0.42), Vector3(0.15, 0.48, -2.35), _mat_color(Color("cbb79a")))
	_static_box(Vector3(0.46, 0.08, 0.46), Vector3(0.15, 0.94, -2.35), _mat_color(Color("3a3a3a")))
	# Corner shrubs / flowers
	_shrub(Vector3(5.3, 0.35, -1.6), Color("6a9a4a"))
	_shrub(Vector3(5.8, 0.28, -0.6), Color("d98ab0"))
	_shrub(Vector3(-5.1, 0.3, -1.5), Color("5e8c3e"))


func _shrub(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.7
	mi.mesh = mesh
	mi.material_override = _mat_color(color)
	mi.position = pos
	add_child(mi)


func _picnic_table(pos: Vector3, rot_y: float) -> void:
	var wood := _tex_mat("res://assets/generated/wood.png", Color("ddd4c4"), Vector3(2, 1, 1))
	var metal := _mat_color(Color("2e3340"))
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
	var wood := _tex_mat("res://assets/generated/wood.png")
	# Tall white clapboard box (photo: high false-front storefront)
	var w := 10.0
	var h := 6.5
	var d := 7.4
	_static_box(Vector3(w, h, d), Vector3(0, h * 0.5, d * 0.5 + _front_z), siding)
	# Pink picture-frame trim around the facade
	var fz := _front_z - 0.04
	_static_box(Vector3(w + 0.18, 0.16, 0.18), Vector3(0, h - 0.02, fz), pink) # top cap
	_static_box(Vector3(w + 0.18, 0.16, 0.18), Vector3(0, 0.12, fz), pink) # bottom kick
	_static_box(Vector3(0.16, h, 0.18), Vector3(-w * 0.5, h * 0.5, fz), pink)
	_static_box(Vector3(0.16, h, 0.18), Vector3(w * 0.5, h * 0.5, fz), pink)
	# Pink roof/parapet edge along the side
	_static_box(Vector3(0.16, 0.16, d + 0.1), Vector3(w * 0.5, h - 0.02, d * 0.5 + _front_z), pink)
	_static_box(Vector3(0.16, 0.16, d + 0.1), Vector3(-w * 0.5, h - 0.02, d * 0.5 + _front_z), pink)
	# Two large windows, pink frames
	_window(Vector3(-2.35, 2.15, fz - 0.02), Vector3(2.2, 2.05, 0.1), pink)
	_window(Vector3(2.35, 2.15, fz - 0.02), Vector3(2.2, 2.05, 0.1), pink)
	# Side door on the right wall (not on the photo face)
	_static_box(Vector3(0.12, 2.2, 1.0), Vector3(w * 0.5 + 0.04, 1.15, 1.8), _mat_color(Color("4a2c2a")))
	# Covered porch out back (reviews; not in this photo)
	_static_box(Vector3(5.5, 0.12, 3.2), Vector3(0, 0.18, d + _front_z + 0.6), wood)
	_static_box(Vector3(5.7, 0.1, 3.3), Vector3(0, 2.5, d + _front_z + 0.6), wood)
	for x in [-2.5, 2.5]:
		_static_box(Vector3(0.12, 2.3, 0.12), Vector3(x, 1.2, d + _front_z - 0.4), wood)
		_static_box(Vector3(0.12, 2.3, 0.12), Vector3(x, 1.2, d + _front_z + 1.8), wood)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.2, _front_z + 0.8)
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
	var tile := _tex_mat("res://assets/generated/tile.png", Color.WHITE, Vector3(6, 6, 6))
	var wood := _tex_mat("res://assets/generated/wood.png")
	_static_box(Vector3(9.4, 0.08, 6.8), Vector3(0, 0.08, 2.3), tile)
	_static_box(Vector3(5.2, 1.1, 0.75), Vector3(-1.0, 0.7, 0.6), wood)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 0.9, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_static_box(Vector3(5.1, 0.65, 0.55), Vector3(-1.0, 1.42, 0.6), glass)
	_static_box(Vector3(1.3, 1.15, 0.65), Vector3(3.2, 0.7, 0.7), _mat_color(Color("3d2a28")))
	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 3.1, 2.2)
	interior.light_color = Color("ffe6c8")
	interior.light_energy = 1.4
	interior.omni_range = 10
	add_child(interior)


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
	addr.text = "2\n3\n1"
	addr.font_size = 48
	addr.modulate = Color("2a2a2a")
	addr.position = Vector3(4.55, 2.55, fz - 0.06)
	addr.rotation_degrees.y = 180
	add_child(addr)
	# Walk-up 3D chibi matching the circular girl (off to the side, not covering the sign)
	var greeter := SunshineMascot.new()
	greeter.show_emblem = false
	greeter.show_girl = true
	greeter.position = Vector3(-4.6, 0.0, -2.8)
	greeter.rotation_degrees.y = -12
	add_child(greeter)


func _spawn_collectibles() -> void:
	var spots: Array[Vector3] = [
		Vector3(2.7, 0.95, -4.15),
		Vector3(-7.4, 0.95, -7.2),
		Vector3(-6.6, 0.95, -9.1),
		Vector3(0.4, 0.45, -2.8),
		Vector3(-3.2, 0.4, -3.2),
		Vector3(4.4, 0.4, -3.6),
		Vector3(-1.0, 1.85, 0.6),
		Vector3(1.4, 1.85, 0.6),
		Vector3(3.2, 1.5, 0.7),
		Vector3(-1.6, 0.45, 6.4),
		Vector3(1.4, 0.45, 6.8),
		Vector3(5.2, 0.4, -1.4),
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
