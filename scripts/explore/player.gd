extends CharacterBody3D
class_name PlayerExplorer
## PUBG-like TPP bakery walker: camera-relative move, over-shoulder cam,
## look does not yank the body except by changing where "forward" is.

const CookieProjectileScript := preload("res://scripts/explore/cookie_projectile.gd")
const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

@export var walk_speed: float = 2.15
@export var jog_speed: float = 4.25
@export var sprint_speed: float = 6.8
@export var accel: float = 13.0
@export var decel: float = 18.0
@export var gravity: float = 28.0
@export var mouse_sens: float = 0.36
@export var touch_look_sens: float = 0.36
@export var key_look_speed: float = 2.1

## Behind + slightly above, mild over-right-shoulder. Baker sits lower-left
## so the patio ahead stays readable. Steady tether — no floaty boom.
const SHOULDER := Vector3(0.68, 1.78, 0.12)
const TETHER_LEN := 4.15

var joy_vector: Vector2 = Vector2.ZERO
var pitch: float = -0.24
var captured := false
var _toss_cool: float = 0.0
var _avatar: AvatarBody
var _cookie_prop: Node3D
var _arm: SpringArm3D
var _grounded_once := false
var _look_held := false
var _free_look := false
var _move_yaw: float = 0.0
var _face_yaw: float = 0.0
var _planar_speed: float = 0.0
var _shown_pitch: float = -0.24
var _throw_arming: float = 0.0
var _knock_vel: Vector3 = Vector3.ZERO
var _knock_left: float = 0.0
var last_hit_msec: int = 0

@onready var _cam: Camera3D = $Camera3D


func _ready() -> void:
	add_to_group("local_baker")
	up_direction = Vector3.UP
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(52.0)
	_setup_collision()
	_setup_camera()
	_avatar = AvatarBodyScript.new()
	_avatar.name = "Avatar"
	add_child(_avatar)
	_avatar.hide_nameplate()
	_hold_practice_cookie()
	if not ProfileStore.avatar_changed.is_connected(_on_avatar_changed):
		ProfileStore.avatar_changed.connect(_on_avatar_changed)
	if not ProfileStore.identity_changed.is_connected(_on_identity_changed):
		ProfileStore.identity_changed.connect(_on_identity_changed)
	call_deferred("snap_to_ground")


func _setup_collision() -> void:
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "Collision"
		add_child(col)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 1.24
	col.shape = cap
	col.position = Vector3(0, 0.62, 0)


func _setup_camera() -> void:
	if _cam == null:
		return
	_arm = get_node_or_null("SpringArm") as SpringArm3D
	if _arm == null:
		_arm = SpringArm3D.new()
		_arm.name = "SpringArm"
		add_child(_arm)
	_arm.spring_length = TETHER_LEN
	_arm.position = SHOULDER
	_arm.collision_mask = 1
	_arm.margin = 0.42
	_shown_pitch = pitch
	_arm.rotation.x = _shown_pitch
	if _cam.get_parent() != _arm:
		_cam.get_parent().remove_child(_cam)
		_arm.add_child(_cam)
	_cam.position = Vector3.ZERO
	_cam.rotation = Vector3.ZERO
	_cam.current = true
	_cam.fov = 58.0


