extends Node3D
## Other signed-in bakers on the hosted patio. Interpolated, never authoritative.

const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")
const SNAP_DIST := 8.0
const MAX_EXTRAP_SEC := 0.24
const MAX_SAMPLES := 8

var net_id: String = ""
var last_hit_msec: int = 0
var _avatar: AvatarBody
var _target: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _recipe: Dictionary = {}
var _cookie_prop: Node3D
var _knock_vel: Vector3 = Vector3.ZERO
var _knock_left: float = 0.0
var _samples: Array = []


func setup(row: Dictionary) -> void:
	net_id = str(row.get("net_id", ""))
	name = "Remote_%s" % net_id
	add_to_group("remote_baker")
	_avatar = AvatarBodyScript.new()
	add_child(_avatar)
	apply_row(row, true)


func apply_knockback(from: Vector3, speed: float = 14.0) -> void:
	var dir := global_position - from
	dir.y = 0.0
	if dir.length_squared() < 0.0004:
		dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_knock_vel = dir.normalized() * maxf(speed, 14.0)
	_knock_left = 0.62
	last_hit_msec = Time.get_ticks_msec()
	if _avatar and _avatar.has_method("play_hit"):
		_avatar.play_hit()
	elif _avatar:
		_avatar.play_throw(true)


func apply_row(row: Dictionary, snap: bool = false) -> void:
	var pos := Vector3(float(row.get("x", 0.0)), float(row.get("y", 0.02)), float(row.get("z", 11.0)))
	var yaw := float(row.get("yaw", 0.0))
	var vel := Vector3(float(row.get("vx", 0.0)), 0.0, float(row.get("vz", 0.0)))
	var moving := bool(row.get("moving", false))
	_push_sample(pos, yaw, vel, moving, snap)
	var recipe: Variant = row.get("avatar", {})
	if recipe is Dictionary and not recipe.is_empty():
		if str(recipe) != str(_recipe):
			_recipe = recipe
			_avatar.rebuild(recipe, str(row.get("display_name", "Baker")))
			_cookie_prop = null
	_avatar.set_nameplate(str(row.get("display_name", "Baker")))
	_avatar.set_moving(moving)
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


func _delay_ms() -> int:
	return 180 if ExploreNet.transport() == "http" else 100


func _push_sample(pos: Vector3, yaw: float, vel: Vector3, moving: bool, snap: bool) -> void:
	var now := Time.get_ticks_msec()
	if not _samples.is_empty() and vel.length_squared() < 0.0004:
		var last: Dictionary = _samples[_samples.size() - 1]
		var dt := maxf((now - int(last["t"])) / 1000.0, 0.016)
		vel = (pos - (last["pos"] as Vector3)) / dt
		vel.y = 0.0
		if vel.length() > 8.4:
			vel = vel.limit_length(8.4)
	if snap or pos.distance_to(global_position) > SNAP_DIST:
		_samples.clear()
		global_position = pos
		rotation.y = yaw
	_target = pos
	_target_yaw = yaw
	_samples.append({
		"t": now,
		"pos": pos,
		"yaw": yaw,
		"vel": vel,
		"moving": moving,
	})
	while _samples.size() > MAX_SAMPLES:
		_samples.remove_at(0)


func _sample_at(render_t: int) -> Dictionary:
	if _samples.is_empty():
		return {}
	if _samples.size() == 1 or render_t <= int(_samples[0]["t"]):
		return _samples[0]
	var last: Dictionary = _samples[_samples.size() - 1]
	if render_t >= int(last["t"]):
		return last
	for i in range(_samples.size() - 1):
		var a: Dictionary = _samples[i]
		var b: Dictionary = _samples[i + 1]
		if render_t <= int(b["t"]):
			var span := maxi(int(b["t"]) - int(a["t"]), 1)
			var alpha := clampf(float(render_t - int(a["t"])) / float(span), 0.0, 1.0)
			return {
				"pos": (a["pos"] as Vector3).lerp(b["pos"] as Vector3, alpha),
				"yaw": lerp_angle(float(a["yaw"]), float(b["yaw"]), alpha),
				"vel": (a["vel"] as Vector3).lerp(b["vel"] as Vector3, alpha),
				"moving": bool(b["moving"]),
				"t": render_t,
			}
	return last


func _process(delta: float) -> void:
	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		global_position += _knock_vel * delta
		global_position.y = _target.y
		_knock_vel *= 0.90
	elif not _samples.is_empty():
		var render_t := Time.get_ticks_msec() - _delay_ms()
		var pose := _sample_at(render_t)
		var last: Dictionary = _samples[_samples.size() - 1]
		if render_t > int(last["t"]):
			var late := minf((render_t - int(last["t"])) / 1000.0, MAX_EXTRAP_SEC)
			var pred: Vector3 = (last["pos"] as Vector3) + (last["vel"] as Vector3) * late
			if pred.distance_to(global_position) > SNAP_DIST:
				global_position = pred
			else:
				global_position = global_position.lerp(pred, clampf(delta * 14.0, 0.0, 1.0))
			rotation.y = lerp_angle(rotation.y, float(last["yaw"]), clampf(delta * 10.0, 0.0, 1.0))
			if _avatar:
				_avatar.set_moving(bool(last["moving"]) or late > 0.02)
		elif not pose.is_empty():
			global_position = pose["pos"]
			rotation.y = float(pose["yaw"])
			if _avatar:
				_avatar.set_moving(bool(pose["moving"]))
	else:
		global_position = global_position.lerp(_target, clampf(delta * 12.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	if _avatar:
		var viewer := Vector3.ZERO
		var local := get_tree().get_first_node_in_group("local_baker") as Node3D
		if local:
			viewer = local.global_position
		_avatar.update_nameplate_for(viewer)
