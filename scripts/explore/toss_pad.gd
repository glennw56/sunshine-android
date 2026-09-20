extends Button
class_name TossPad
## Fire button that uses ScreenTouch index, not the emulated mouse.
## BaseButton only sees finger 0 (emulate_mouse_from_touch). Stick + look
## already own two fingers, so a third tap never reached `pressed`.

signal toss_pressed

var _finger: int = -1


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	toggle_mode = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger < 0:
			_finger = touch.index
			toss_pressed.emit()
		elif (not touch.pressed) and touch.index == _finger:
			_finger = -1
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		## Finger 0 already fired via ScreenTouch. Extra mouse echo would double-toss.
		if _finger >= 0:
			accept_event()
			return
		if event.pressed:
			toss_pressed.emit()
		accept_event()
