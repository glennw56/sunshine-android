extends CharacterBody3D
class_name PlayerExplorer
## PUBG-like TPP bakery walker: camera-relative move, centered follow cam,
## look does not yank the body except by changing where "forward" is.

const CookieProjectileScript := preload("res://scripts/explore/cookie_projectile.gd")
const PumpkinProjectileScript := preload("res://scripts/explore/pumpkin_toss.gd")
const PumpkinPropLib := preload("res://scripts/explore/pumpkin_prop.gd")
const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

@export var walk_speed: float = 2.15
@export var jog_speed: float = 4.25
@export var sprint_speed: float = 6.8
@export var accel: float = 13.0
@export var decel: float = 18.0
@export var gravity: float = 28.0
@export var jump_speed: float = 8.6
@export var mouse_sens: float = 0.36
@export var touch_look_sens: float = 0.36
@export var key_look_speed: float = 2.1

## Behind + slightly above. X stays 0 so the baker is horizontally centered
## (lower-third TPP), not parked on the left from an over-right-shoulder boom.
## CAMERA_BUILD is a readable string left in the exported .gdc so a sideload
## APK can be proven to contain this TPP player (the 0.1.68 git tag did not).
const CAMERA_BUILD := "center_baker_v069"
const SHOULDER := Vector3(0.0, 1.78, 0.12)
const TETHER_LEN := 4.15
## Walk stays centered on SHOULDER. A toss steps the camera to the right
## shoulder so the look ray — where the cookie flies — is not inside the baker.
const TOSS_SHOULDER := Vector3(1.05, 1.92, 0.12)
const TOSS_TETHER := 4.45
const TOSS_SEE_MIN := 0.9
const TOSS_SEE_CAP := 1.75

var joy_vector: Vector2 = Vector2.ZERO
var pitch: float = -0.24
var captured := false
var _toss_cool: float = 0.0
var _avatar: AvatarBody
var _cookie_prop: Node3D
var _pumpkin_prop: Node3D
var _holding_pumpkin := false
var _held_pet: Node3D = null
var _release_pumpkin := false
var _arm: SpringArm3D
var _grounded_once := false
var _look_held := false
var _free_look := false
var _move_yaw: float = 0.0
var _face_yaw: float = 0.0
var _planar_speed: float = 0.0
var _shown_pitch: float = -0.24
var _throw_arming: float = 0.0
var _toss_see: float = 0.0
var _toss_see_cap: float = 0.0
var _toss_cookie: Node3D = null
var _jump_buffered: bool = false
var _knock_vel: Vector3 = Vector3.ZERO
var _knock_left: float = 0.0
var last_hit_msec: int = 0
const PET_REACH := 3.7
var _tap_from := Vector2(-1, -1)

signal toss_blocked_empty

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
	if AppConfig and AppConfig.test_world:
		cap.radius = 0.22
		cap.height = 1.56
		col.position = Vector3(0, 0.78, 0)
	else:
		cap.radius = 0.24
		cap.height = 1.24
		col.position = Vector3(0, 0.62, 0)
	col.shape = cap


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
	_cam.h_offset = 0.0
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
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
		if _toss_view_on():
			_avatar.set_toss_ghost(true)


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
	_cookie_prop = CookieProjectileScript.make_visual(true)
	hand.add_child(_cookie_prop)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		try_jump()
		get_viewport().set_input_as_handled()
		return
	## Keyboard toss stays off Space so jump and cookie throw do not share a key.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		toss_cookie()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if holding_pet():
			try_put_down_pet()
		elif nearest_pet() != null and not _holding_pumpkin:
			try_pickup_pet()
		else:
			try_pickup_pumpkin()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tap_from = event.position
		elif _tap_from.x >= 0.0 and event.position.distance_to(_tap_from) < 26.0:
			try_tap_pet(event.position)
		if not event.pressed:
			_tap_from = Vector2(-1, -1)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_tap_from = touch.position
		else:
			if _tap_from.x >= 0.0 and touch.position.distance_to(_tap_from) < 26.0:
				try_tap_pet(touch.position)
			_tap_from = Vector2(-1, -1)
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


