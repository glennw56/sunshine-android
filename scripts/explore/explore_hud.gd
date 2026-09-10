extends CanvasLayer
class_name ExploreHUD

signal leave_requested

@onready var _stamps: HBoxContainer = $Root/Top/Stamps
@onready var _status: Label = $Root/Top/Status
@onready var _board: VBoxContainer = $Root/Board
@onready var _back: Button = $Root/Top/Back
@onready var _joy: VirtualJoystick = $Root/Joy


func _ready() -> void:
	_back.pressed.connect(func(): leave_requested.emit())
	_refresh()


func joystick() -> VirtualJoystick:
	return _joy


func _refresh() -> void:
	for child in _stamps.get_children():
		child.queue_free()
	for i in GameSave.STAMPS_FOR_DRINK:
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(22, 22)
		slot.color = Color("f4c430") if i < GameSave.stamps else Color(1, 1, 1, 0.25)
		_stamps.add_child(slot)
	_status.text = "Stamps %d/%d · finds this week %d · free drinks %d" % [
		GameSave.stamps, GameSave.STAMPS_FOR_DRINK, GameSave.finds_this_week, GameSave.free_drinks_earned
	]
	for child in _board.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Local weekly finders"
	title.add_theme_color_override("font_color", Color("fff6ea"))
	_board.add_child(title)
	var rows: Array = GameSave.weekly_board()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Pick up croissants & drinks to get on this device's board."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color("e8b4b8"))
		_board.add_child(empty)
	var rank := 1
	for row in rows:
		if not row is Dictionary:
			continue
		var line := Label.new()
		line.text = "%d. %s  ·  %d" % [rank, str(row.get("name", "Guest")), int(row.get("finds", 0))]
		line.add_theme_color_override("font_color", Color("fff6ea"))
		_board.add_child(line)
		rank += 1
		if rank > 8:
			break


func on_collected(kind: String) -> void:
	var result := GameSave.add_find(1)
	NoticeService.info("Found a %s! Stamp +1" % kind)
	if result.get("free", false):
		NoticeService.customer("Stamp card full — free drink on the house (game loop).")
	_refresh()
