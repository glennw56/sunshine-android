extends RigidBody3D
## Bakery golf ball. CCD so a full-power putt does not tunnel the rails.
## The mesh is the supplied golf_ball.glb (radius 0.06, origin at centre).

const Catalog := preload("res://scripts/minigolf/catalog.gd")
const Look := preload("res://scripts/explore/authored_look.gd")
const BALL_GLB := "res://assets/minigolf/golf_ball/golf_ball.glb"

var _trail: CPUParticles3D


func _ready() -> void:
	name = "GolfBall"
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
	var sphere := SphereShape3D.new()
	sphere.radius = Catalog.BALL_RADIUS
	shape.shape = sphere
	add_child(shape)
	_visual()
	_shadow()
	_trail = CPUParticles3D.new()
	_trail.amount = 16
	_trail.lifetime = 0.32
	_trail.local_coords = false
	_trail.direction = Vector3.UP
	_trail.spread = 18.0
	_trail.gravity = Vector3.ZERO
	_trail.initial_velocity_min = 0.02
	_trail.initial_velocity_max = 0.08
	_trail.scale_amount_min = 0.035
	_trail.scale_amount_max = 0.07
	_trail.color = Color("fff6ea")
	_trail.emitting = false
	var puff := SphereMesh.new()
	puff.radius = 0.045
	puff.height = 0.09
	var puff_mat := StandardMaterial3D.new()
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.albedo_color = Color(1, 0.95, 0.9, 0.55)
	puff.material = puff_mat
	_trail.mesh = puff
	add_child(_trail)


func _visual() -> void:
	if not ResourceLoader.exists(BALL_GLB):
		return
	var packed := load(BALL_GLB) as PackedScene
	if packed == null:
		return
	var mesh := packed.instantiate()
	add_child(mesh)
	Look.apply(mesh)


func _shadow() -> void:
	var blob := MeshInstance3D.new()
	blob.name = "BlobShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.008
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.15, 0.08, 0.08, 0.35)
	disc.material = mat
	blob.mesh = disc
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position = Vector3(0, -Catalog.BALL_RADIUS + 0.012, 0)
	add_child(blob)


func _physics_process(_delta: float) -> void:
	if _trail:
		_trail.emitting = not freeze and linear_velocity.length() > 0.45


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