func try_jump() -> bool:
	if not is_inside_tree() or not is_on_floor():
		return false
	_jump_buffered = true
	return true


func holding_pumpkin() -> bool:
	return _holding_pumpkin


func near_pumpkin_bin() -> bool:
	if not AppConfig.test_world:
		return false
	for bin in get_tree().get_nodes_in_group("pumpkin_bin"):
		if bin.has_method("contains_point") and bool(bin.call("contains_point", global_position)):
			return true
	return false


func try_pickup_pumpkin() -> bool:
	if not AppConfig.test_world or _holding_pumpkin or holding_pet() or not near_pumpkin_bin():
		return false
	var hand := _avatar.hand_socket() if _avatar else null
	if hand == null:
		return false
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.visible = false
	_pumpkin_prop = PumpkinPropLib.instantiate()
	_pumpkin_prop.name = "HeldPumpkin"
	hand.add_child(_pumpkin_prop)
	_holding_pumpkin = true
	return true


func holding_pet() -> bool:
	return _held_pet != null and is_instance_valid(_held_pet)


func nearest_pet() -> Node3D:
	if not AppConfig.test_world or holding_pet():
		return null
	var best: Node3D = null
	var best_d := PET_REACH
	for pet in get_tree().get_nodes_in_group("patio_pet"):
		if not pet is Node3D or bool(pet.get("held")):
			continue
		var dist := global_position.distance_to((pet as Node3D).global_position)
		if dist < best_d:
			best_d = dist
			best = pet as Node3D
	return best


func try_tap_pet(screen_pos: Vector2) -> bool:
	if not AppConfig.test_world or holding_pet() or _holding_pumpkin:
		return false
	var pet := _pet_on_screen(screen_pos)
	if pet == null:
		return false
	return try_pickup_pet(pet)


func try_pickup_pet(target: Node = null) -> bool:
	if not AppConfig.test_world or holding_pet() or _holding_pumpkin:
		return false
	var pet: Node3D = target as Node3D if target is Node3D else nearest_pet()
	if pet == null or bool(pet.get("held")):
		return false
	if not pet.is_in_group("patio_pet"):
		return false
	if global_position.distance_to(pet.global_position) > PET_REACH + 1.1:
		return false
	pet.set("held", true)
	if pet.get_parent() != self:
		pet.reparent(self)
	_held_pet = pet
	if _avatar:
		pet.call("follow_chest", _avatar)
	return true


func try_put_down_pet() -> bool:
	if not holding_pet():
		return false
	var home := get_tree().get_first_node_in_group("patio_pets")
	if home == null:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var ahead := global_position + forward * 1.45
	var at := Vector3(ahead.x, 0.0, ahead.z)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var from := Vector3(ahead.x, global_position.y + 1.4, ahead.z)
		var to := Vector3(ahead.x, global_position.y - 8.0, ahead.z)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			at = hit.position
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() < 0.9:
		at += forward * 0.9
	_held_pet.call("place_on_ground", at, home)
	_held_pet = null
	return true


func _pet_on_screen(screen_pos: Vector2) -> Node3D:
	if _cam == null:
		return null
	var best: Node3D = null
	var best_px := 96.0
	for pet in get_tree().get_nodes_in_group("patio_pet"):
		if not pet is Node3D or bool(pet.get("held")):
			continue
		var node := pet as Node3D
		if global_position.distance_to(node.global_position) > PET_REACH + 1.1:
			continue
		for lift in [0.2, 0.45]:
			var world := node.global_position + Vector3(0.0, lift, 0.0)
			if _cam.is_position_behind(world):
				continue
			var sp := _cam.unproject_position(world)
			var dist := sp.distance_to(screen_pos)
			if dist < best_px:
				best_px = dist
				best = node
	return best


