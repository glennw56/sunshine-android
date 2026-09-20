extends Control
class_name LookPad
## Right-half look. Owns one ScreenTouch index. A new finger (toss / stick)
## must not rebind look or end the drag.

signal look_delta(relative: Vector2)
signal looking_changed(on: bool)

const HOLD_PX_PER_SEC := 1100.0
const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

var _dragging := false
var _from_touch := false
var _pointer_index := -1
var _hold := Vector2.ZERO
var _last_local := Vector2.ZERO
var _last_rel := Vector2.ZERO
var _coast := Vector2.ZERO

@onready var _left: BaseButton = get_node_or_null("LookLeft")
@onready var _right: BaseButton = get_node_or_null("LookRight")
@onready var _up: BaseButton = get_node_or_null("LookUp")
@onready var _down: BaseButton = get_node_or_null("LookDown")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wire(_left, Vector2(-1, 0))
	_wire(_right, Vector2(1, 0))
	_wire(_up, Vector2(0, -1))
	_wire(_down, Vector2(0, 1))
	var plate := get_node_or_null("Plate") as CanvasItem
	if plate:
		plate.visible = false
		if plate is Control:
			(plate as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _wire(btn: BaseButton, axis: Vector2) -> void:
	if btn == null:
		return
	btn.button_down.connect(func(): _hold += axis)
	btn.button_up.connect(func(): _hold -= axis)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if _hold.length() > 0.05:
		look_delta.emit(_hold.limit_length(1.0) * HOLD_PX_PER_SEC * delta)
	if not _dragging and _coast.length() > 0.4:
		look_delta.emit(_coast)
		_coast = _coast.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		if _coast.length() < 0.4:
			_coast = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _dragging:
				accept_event()
				return
			_begin(touch.position, true, touch.index)
		elif touch.index == _pointer_index:
			_end()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _dragging and drag.index == _pointer_index:
			_drag(drag.relative, drag.position)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _from_touch:
			accept_event()
			return
		if event.pressed:
			if _dragging:
				accept_event()
				return
			_begin(event.position, false, -1)
		else:
			_end()
		accept_event()
	elif event is InputEventMouseMotion and _dragging and not _from_touch:
		_drag(event.relative, event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var local := make_input_local(event)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if (not touch.pressed) and touch.index == _pointer_index:
			_end()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer_index:
			_drag(local.position - _last_local, local.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _from_touch:
		_end()
	elif event is InputEventMouseMotion and not _from_touch and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_drag(event.relative, local.position)


func _begin(local_pos: Vector2, touch: bool, index: int) -> void:
	_dragging = true
	_from_touch = touch
	_pointer_index = index
	_last_local = local_pos
	_last_rel = Vector2.ZERO
	_coast = Vector2.ZERO
	looking_changed.emit(true)


func _drag(relative: Vector2, local_pos: Vector2) -> void:
	_last_local = local_pos
	_last_rel = relative
	look_delta.emit(relative)


func _end() -> void:
	_dragging = false
	_from_touch = false
	_pointer_index = -1
	_coast = _last_rel * 0.72
	_last_rel = Vector2.ZERO
	looking_changed.emit(false)
