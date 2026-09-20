extends CharacterBody3D
class_name PlayerExplorer

const CookieProjectileScript := preload("res://scripts/explore/cookie_projectile.gd")
const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

@export var speed: float = 6.4
@export var gravity: float = 28.0
@export var mouse_sens: float = 0.22
@export var touch_look_sens: float = 0.28
@export var key_look_speed: float = 2.1

var joy_vector: Vector2 = Vector2.ZERO
var pitch: float = -0.16
var captured := false
var _toss_cool: float = 0.0
var _avatar: AvatarBody
var _cookie_prop: Node3D
var _arm: SpringArm3D
var _grounded_once := false

@onready var _cam: Camera3D = $Camera3D


func _ready() -> void:
	up_direction = Vector3.UP
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(52.0)
	_setup_collision()
	_setup_camera()
	_avatar = AvatarBodyScript.new()
	_avatar.name = "Avatar"
	add_child(_avatar)
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
	## Origin is the soles. Capsule sits on the feet, not around the chest.
	col.position = Vector3(0, 0.62, 0)


func _setup_camera() -> void:
	if _cam == null:
		return
	_arm = get_node_or_null("SpringArm") as SpringArm3D
	if _arm == null:
		_arm = SpringArm3D.new()
		_arm.name = "SpringArm"
		add_child(_arm)
	_arm.spring_length = 3.55
	_arm.position = Vector3(0.28, 1.36, 0.0)
	_arm.collision_mask = 1
	_arm.margin = 0.18
	_arm.rotation.x = pitch
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
		global_position.y = float(hit.position.y)
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
		else:
			captured = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if captured:
			captured = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and captured:
		_look(event.relative)


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sens * 0.01)
	pitch = clampf(pitch - relative.y * mouse_sens * 0.01, -1.05, 0.45)
	if _arm:
		_arm.rotation.x = pitch


func apply_touch_look(relative: Vector2) -> void:
	_look(relative * (touch_look_sens / mouse_sens))


func toss_cookie() -> bool:
	if _toss_cool > 0.0 or not is_inside_tree():
		return false
	_toss_cool = 0.34
	var cookie := CookieProjectileScript.new()
	var host := get_parent()
	if host == null:
		return false
	host.add_child(cookie)
	cookie.exclude_rids = [get_rid()]
	var forward := -_cam.global_transform.basis.z
	var origin := global_position + Vector3(0, 0.78, 0) + -transform.basis.z * 0.35
	if _avatar and _avatar.hand_socket():
		origin = _avatar.hand_socket().global_position
	if _cookie_prop and is_instance_valid(_cookie_prop):
		_cookie_prop.visible = false
		get_tree().create_timer(0.28).timeout.connect(func():
			if is_instance_valid(_cookie_prop):
				_cookie_prop.visible = true
		)
	cookie.global_position = origin
	cookie.velocity = (forward + Vector3(0, 0.08, 0)).normalized() * 12.0
	cookie.proj_id = "ck_%s_%d" % [ProfileStore.player_id, Time.get_ticks_msec()]
	ExploreNet.send_throw(origin, cookie.velocity, cookie.proj_id)
	return true


func _physics_process(delta: float) -> void:
	if _toss_cool > 0.0:
		_toss_cool = maxf(0.0, _toss_cool - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		if not _grounded_once:
			_grounded_once = true
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward")
	)
	input += joy_vector
	input = input.limit_length(1.0)
	var basis_flat := Transform3D(Basis(Vector3.UP, rotation.y), Vector3.ZERO)
	var wish := (basis_flat.basis * Vector3(input.x, 0, -input.y)).normalized() if input.length() > 0.05 else Vector3.ZERO
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	var look_x := 0.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT):
		look_x -= 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_RIGHT):
		look_x += 1.0
	if absf(look_x) > 0.01:
		rotate_y(-look_x * key_look_speed * delta)
	move_and_slide()
	if _avatar:
		_avatar.set_moving(wish.length() > 0.05)
		_avatar.set_nameplate(ProfileStore.display_name)
	if global_position.y < -2.0:
		global_position = Vector3(0.0, 0.08, 11.0)
		velocity = Vector3.ZERO
		snap_to_ground()