func toss_cookie() -> bool:
	if holding_pet():
		return false
	if _toss_cool > 0.0 or _throw_arming > 0.0 or not is_inside_tree():
		return false
	if _holding_pumpkin:
		_toss_cool = 0.52
		_throw_arming = 0.12
		_release_pumpkin = true
		_toss_see = TOSS_SEE_MIN
		_toss_see_cap = TOSS_SEE_CAP
		_kick_toss_camera()
		if _avatar:
			_avatar.play_throw()
			_avatar.set_toss_ghost(true)
		return true
	if not GameSave.spend_throw_cookie():
		toss_blocked_empty.emit()
		return false
	_toss_cool = 0.52
	_throw_arming = 0.12
	_toss_see = TOSS_SEE_MIN
	_toss_see_cap = TOSS_SEE_CAP
	_kick_toss_camera()
	if _avatar:
		_avatar.play_throw()
		_avatar.set_toss_ghost(true)
	return true


func toss_ghost_alpha() -> float:
	if _avatar and _avatar.has_method("toss_ghost_alpha"):
		return float(_avatar.toss_ghost_alpha())
	return 1.0


func _toss_view_on() -> bool:
	return _throw_arming > 0.0 or _toss_see > 0.0


func _kick_toss_camera() -> void:
	if _arm == null:
		return
	_arm.position = _arm.position.lerp(TOSS_SHOULDER, 0.72)
	_arm.spring_length = lerpf(_arm.spring_length, TOSS_TETHER, 0.72)


func _aim_forward() -> Vector3:
	var forward := -global_transform.basis.z
	if _arm:
		forward = -_arm.global_transform.basis.z
	elif _cam:
		forward = -_cam.global_transform.basis.z
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _toss_spawn(forward: Vector3) -> Vector3:
	## Release on the camera look ray, past the chibi, instead of inside the
	## hand. The hand sits in the torso silhouette, so a cookie born there
	## never clears the local baker.
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0004:
		flat = -global_transform.basis.z
		flat.y = 0.0
	if flat.length_squared() < 0.0004:
		flat = Vector3(0.0, 0.0, -1.0)
	flat = flat.normalized()
	var cam_pos := global_position + Vector3(0.0, 2.4, 4.0)
	if _arm:
		cam_pos = _arm.to_global(Vector3(0.0, 0.0, _arm.spring_length))
	elif _cam:
		cam_pos = _cam.global_position
	var front := global_position + flat * 0.85
	var denom := forward.dot(flat)
	var travel := 1.8
	if absf(denom) > 0.08:
		travel = (front - cam_pos).dot(flat) / denom
	travel = clampf(travel, 0.45, 9.0)
	var origin := cam_pos + forward * travel
	var planar := origin - global_position
	planar.y = 0.0
	if planar.length() < 0.7:
		origin += flat * (0.7 - planar.length())
	return origin


func _update_toss_visibility(delta: float) -> void:
	var flying := false
	if _toss_cookie != null and is_instance_valid(_toss_cookie):
		flying = not bool(_toss_cookie.get("_did_burst"))
	else:
		_toss_cookie = null
	if flying and _toss_see_cap > 0.0:
		_toss_see = maxf(_toss_see, 0.32)
	if _toss_see_cap > 0.0:
		_toss_see_cap = maxf(0.0, _toss_see_cap - delta)
	if _toss_see > 0.0:
		_toss_see = maxf(0.0, _toss_see - delta)
	if _avatar:
		_avatar.set_toss_ghost(_toss_view_on())
	if not _toss_view_on():
		_toss_cookie = null


func _apply_follow_camera(delta: float) -> void:
	if _arm == null:
		return
	_arm.rotation.x = _shown_pitch
	var tossing := _toss_view_on()
	var rate := 22.0 if tossing else 8.0
	var shoulder := TOSS_SHOULDER if tossing else SHOULDER
	var tether := TOSS_TETHER if tossing else TETHER_LEN
	var blend := clampf(delta * rate, 0.0, 1.0)
	_arm.position = _arm.position.lerp(shoulder, blend)
	_arm.spring_length = lerpf(_arm.spring_length, tether, blend)
	if not tossing and _arm.position.distance_to(SHOULDER) < 0.02 and absf(_arm.spring_length - TETHER_LEN) < 0.02:
		_arm.position = SHOULDER
		_arm.spring_length = TETHER_LEN


