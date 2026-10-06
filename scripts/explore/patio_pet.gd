extends Node3D
## One patio pet. Wander until a player picks it up. Never a projectile.

var held := false
var _kind := "cat"
var _home := Vector3.ZERO
var _goal := Vector3.ZERO
var _wait := 0.6


func setup(kind: String, home: Vector3) -> void:
	_kind = kind
	_home = home
	name = "Cat" if kind == "cat" else "Dog"
	position = home
	_goal = home
	if kind == "cat":
		_build_cat()
	else:
		_build_dog()
	add_to_group("patio_pet")


func _process(delta: float) -> void:
	if held:
		return
	var tail := get_node_or_null("Tail") as Node3D
	if tail:
		tail.rotation.z = sin(Time.get_ticks_msec() * 0.006) * (0.45 if _kind == "dog" else 0.25)
	if _wait > 0.0:
		_wait -= delta
		return
	var flat := Vector3(_goal.x - position.x, 0.0, _goal.z - position.z)
	if flat.length() < 0.18:
		_wait = randf_range(1.1, 2.6)
		_goal = _home + Vector3(randf_range(-3.2, 3.2), 0.0, randf_range(-2.6, 2.6))
		_goal.x = clampf(_goal.x, -8.5, 8.5)
		_goal.z = clampf(_goal.z, -6.5, 7.5)
		return
	var step := flat.normalized() * minf(0.85 * delta, flat.length())
	position += step
	position.y = 0.0
	if step.length_squared() > 0.000004:
		look_at(global_position + step, Vector3.UP)
	rotation.x = sin(Time.get_ticks_msec() * 0.012) * 0.04


func follow_chest(avatar: Node3D) -> void:
	## Lie across the arms. Local +Y (ears) points forward, local +X is up,
	## so the tall axis stays horizontal and the body sits on the chest.
	## Avatar face is −Z at about y 1.28; this pose stays under the chin.
	var carry := Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	global_transform = avatar.global_transform * Transform3D(carry, Vector3(0.0, 0.72, -0.32))


func place_on_ground(at: Vector3, home: Node) -> void:
	held = false
	if get_parent() != home:
		reparent(home)
	global_position = Vector3(at.x, maxf(at.y, 0.0), at.z)
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	_wait = 0.9
	_goal = global_position


func _build_cat() -> void:
	var fur := _mat(Color("f0a04a"))
	var cream := _mat(Color("ffe6c4"))
	var dark := _mat(Color("2a211c"))
	_ball(0.16, fur, Vector3(0, 0.28, 0), Vector3(1.35, 0.85, 0.78))
	_ball(0.1, cream, Vector3(0, 0.24, -0.08), Vector3(0.8, 0.55, 0.5))
	_ball(0.11, fur, Vector3(0, 0.48, -0.1))
	_ear(Vector3(-0.07, 0.58, -0.08), fur)
	_ear(Vector3(0.07, 0.58, -0.08), fur)
	_ball(0.045, dark, Vector3(-0.045, 0.5, -0.18), Vector3(0.85, 1.15, 0.45))
	_ball(0.045, dark, Vector3(0.045, 0.5, -0.18), Vector3(0.85, 1.15, 0.45))
	_ball(0.02, _mat(Color("f2a0b0")), Vector3(0, 0.45, -0.2))
	_leg(Vector3(-0.09, 0.08, -0.08), fur)
	_leg(Vector3(0.09, 0.08, -0.08), fur)
	_leg(Vector3(-0.09, 0.08, 0.1), fur)
	_leg(Vector3(0.09, 0.08, 0.1), fur)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.32, 0.16)
	add_child(tail)
	_ball(0.035, fur, Vector3(0, 0.08, 0.06), Vector3(0.8, 1.4, 0.8), tail)
	_ball(0.03, fur, Vector3(0, 0.18, 0.02), Vector3(0.8, 1.2, 0.8), tail)


func _build_dog() -> void:
	var fur := _mat(Color("f3e2c4"))
	var ear := _mat(Color("c4844a"))
	var dark := _mat(Color("2a211c"))
	_ball(0.16, fur, Vector3(0, 0.3, 0.02), Vector3(1.45, 0.82, 0.75))
	_ball(0.12, fur, Vector3(0, 0.5, -0.16))
	_ball(0.07, fur, Vector3(0, 0.46, -0.26), Vector3(0.7, 0.6, 1.1))
	_ball(0.055, ear, Vector3(-0.1, 0.46, -0.12), Vector3(0.55, 1.35, 0.4))
	_ball(0.055, ear, Vector3(0.1, 0.46, -0.12), Vector3(0.55, 1.35, 0.4))
	_ball(0.04, dark, Vector3(-0.045, 0.54, -0.24), Vector3(0.9, 1.1, 0.45))
	_ball(0.04, dark, Vector3(0.045, 0.54, -0.24), Vector3(0.9, 1.1, 0.45))
	_ball(0.025, dark, Vector3(0, 0.46, -0.32))
	_leg(Vector3(-0.1, 0.08, -0.1), fur)
	_leg(Vector3(0.1, 0.08, -0.1), fur)
	_leg(Vector3(-0.1, 0.08, 0.12), fur)
	_leg(Vector3(0.1, 0.08, 0.12), fur)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.38, 0.18)
	add_child(tail)
	_ball(0.04, fur, Vector3(0, 0.08, 0.02), Vector3(0.7, 1.3, 0.7), tail)


func _ear(pos: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.045
	mesh.height = 0.1
	mesh.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _leg(pos: Vector3, mat: Material) -> void:
	_ball(0.045, mat, pos, Vector3(0.7, 1.1, 0.7))


func _ball(r: float, mat: Material, pos: Vector3, scl := Vector3.ONE, parent: Node = null) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
