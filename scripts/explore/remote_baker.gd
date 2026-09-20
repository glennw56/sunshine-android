extends Node3D
## Other signed-in bakers on the hosted patio. Interpolated, never authoritative.

const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

var net_id: String = ""
var last_hit_msec: int = 0
var _avatar: AvatarBody
var _target: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _recipe: Dictionary = {}
var _cookie_prop: Node3D
var _knock_vel: Vector3 = Vector3.ZERO
var _knock_left: float = 0.0


func setup(row: Dictionary) -> void:
	net_id = str(row.get("net_id", ""))
	name = "Remote_%s" % net_id
	add_to_group("remote_baker")
	_avatar = AvatarBodyScript.new()
	add_child(_avatar)
	apply_row(row, true)


func apply_knockback(from: Vector3, speed: float = 8.4) -> void:
	var dir := global_position - from
	dir.y = 0.0
	if dir.length_squared() < 0.0004:
		dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_knock_vel = dir.normalized() * speed
	_knock_left = 0.45
	last_hit_msec = Time.get_ticks_msec()
	if _avatar:
		_avatar.play_throw(true)


func apply_row(row: Dictionary, snap: bool = false) -> void:
	_target = Vector3(float(row.get("x", 0.0)), float(row.get("y", 0.02)), float(row.get("z", 11.0)))
	_target_yaw = float(row.get("yaw", 0.0))
	if snap:
		global_position = _target
		rotation.y = _target_yaw
	var recipe: Variant = row.get("avatar", {})
	if recipe is Dictionary and not recipe.is_empty():
		if str(recipe) != str(_recipe):
			_recipe = recipe
			_avatar.rebuild(recipe, str(row.get("display_name", "Baker")))
			_cookie_prop = null
	_avatar.set_nameplate(str(row.get("display_name", "Baker")))
	_avatar.set_moving(bool(row.get("moving", false)))
	_ensure_hand_cookie()


func play_throw(skip_windup := true) -> void:
	if _avatar:
		_avatar.play_throw(skip_windup)
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.visible = false
		get_tree().create_timer(0.42).timeout.connect(func():
			if is_instance_valid(_cookie_prop):
				_cookie_prop.visible = true
		)


func hand_position() -> Vector3:
	if _avatar and _avatar.hand_socket():
		return _avatar.hand_socket().global_position
	return global_position + Vector3(0, 0.78, 0)


func _ensure_hand_cookie() -> void:
	if _cookie_prop and is_instance_valid(_cookie_prop):
		return
	var hand := _avatar.hand_socket() if _avatar else null
	if hand == null:
		return
	# Cheap unshaded disc — a full cookie GLB on every remote hits mid phones.
	var mi := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.04
	ball.radial_segments = 8
	ball.rings = 4
	mi.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("f3e2c4")
	mi.material_override = mat
	_cookie_prop = mi
	hand.add_child(_cookie_prop)


func _process(delta: float) -> void:
	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		global_position += _knock_vel * delta
		global_position.y = _target.y
		_knock_vel *= 0.86
	else:
		global_position = global_position.lerp(_target, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	if _avatar:
		var viewer := Vector3.ZERO
		var local := get_tree().get_first_node_in_group("local_baker") as Node3D
		if local:
			viewer = local.global_position
		_avatar.update_nameplate_for(viewer)