func snap_to_ground() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		global_position.y = 0.02
		return
	var from := Vector3(global_position.x, global_position.y + 8.0, global_position.z)
	var to := Vector3(global_position.x, global_position.y - 14.0, global_position.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var hy := float(hit.position.y)
		if hy > -0.2 and hy < 1.2:
			global_position.y = hy
		else:
			global_position.y = 0.02
	else:
		global_position.y = 0.02
	velocity.y = 0.0
	_grounded_once = true


func _on_avatar_changed(recipe: Dictionary) -> void:
	if _avatar:
		_avatar.rebuild(recipe)
		_hold_practice_cookie()


func _on_identity_changed() -> void:
	if _avatar:
		_avatar.set_nameplate(ProfileStore.display_name)


func _hold_practice_cookie() -> void:
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.queue_free()
	_cookie_prop = null
	var hand := _avatar.hand_socket() if _avatar else null
	if hand == null:
		return
	var MenuPropsLib := preload("res://scripts/explore/menu_props.gd")
	_cookie_prop = MenuPropsLib.instantiate_cookie()
	_cookie_prop.scale = Vector3(1.6, 1.6, 1.6)
	hand.add_child(_cookie_prop)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		toss_cookie()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		captured = not captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			captured = true
			set_looking(true)
		else:
			captured = false
			set_looking(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if captured:
			captured = false
			set_looking(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and captured:
		_look(event.relative)


func _look(relative: Vector2) -> void:
	## 1:1 with the finger while dragging. rotation.y is camera yaw.
	rotate_y(-relative.x * mouse_sens * 0.01)
	pitch = clampf(pitch - relative.y * mouse_sens * 0.01, -0.95, 0.38)
	if _look_held:
		_shown_pitch = pitch
		if _arm:
			_arm.rotation.x = _shown_pitch
	if not _free_look:
		_move_yaw = rotation.y


func apply_touch_look(relative: Vector2) -> void:
	_look(relative * (touch_look_sens / mouse_sens))


func set_looking(on: bool) -> void:
	if on and not _look_held and joy_vector.length() > 0.22:
		_free_look = true
		_move_yaw = rotation.y
	if not on:
		_free_look = false
		_move_yaw = rotation.y
	_look_held = on


func toss_cookie() -> bool:
	if _toss_cool > 0.0 or _throw_arming > 0.0 or not is_inside_tree():
		return false
	_toss_cool = 0.52
	_throw_arming = 0.12
	if _avatar:
		_avatar.play_throw()
	return true


func _release_cookie() -> void:
	var cookie := CookieProjectileScript.new()
	var host := get_parent()
	if host == null:
		return
	host.add_child(cookie)
	cookie.exclude_rids = [get_rid()]
	var forward := -_cam.global_transform.basis.z
	var origin := global_position + Vector3(0, 0.78, 0) + -transform.basis.z * 0.35
	if _avatar and _avatar.hand_socket():
		origin = _avatar.hand_socket().global_position
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.visible = false
		get_tree().create_timer(0.42).timeout.connect(func():
			if is_instance_valid(_cookie_prop):
				_cookie_prop.visible = true
		)
	cookie.global_position = origin
	cookie.velocity = (forward + Vector3(0, 0.08, 0)).normalized() * 12.0
	cookie.proj_id = "ck_%s_%d" % [ProfileStore.player_id, Time.get_ticks_msec()]
	cookie.owner_net_id = ExploreNet.net_id
	ExploreNet.send_throw(origin, cookie.velocity, cookie.proj_id)
	if not cookie.impacted.is_connected(_on_cookie_impact):
		cookie.impacted.connect(_on_cookie_impact)


func apply_knockback(from: Vector3, speed: float = 14.0) -> void:
	var dir := global_position - from
	dir.y = 0.0
	if dir.length_squared() < 0.0004:
		dir = -transform.basis.z
	_knock_vel = dir.normalized() * maxf(speed, 14.0)
	_knock_left = 0.62
	last_hit_msec = Time.get_ticks_msec()
	pitch = clampf(pitch + 0.16, -0.95, 0.38)
	_shown_pitch = pitch
	if _arm:
		_arm.rotation.x = _shown_pitch
	if _avatar and _avatar.has_method("play_hit"):
		_avatar.play_hit()
	elif _avatar:
		_avatar.play_throw(true)


func _on_cookie_impact(at: Vector3, id: String, who: String = "") -> void:
	ExploreNet.send_impact(at, id, who)


func _stick_speed(mag: float) -> float:
	if mag < 0.12:
		return 0.0
	if mag < 0.48:
		return lerpf(walk_speed * 0.72, walk_speed, (mag - 0.12) / 0.36)
	if mag < 0.84:
		return lerpf(walk_speed, jog_speed, (mag - 0.48) / 0.36)
	return lerpf(jog_speed, sprint_speed, (mag - 0.84) / 0.16)


func _physics_process(delta: float) -> void:
	if _throw_arming > 0.0:
		_throw_arming = maxf(0.0, _throw_arming - delta)
		if _throw_arming <= 0.0:
			_release_cookie()
	if _toss_cool > 0.0:
		_toss_cool = maxf(0.0, _toss_cool - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		if not _grounded_once:
			_grounded_once = true
	if not _look_held:
		_shown_pitch = lerpf(_shown_pitch, pitch, clampf(delta * 10.0, 0.0, 1.0))
	if _arm:
		_arm.rotation.x = _shown_pitch
		_arm.position = _arm.position.lerp(SHOULDER, clampf(delta * 8.0, 0.0, 1.0))
		_arm.spring_length = TETHER_LEN
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward")
	)
	input += joy_vector
	input = input.limit_length(1.0)
	var basis_yaw := _move_yaw if _free_look else rotation.y
	var basis_flat := Transform3D(Basis(Vector3.UP, basis_yaw), Vector3.ZERO)
	var wish := (basis_flat.basis * Vector3(input.x, 0, -input.y))
	if wish.length() > 0.05:
		wish = wish.normalized()
	else:
		wish = Vector3.ZERO
	var target := _stick_speed(input.length())
	var rate := accel if target > _planar_speed else decel
	_planar_speed = move_toward(_planar_speed, target, rate * delta)
	velocity.x = wish.x * _planar_speed
	velocity.z = wish.z * _planar_speed
	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x += _knock_vel.x
		velocity.z += _knock_vel.z
		_knock_vel *= 0.90
	var look_x := 0.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT):
		look_x -= 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_RIGHT):
		look_x += 1.0
	if absf(look_x) > 0.01:
		rotate_y(-look_x * key_look_speed * delta)
		if not _free_look:
			_move_yaw = rotation.y
	move_and_slide()
	if wish.length() > 0.05:
		var face := atan2(-wish.x, -wish.z)
		var local := wrapf(face - rotation.y, -PI, PI)
		_face_yaw = lerp_angle(_face_yaw, local, clampf(delta * 10.0, 0.0, 1.0))
	else:
		_face_yaw = lerp_angle(_face_yaw, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if _avatar:
		_avatar.rotation.y = _face_yaw
		_avatar.set_moving(wish.length() > 0.05)
	if global_position.y < -2.0:
		global_position = Vector3(0.0, 0.08, 11.0)
		velocity = Vector3.ZERO
		snap_to_ground()
