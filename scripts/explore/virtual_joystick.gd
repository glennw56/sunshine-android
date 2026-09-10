extends Control
class_name VirtualJoystick

signal vector_changed(value: Vector2)

var _pressed := false
var _origin := Vector2.ZERO
var _knob_pos := Vector2.ZERO
const RADIUS := 70.0

@onready var _base: TextureRect = $Base
@onready var _knob: TextureRect = $Knob


func _ready() -> void:
	_base.texture = load("res://assets/generated/joy_base.png")
	_knob.texture = load("res://assets/generated/joy_knob.png")
	_reset_knob()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_origin = event.position
			_apply(event.position)
		else:
			_pressed = false
			_reset_knob()
			vector_changed.emit(Vector2.ZERO)
	elif event is InputEventScreenDrag and _pressed:
		_apply(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_origin = event.position
			_apply(event.position)
		else:
			_pressed = false
			_reset_knob()
			vector_changed.emit(Vector2.ZERO)
	elif event is InputEventMouseMotion and _pressed:
		_apply(event.position)


func _apply(pos: Vector2) -> void:
	var delta := pos - _origin
	if delta.length() > RADIUS:
		delta = delta.normalized() * RADIUS
	_knob.position = _base.size / 2.0 - _knob.size / 2.0 + delta
	var v := delta / RADIUS
	# UI Y down → game forward is up on the stick.
	vector_changed.emit(Vector2(v.x, -v.y))


func _reset_knob() -> void:
	_knob.position = _base.size / 2.0 - _knob.size / 2.0
	_origin = _base.size / 2.0
