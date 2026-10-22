extends RigidBody3D
## Bakery golf ball. A smooth sphere, the same radius as the SphereShape3D.
## The old golf_ball.glb was a low-poly dimpled mesh (and imported with LODs),
## so on a phone it read as a faceted lump. Nothing in this branch scales it.

const Catalog := preload("res://scripts/minigolf/catalog.gd")

var _trail: CPUParticles3D
var _logged_scale := false
var _vy_before := 0.0
var _strip_up := false


func _ready() -> void:
	name = "GolfBall"
	scale = Vector3.ONE
	mass = Catalog.BALL_MASS
	gravity_scale = Catalog.BALL_GRAVITY
	linear_damp = Catalog.BALL_LINEAR_DAMP
	angular_damp = Catalog.BALL_ANGULAR_DAMP
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 8
	collision_layer = 1
	collision_mask = 1
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var mat := PhysicsMaterial.new()
	mat.friction = Catalog.BALL_FRICTION
	mat.bounce = Catalog.BALL_BOUNCE
	physics_material_override = mat
	var shape := CollisionShape3D.new()
	shape.name = "BallShape"
	shape.position = Vector3.ZERO
	shape.scale = Vector3.ONE
	var sphere := SphereShape3D.new()
	sphere.radius = Catalog.BALL_RADIUS
	shape.shape = sphere
	add_child(shape)
	_visual()
	_shadow()
	_trail = CPUParticles3D.new()
	_trail.amount = 10
	_trail.lifetime = 0.28
	_trail.local_coords = false
	_trail.direction = Vector3.UP
	_trail.spread = 18.0
	_trail.gravity = Vector3.ZERO
	_trail.initial_velocity_min = 0.02
	_trail.initial_velocity_max = 0.08
	_trail.scale_amount_min = 0.25
	_trail.scale_amount_max = 0.45
	_trail.color = Color("fff6ea")
	_trail.emitting = false
	var puff := SphereMesh.new()
	puff.radius = 0.012
	puff.height = 0.024
	puff.radial_segments = 12
	puff.rings = 8
	var puff_mat := StandardMaterial3D.new()
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.albedo_color = Color(1, 0.95, 0.9, 0.45)
	puff.material = puff_mat
	_trail.mesh = puff
	add_child(_trail)
	call_deferred("_keep_round")


func _visual() -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "BallMesh"
	mesh_node.position = Vector3.ZERO
	mesh_node.scale = Vector3.ONE
	var mesh := SphereMesh.new()
	mesh.radius = Catalog.BALL_RADIUS
	mesh.height = Catalog.BALL_RADIUS * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	mesh_node.mesh = mesh
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.material_override = _round_material()
	add_child(mesh_node)


func _round_material() -> ShaderMaterial:
	# Unshaded view-space lighting so the ball stays round under the flat
	# ambient sky. A plain unshaded color reads as a disc.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.99, 0.97, 0.93, 1.0);
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 light = normalize(vec3(0.32, 0.74, 0.59));
	float ndl = clamp(dot(n, light), 0.0, 1.0);
	float wrap = ndl * 0.62 + 0.38;
	float spec = pow(clamp(dot(n, normalize(vec3(0.15, 0.55, 0.82))), 0.0, 1.0), 36.0);
	float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.4);
	ALBEDO = base_color.rgb * wrap + vec3(1.0, 0.98, 0.95) * spec * 0.55 + vec3(0.55, 0.32, 0.34) * rim * 0.18;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _shadow() -> void:
	var blob := MeshInstance3D.new()
	blob.name = "BlobShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.05
	disc.bottom_radius = 0.05
	disc.height = 0.004
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.15, 0.08, 0.08, 0.28)
	disc.material = mat
	blob.mesh = disc
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position = Vector3(0, -Catalog.BALL_RADIUS + 0.006, 0)
	blob.scale = Vector3.ONE
	add_child(blob)


func _keep_round() -> void:
	# A scaled parent would squash the sphere and the collider together.
	# Counter it so the world scale stays 1,1,1 and the shape matches the mesh.
	if scale.distance_to(Vector3.ONE) > 0.001:
		scale = Vector3.ONE
	if get_parent() is Node3D:
		var parent_scale := (get_parent() as Node3D).global_transform.basis.get_scale()
		if parent_scale.distance_to(Vector3.ONE) > 0.001 and parent_scale.x != 0.0 and parent_scale.y != 0.0 and parent_scale.z != 0.0:
			scale = Vector3(1.0 / parent_scale.x, 1.0 / parent_scale.y, 1.0 / parent_scale.z)
	if _logged_scale:
		return
	_logged_scale = true
	var world_scale := global_transform.basis.get_scale()
	print("BALL world_scale ", world_scale, " mesh_r ", Catalog.BALL_RADIUS, " shape_r ", Catalog.BALL_RADIUS)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var velocity := state.linear_velocity
	_vy_before = velocity.y
	_strip_up = false
	var basis := state.transform.basis
	for i in state.get_contact_count():
		var normal := basis * state.get_contact_local_normal(i)
		if normal.length() < 0.001:
			continue
		normal = normal.normalized()
		var sideways := Vector2(normal.x, normal.z).length()
		var approach := -velocity.dot(normal)
		# Only a near-vertical wall. A loop or a funnel slope must keep its climb.
		if sideways > 0.92 and approach > 2.2 and normal.y > -0.05 and normal.y < 0.4:
			_strip_up = true
	if velocity.length() > _speed_cap():
		state.linear_velocity = velocity.limit_length(_speed_cap())


func _physics_process(_delta: float) -> void:
	_keep_round()
	var velocity := linear_velocity
	var changed := false
	if _strip_up and velocity.y > _vy_before + 0.2:
		velocity.y = minf(velocity.y, maxf(_vy_before, 0.0))
		changed = true
	if velocity.length() > _speed_cap():
		velocity = velocity.limit_length(_speed_cap())
		changed = true
	if changed:
		linear_velocity = velocity
	if _trail:
		_trail.emitting = not freeze and linear_velocity.length() > 0.45


func _speed_cap() -> float:
	return Catalog.MAX_PUTT_SPEED * 1.25


func launch(dir: Vector3, speed: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(0, 0, -1)
	flat = flat.normalized()
	freeze = false
	sleeping = false
	# Step out of a rail or lip the ball is resting against.
	global_position += flat * 0.04
	linear_velocity = flat * speed
	angular_velocity = Vector3(flat.z, 0.0, -flat.x) * (speed / Catalog.BALL_RADIUS) * 0.22


func park(at: Vector3) -> void:
	global_position = at
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	freeze = true


func is_slow() -> bool:
	return linear_velocity.length() < Catalog.STOP_SPEED and angular_velocity.length() < 1.1