func _release_held_pumpkin() -> void:
	_release_pumpkin = false
	var shot := PumpkinProjectileScript.new()
	var host := get_parent()
	if host == null:
		return
	host.add_child(shot)
	shot.exclude_rids = [get_rid()]
	var forward := _aim_forward()
	var origin := _toss_spawn(forward)
	if _pumpkin_prop and is_instance_valid(_pumpkin_prop):
		_pumpkin_prop.queue_free()
	_pumpkin_prop = null
	_holding_pumpkin = false
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.visible = true
	shot.global_position = origin
	shot.velocity = (forward + Vector3(0, 0.1, 0)).normalized() * 11.0
	_toss_cookie = shot
	shot.proj_id = "pk_%s_%d" % [ProfileStore.player_id, Time.get_ticks_msec()]
	shot.owner_net_id = ExploreNet.net_id
	ExploreNet.send_throw(origin, shot.velocity, shot.proj_id)
	if not shot.impacted.is_connected(_on_cookie_impact):
		shot.impacted.connect(_on_cookie_impact)


func _release_cookie() -> void:
	var cookie := CookieProjectileScript.new()
	var host := get_parent()
	if host == null:
		return
	host.add_child(cookie)
	cookie.exclude_rids = [get_rid()]
	var forward := _aim_forward()
	var origin := _toss_spawn(forward)
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.visible = false
		get_tree().create_timer(0.42).timeout.connect(func():
			if is_instance_valid(_cookie_prop):
				_cookie_prop.visible = true
		)
	cookie.global_position = origin
	cookie.velocity = (forward + Vector3(0, 0.08, 0)).normalized() * 12.0
	_toss_cookie = cookie
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
	## Own throws only reach this signal. Score a hit on someone else, not a wall or yourself.
	if who == "" or who == str(ExploreNet.net_id):
		return
	var result: Dictionary = GameSave.record_baker_hit(id)
	if not bool(result.get("counted", false)):
		return
	var hud := get_tree().get_first_node_in_group("explore_hud")
	if hud and hud.has_method("on_baker_hit"):
		hud.call("on_baker_hit", int(result.get("hits", 0)))


func _stick_speed(mag: float) -> float:
	if mag < 0.12:
		return 0.0
	if mag < 0.48:
		return lerpf(walk_speed * 0.72, walk_speed, (mag - 0.12) / 0.36)
	if mag < 0.84:
		return lerpf(walk_speed, jog_speed, (mag - 0.48) / 0.36)
	return lerpf(jog_speed, sprint_speed, (mag - 0.84) / 0.16)


func _physics_process(delta: float) -> void:
	_update_toss_visibility(delta)
	if holding_pet() and _avatar:
		_held_pet.call("follow_chest", _avatar)
	if _throw_arming > 0.0:
		_throw_arming = maxf(0.0, _throw_arming - delta)
		if _throw_arming <= 0.0:
			if _release_pumpkin:
				_release_held_pumpkin()
			else:
				_release_cookie()
	if _toss_cool > 0.0:
		_toss_cool = maxf(0.0, _toss_cool - delta)
	## Throw is animation-only. Stick / WASD must keep moving, including strafe.
	var jumping := _jump_buffered and is_on_floor()
	_jump_buffered = false
	if not is_on_floor():
		velocity.y -= gravity * delta
		floor_snap_length = 0.55
	elif jumping:
		## Snap would glue a short hop back onto the grass.
		velocity.y = jump_speed
		floor_snap_length = 0.0
	else:
		velocity.y = 0.0
		floor_snap_length = 0.55
		if not _grounded_once:
			_grounded_once = true
	if not _look_held:
		_shown_pitch = lerpf(_shown_pitch, pitch, clampf(delta * 10.0, 0.0, 1.0))
	_apply_follow_camera(delta)
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
