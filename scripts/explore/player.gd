extends CharacterBody3D
class_name PlayerExplorer

@export var speed: float = 4.4
@export var gravity: float = 22.0
@export var mouse_sens: float = 0.12
@export var touch_look_sens: float = 0.14

var joy_vector: Vector2 = Vector2.ZERO
var look_touch_id: int = -1
var pitch: float = 0.0
var captured := false

@onready var _cam: Camera3D = $Camera3D


func _ready() -> void:
	floor_snap_length = 0.3
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape == null:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.36
		cap.height = 1.65
		col.shape = cap


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		captured = not captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		captured = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseMotion and captured:
		_look(event.relative)


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sens * 0.01)
	pitch = clampf(pitch - relative.y * mouse_sens * 0.01, -1.2, 1.2)
	_cam.rotation.x = pitch


func apply_touch_look(relative: Vector2) -> void:
	_look(relative * (touch_look_sens / mouse_sens))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
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
	move_and_slide()
