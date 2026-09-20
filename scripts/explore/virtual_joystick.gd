extends Control
class_name VirtualJoystick
## Fixed bakery stick (PUBG Layout-3 feel). One ScreenTouch index only.
## Extra fingers on the plate are ignored so look + toss keep theirs.

signal vector_changed(value: Vector2)

const RADIUS := 108.0
const DEAD := 0.10

var _pressed := false
var _from_touch := false
var _pointer_index := -1
var _vector := Vector2.ZERO
var _sprint_lock := false

@onready var _base: TextureRect = $Base
@onready var _knob: TextureRect = $Knob


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_art()
	_reset_knob()


func current_vector() -> Vector2:
	return _vector


func debug_set_vector(v: Vector2) -> void:
	_sprint_lock = false
	_vector = v.limit_length(1.0)
	_place_knob(_vector)
	vector_changed.emit(_vector)


func apply_local_point(local_pos: Vector2) -> void:
	_apply(local_pos)


func _ensure_art() -> void:
	if _base and _base.texture == null:
		if ResourceLoader.exists("res://assets/generated/joy_base.png"):
			_base.texture = load("res://assets/generated/joy_base.png")
		if _base.texture == null:
			_base.texture = _circle_tex(256, Color(0.29, 0.11, 0.16, 0.42), Color(1, 0.96, 0.91, 0.55), 10.0)
	if _knob and _knob.texture == null:
		if ResourceLoader.exists("res://assets/generated/joy_knob.png"):
			_knob.texture = load("res://assets/generated/joy_knob.png")
		if _knob.texture == null:
			_knob.texture = _circle_tex(160, Color(0.91, 0.66, 0.70, 0.92), Color(0.29, 0.11, 0.16, 0.9), 8.0)
	if _base:
		_base.modulate = Color(1, 1, 1, 0.92)
		_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _knob:
		_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _circle_tex(px: int, fill: Color, ring: Color, ring_w: float) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px * 0.5, px * 0.5)
	var r := px * 0.5 - 2.0
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r and d >= r - ring_w:
				img.set_pixel(x, y, ring)
			elif d < r - ring_w:
				img.set_pixel(x, y, fill)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _pressed:
				accept_event()
				return
			_pressed = true
			_from_touch = true
			_pointer_index = touch.index
			_apply(touch.position)
		elif touch.index == _pointer_index:
			_release()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pressed and drag.index == _pointer_index:
			_apply(drag.position)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _from_touch:
			accept_event()
			return
		if event.pressed:
			if _pressed:
				accept_event()
				return
			_pressed = true
			_from_touch = false
			_pointer_index = -1
			_apply(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _pressed and not _from_touch:
		_apply(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	## Drag / lift after the thumb leaves the plate. Other fingers pass through.
	if not _pressed:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if (not touch.pressed) and touch.index == _pointer_index:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer_index:
			_apply(make_input_local(drag).position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _from_touch:
		_release()
	elif event is InputEventMouseMotion and not _from_touch and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_apply(make_input_local(event).position)


func _apply(pos: Vector2) -> void:
	var plate := size
	if plate.x < 8.0 or plate.y < 8.0:
		plate = Vector2(320, 320)
	var delta := pos - plate / 2.0
	if delta.length() > RADIUS:
		delta = delta.normalized() * RADIUS
	_place_delta(delta)
	var v := Vector2(delta.x / RADIUS, -delta.y / RADIUS)
	if v.length() < DEAD:
		v = Vector2.ZERO
		_sprint_lock = false
	else:
		v = v.limit_length(1.0)
		if v.y > 0.90 and absf(v.x) < 0.30:
			_sprint_lock = true
		elif v.y < 0.42 or v.length() < 0.22:
			_sprint_lock = false
		if _sprint_lock:
			v = Vector2(v.x * 0.72, 1.0).limit_length(1.0)
	_vector = v
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
	_pointer_index = -1
	_sprint_lock = false
	_vector = Vector2.ZERO
	_reset_knob()
	vector_changed.emit(Vector2.ZERO)


func _reset_knob() -> void:
	if _knob == null:
		return
	_knob.position = size / 2.0 - _knob.size / 2.0
