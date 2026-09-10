extends Control
class_name VirtualJoystick
## Large thumb-zone stick. Mouse click/drag AND touch. Static center so a
## click on the top of the plate immediately walks forward (no dead press).

signal vector_changed(value: Vector2)

const RADIUS := 92.0
const DEAD := 0.08

var _pressed := false
var _from_touch := false
var _pointer_index := 0
var _vector := Vector2.ZERO

@onready var _base: TextureRect = $Base
@onready var _knob: TextureRect = $Knob


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://assets/generated/joy_base.png"):
		_base.texture = load("res://assets/generated/joy_base.png")
	if ResourceLoader.exists("res://assets/generated/joy_knob.png"):
		_knob.texture = load("res://assets/generated/joy_knob.png")
	_reset_knob()


func current_vector() -> Vector2:
	return _vector


func debug_set_vector(v: Vector2) -> void:
	_vector = v.limit_length(1.0)
	_place_knob(_vector)
	vector_changed.emit(_vector)


## local_pos is in this control's pixel space (0,0 = top-left).
func apply_local_point(local_pos: Vector2) -> void:
	_apply(local_pos)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_from_touch = true
			_pointer_index = event.index
			_apply(event.position)
		elif event.index == _pointer_index:
			_release()
		accept_event()
	elif event is InputEventScreenDrag and _pressed and event.index == _pointer_index:
		_apply(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _from_touch:
			return
		if event.pressed:
			_pressed = true
			_from_touch = false
			_apply(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _pressed and not _from_touch:
		_apply(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _pressed:
		return
	var local := make_input_local(event)
	if event is InputEventScreenTouch and not event.pressed and event.index == _pointer_index:
		_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _pointer_index:
		_apply(local.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _from_touch:
		_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _from_touch and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_apply(local.position)


func _apply(pos: Vector2) -> void:
	var plate := size
	if plate.x < 8.0 or plate.y < 8.0:
		plate = Vector2(240, 240)
	var delta := pos - plate / 2.0
	if delta.length() > RADIUS:
		delta = delta.normalized() * RADIUS
	_place_delta(delta)
	var v := Vector2(delta.x / RADIUS, -delta.y / RADIUS)
	if v.length() < DEAD:
		v = Vector2.ZERO
	_vector = v.limit_length(1.0)
	vector_changed.emit(_vector)


func _place_delta(delta: Vector2) -> void:
	if _knob == null:
		return
	_knob.position = size / 2.0 - _knob.size / 2.0 + delta


func _place_knob(v: Vector2) -> void:
	_place_delta(Vector2(v.x, -v.y) * RADIUS)


func _release() -> void:
	_pressed = false
	_from_touch = false
	_vector = Vector2.ZERO
	_reset_knob()
	vector_changed.emit(Vector2.ZERO)


func _reset_knob() -> void:
	if _knob == null or _base == null:
		return
	_knob.position = size / 2.0 - _knob.size / 2.0
