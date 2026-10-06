extends Node3D
## A few cartoon ghosts for the test world. No colliders, so they never block a walk.
## Meshes stay unshaded and unlit so four of them stay cheap on a phone.

const COUNT := 4
const CREAM := Color("f7f4ee")
const BLUSH := Color("e8b4b8")
const EYE := Color("2a2428")


func _ready() -> void:
	name = "PatioGhosts"
	for i in COUNT:
		add_child(_ghost(i))


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in get_child_count():
		var ghost := get_child(i) as Node3D
		if ghost == null:
			continue
		var phase := float(i) * 1.7
		var radius := 6.5 + float(i) * 2.8
		var speed := 0.16 + float(i) * 0.035
		var ang := t * speed + phase
		var bob := sin(t * 1.5 + phase) * 0.22
		ghost.position = Vector3(
			1.2 + cos(ang) * radius,
			1.15 + bob,
			-0.6 + sin(ang) * radius * 0.82
		)
		ghost.rotation.y = ang + PI * 0.5
		var squash := 1.0 + sin(t * 1.5 + phase) * 0.04
		ghost.scale = Vector3(1.0 / squash, squash, 1.0)


func _ghost(i: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Ghost%d" % i
	var body := _mat(CREAM)
	_sphere(root, 0.34, body, Vector3(0, 0.22, 0), Vector3(1.05, 1.25, 0.95))
	_sphere(root, 0.16, body, Vector3(-0.12, -0.02, 0.02), Vector3(0.9, 0.7, 0.8))
	_sphere(root, 0.15, body, Vector3(0.12, -0.04, 0.0), Vector3(0.85, 0.75, 0.8))
	_sphere(root, 0.12, body, Vector3(0.0, -0.08, -0.04), Vector3(0.8, 0.85, 0.75))
	_sphere(root, 0.07, _mat(BLUSH), Vector3(-0.12, 0.20, -0.22), Vector3(1.1, 0.7, 0.4))
	_sphere(root, 0.07, _mat(BLUSH), Vector3(0.12, 0.20, -0.22), Vector3(1.1, 0.7, 0.4))
	_sphere(root, 0.055, _mat(EYE), Vector3(-0.09, 0.28, -0.26))
	_sphere(root, 0.055, _mat(EYE), Vector3(0.09, 0.28, -0.26))
	return root


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 70.0
	mi.visibility_range_end_margin = 8.0
	parent.add_child(mi)
