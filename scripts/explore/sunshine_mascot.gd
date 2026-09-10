extends Node3D
class_name SunshineMascot
## Low-poly chibi matching assets/branding/sunshine-logo-girl.jpg
## (round glasses, shiny black eyes, beauty mark, wavy brown hair + bangs,
## yellow-orange hat + black band + sunflower, pink top, red collar, grey apron).

const SKIN := Color("f7d3b8")
const HAIR := Color("3d2418")
const HAT := Color("e6b14a")
const HAT_BAND := Color("1a1a1a")
const PINK := Color("e8a8b4")
const COLLAR := Color("c45c6a")
const APRON := Color("c5c0be")
const GLASS := Color("1a1a1a")
const EYE := Color("14110f")
const SHINE := Color("ffffff")
const PETAL := Color("e8942a")
const PETAL_DARK := Color("c45c1a")
const SEED := Color("5c3310")
const CREAM := Color("f3d9a8")
const BAR := Color("e08a5e")
const OUTLINE := Color("1a1a1a")


@export var show_emblem: bool = true
@export var show_girl: bool = true


func _ready() -> void:
	if show_emblem:
		_build_emblem()
	if show_girl:
		_build_girl()


func _mat(color: Color, roughness: float = 0.62, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scale
	add_child(mi)
	return mi


func _sphere(r: float, mat: Material, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	return _mesh(mesh, mat, pos, Vector3.ZERO, scale)


func _cyl(r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = 16
	return _mesh(mesh, mat, pos, rot)


func _box(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, mat, pos, rot)


func _build_emblem() -> void:
	# Cream sunburst disc + thick black ring + orange name bar (logo plate).
	var disc := CylinderMesh.new()
	disc.top_radius = 1.05
	disc.bottom_radius = 1.05
	disc.height = 0.06
	disc.radial_segments = 32
	_mesh(disc, _mat(CREAM), Vector3(0, 1.15, 0.18), Vector3(90, 0, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.02
	ring.outer_radius = 1.12
	ring.rings = 24
	ring.ring_segments = 12
	_mesh(ring, _mat(OUTLINE, 0.4), Vector3(0, 1.15, 0.18), Vector3(90, 0, 0))
	# Official artwork on a slightly inset disc so the 3D girl stands in front.
	var art := CylinderMesh.new()
	art.top_radius = 0.98
	art.bottom_radius = 0.98
	art.height = 0.02
	art.radial_segments = 32
	var art_mat := StandardMaterial3D.new()
	art_mat.albedo_texture = load("res://assets/branding/sunshine-logo-girl.jpg")
	art_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	art_mat.roughness = 0.7
	_mesh(art, art_mat, Vector3(0, 1.15, 0.21), Vector3(90, 0, 0))
	# Rays
	for i in 12:
		var ang := i * PI / 6.0
		var ray := BoxMesh.new()
		ray.size = Vector3(0.035, 0.18, 0.02)
		var mi := _mesh(ray, _mat(OUTLINE), Vector3(cos(ang) * 0.92, 1.15 + sin(ang) * 0.92, 0.2), Vector3(0, 0, rad_to_deg(ang)))
		mi.visible = true
	var bar := _box(Vector3(1.7, 0.42, 0.04), _mat(BAR), Vector3(0, 0.42, 0.2))
	bar.visible = true
	var title := Label3D.new()
	title.text = "SUNSHINE'S\nBAKERY"
	title.font_size = 42
	title.outline_size = 6
	title.modulate = Color("1a1a1a")
	title.position = Vector3(0, 0.42, 0.24)
	title.rotation_degrees.y = 180
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(title)


func _build_girl() -> void:
	var skin := _mat(SKIN, 0.55)
	var hair := _mat(HAIR, 0.7)
	var hat := _mat(HAT, 0.5)
	# Head
	_sphere(0.28, skin, Vector3(0, 1.22, -0.02))
	# Wavy hair masses (behind + sides)
	_sphere(0.22, hair, Vector3(-0.22, 1.12, 0.06), Vector3(1.0, 1.35, 0.85))
	_sphere(0.22, hair, Vector3(0.22, 1.12, 0.06), Vector3(1.0, 1.35, 0.85))
	_sphere(0.26, hair, Vector3(0, 1.28, 0.12), Vector3(1.15, 0.7, 0.9))
	_sphere(0.18, hair, Vector3(-0.18, 0.92, 0.04), Vector3(0.85, 1.2, 0.7))
	_sphere(0.18, hair, Vector3(0.18, 0.92, 0.04), Vector3(0.85, 1.2, 0.7))
	# Bangs
	_sphere(0.1, hair, Vector3(-0.1, 1.36, -0.16), Vector3(1.3, 0.55, 0.7))
	_sphere(0.1, hair, Vector3(0.08, 1.37, -0.16), Vector3(1.2, 0.5, 0.7))
	_sphere(0.08, hair, Vector3(-0.02, 1.34, -0.18), Vector3(1.1, 0.45, 0.6))
	# Hat brim + crown + black band
	var brim := CylinderMesh.new()
	brim.top_radius = 0.55
	brim.bottom_radius = 0.55
	brim.height = 0.045
	brim.radial_segments = 20
	_mesh(brim, hat, Vector3(0, 1.48, 0.0), Vector3(12, 0, -8))
	_cyl(0.22, 0.26, 0.16, hat, Vector3(0, 1.56, 0.04), Vector3(10, 0, -6))
	_cyl(0.235, 0.235, 0.05, _mat(HAT_BAND, 0.4), Vector3(0, 1.50, 0.02), Vector3(10, 0, -6))
	# Sunflower on viewer's right (her left from behind = +X when facing -Z)
	_build_sunflower(Vector3(0.28, 1.58, -0.12))
	# Eyes + shine
	_sphere(0.07, _mat(EYE, 0.25), Vector3(-0.09, 1.22, -0.24))
	_sphere(0.07, _mat(EYE, 0.25), Vector3(0.09, 1.22, -0.24))
	_sphere(0.022, _mat(SHINE, 0.2), Vector3(-0.07, 1.245, -0.29))
	_sphere(0.022, _mat(SHINE, 0.2), Vector3(0.11, 1.245, -0.29))
	# Round glasses
	_torus(0.085, 0.012, Vector3(-0.09, 1.22, -0.25))
	_torus(0.085, 0.012, Vector3(0.09, 1.22, -0.25))
	_box(Vector3(0.06, 0.012, 0.012), _mat(GLASS, 0.3), Vector3(0, 1.22, -0.25))
	# Smile (thin torus segment approximated with a bent box)
	_box(Vector3(0.1, 0.012, 0.012), _mat(GLASS, 0.4), Vector3(0, 1.12, -0.26), Vector3(0, 0, 0))
	# Beauty mark on her left cheek (viewer's right)
	_sphere(0.012, _mat(HAIR, 0.5), Vector3(0.14, 1.14, -0.23))
	# Shoulders / pink top / red collar / grey apron straps
	_sphere(0.16, _mat(PINK, 0.65), Vector3(0, 0.86, 0.0), Vector3(1.35, 0.7, 0.9))
	_cyl(0.12, 0.12, 0.05, _mat(COLLAR, 0.5), Vector3(0, 0.98, -0.05), Vector3(8, 0, 0))
	_box(Vector3(0.05, 0.22, 0.03), _mat(APRON, 0.7), Vector3(-0.08, 0.88, -0.12), Vector3(12, 0, 8))
	_box(Vector3(0.05, 0.22, 0.03), _mat(APRON, 0.7), Vector3(0.08, 0.88, -0.12), Vector3(12, 0, -8))


func _torus(r: float, t: float, pos: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = r - t
	mesh.outer_radius = r + t
	mesh.rings = 14
	mesh.ring_segments = 10
	_mesh(mesh, _mat(GLASS, 0.3), pos, Vector3(90, 0, 0))


func _build_sunflower(pos: Vector3) -> void:
	_sphere(0.07, _mat(SEED, 0.7), pos)
	for i in 12:
		var ang := i * PI / 6.0
		var petal := SphereMesh.new()
		petal.radius = 0.035
		petal.height = 0.09
		var mi := MeshInstance3D.new()
		mi.mesh = petal
		mi.material_override = _mat(PETAL if i % 2 == 0 else PETAL_DARK, 0.55)
		mi.position = pos + Vector3(cos(ang) * 0.09, sin(ang) * 0.09, -0.01)
		mi.rotation_degrees.z = rad_to_deg(ang)
		add_child(mi)
