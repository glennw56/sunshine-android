extends Control
class_name LookPad
## Right-thumb look: drag on the plate (mouse or touch) plus hold buttons.

signal look_delta(relative: Vector2)

const HOLD_PX_PER_SEC := 760.0

var _dragging := false
var _from_touch := false
var _pointer_index := 0
var _hold := Vector2.ZERO
var _last_local := Vector2.ZERO

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
	var plate := get_node_or_null("Plate") as Panel
	if plate:
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", BakeryTheme.hud_plate())


func _wire(btn: BaseButton, axis: Vector2) -> void:
	if btn == null:
		return
	btn.button_down.connect(func(): _hold += axis)
	btn.button_up.connect(func(): _hold -= axis)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if _hold.length() > 0.05:
		look_delta.emit(_hold.limit_length(1.0) * HOLD_PX_PER_SEC * delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_from_touch = true
			_pointer_index = event.index
			_last_local = event.position
		elif event.index == _pointer_index:
			_dragging = false
			_from_touch = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging and event.index == _pointer_index:
		look_delta.emit(event.relative)
		_last_local = event.position
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _from_touch:
			return
		_dragging = event.pressed
		_last_local = event.position
		accept_event()
	elif event is InputEventMouseMotion and _dragging and not _from_touch:
		look_delta.emit(event.relative)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var local := make_input_local(event)
	if event is InputEventScreenTouch and not event.pressed and event.index == _pointer_index:
		_dragging = false
		_from_touch = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _pointer_index:
		look_delta.emit(local.position - _last_local)
		_last_local = local.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _from_touch:
		_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _from_touch and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		look_delta.emit(event.relative)
