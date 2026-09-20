extends CanvasLayer
class_name ExploreHUD

signal leave_requested
signal toss_requested
signal customize_requested
signal chat_submitted(body: String)

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const LookPad := preload("res://scripts/explore/look_pad.gd")
const VirtualJoystick := preload("res://scripts/explore/virtual_joystick.gd")

@onready var _stamps: HBoxContainer = $Root/Top/Stamps
@onready var _status: Label = $Root/Status
@onready var _board: VBoxContainer = $Root/Board
@onready var _back: Button = $Root/Top/Back
@onready var _joy: VirtualJoystick = $Root/Joy
@onready var _hint: Label = $Root/Hint
@onready var _fresh_tip: Label = $Root/FreshTip
@onready var _look: LookPad = $Root/LookPad
@onready var _toss: Button = $Root/TossCookie


func _ready() -> void:
	BakeryTheme.apply($Root)
	_back.theme_type_variation = "SecondaryButton"
	_back.text = "Menu"
	_back.custom_minimum_size = Vector2(128, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_back.pressed.connect(func(): leave_requested.emit())
	if not has_node("Root/Top/Look"):
		var look_btn := Button.new()
		look_btn.name = "Look"
		look_btn.text = "Look"
		look_btn.theme_type_variation = "SecondaryButton"
		look_btn.custom_minimum_size = Vector2(120, 64)
		look_btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
		look_btn.pressed.connect(func(): customize_requested.emit())
		$Root/Top.add_child(look_btn)
		$Root/Top.move_child(look_btn, 1)
	if _toss:
		_toss.theme_type_variation = "SecondaryButton"
		_toss.text = "Toss cookie"
		_toss.custom_minimum_size = Vector2(220, 96)
		_toss.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
		_toss.pressed.connect(func(): toss_requested.emit())
	_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_fresh_tip.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_layout_thumbs()
	_ensure_room_ui()
	_refresh()
	set_room_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		leave_requested.emit()
		get_viewport().set_input_as_handled()


func joystick() -> VirtualJoystick:
	return _joy


func look_pad() -> LookPad:
	return _look


func _refresh() -> void:
	for child in _stamps.get_children():
		child.queue_free()
	for i in GameSave.STAMPS_FOR_DRINK:
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(28, 28)
		slot.color = Color("f4c430") if i < GameSave.stamps else Color(1, 1, 1, 0.25)
		_stamps.add_child(slot)
	var active := GameSave.is_fresh_batch_active()
	if active:
		_status.text = "Fresh Batch · 2× left %d" % GameSave.fresh_batch_bonus_remaining()
	else:
		_status.text = "Free drinks %d" % GameSave.free_drinks_earned
	_fresh_tip.text = GameSave.fresh_batch_hint()
	_fresh_tip.modulate = Color("f4c430") if active else Color(1, 0.965, 0.918, 1)
	if _hint:
		_hint.visible = false
		_hint.text = ""
	for child in _board.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Local weekly finders"
	title.add_theme_color_override("font_color", Color("fff6ea"))
	title.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_board.add_child(title)
	var rows: Array = GameSave.weekly_board()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Pick up croissants & drinks to get on this device's board."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color("e8b4b8"))
		empty.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
		empty.add_theme_constant_override("outline_size", 6)
		empty.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		_board.add_child(empty)
	var rank := 1
	for row in rows:
		if not row is Dictionary:
			continue
		var line := Label.new()
		line.text = "%d. %s  ·  %d" % [rank, str(row.get("name", "Guest")), int(row.get("finds", 0))]
		line.add_theme_color_override("font_color", Color("fff6ea"))
		line.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
		line.add_theme_constant_override("outline_size", 6)
		line.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		_board.add_child(line)
		rank += 1
		if rank > 8:
			break


func _layout_thumbs() -> void:
	## Big fixed left stick + right-half look so older thumbs can move and
	## look at the same time. Toss / chat stay later siblings and keep clicks.
	if _joy:
		_joy.anchor_left = 0.0
		_joy.anchor_top = 1.0
		_joy.anchor_right = 0.0
		_joy.anchor_bottom = 1.0
		_joy.offset_left = 8.0
		_joy.offset_top = -368.0
		_joy.offset_right = 336.0
		_joy.offset_bottom = -28.0
	if _look:
		## True right half so the left thumb never fights look.
		_look.anchor_left = 0.50
		_look.anchor_top = 0.14
		_look.anchor_right = 1.0
		_look.anchor_bottom = 1.0
		_look.offset_left = 0.0
		_look.offset_top = 0.0
		_look.offset_right = 0.0
		_look.offset_bottom = 0.0
	if _toss:
		_toss.z_index = 4


func _ensure_room_ui() -> void:
	if $Root.get_node_or_null("RoomStatus") == null:
		var room := Label.new()
		room.name = "RoomStatus"
		room.position = Vector2(12, 280)
		room.size = Vector2(420, 48)
		room.add_theme_color_override("font_color", Color("fff6ea"))
		room.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
		room.add_theme_constant_override("outline_size", 6)
		room.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		$Root.add_child(room)
	if $Root.get_node_or_null("ChatLog") == null:
		var log := Label.new()
		log.name = "ChatLog"
		log.position = Vector2(12, 328)
		log.size = Vector2(420, 120)
		log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log.add_theme_color_override("font_color", Color("fff6ea"))
		log.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
		log.add_theme_constant_override("outline_size", 6)
		log.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		$Root.add_child(log)
	if $Root.get_node_or_null("ChatRow") == null:
		var row := HBoxContainer.new()
		row.name = "ChatRow"
		row.anchor_left = 0.5
		row.anchor_right = 0.5
		row.anchor_top = 1.0
		row.anchor_bottom = 1.0
		row.offset_left = -260.0
		row.offset_right = 260.0
		row.offset_top = -272.0
		row.offset_bottom = -204.0
		row.add_theme_constant_override("separation", 8)
		var field := LineEdit.new()
		field.name = "Field"
		field.placeholder_text = "Say hi on the patio"
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.custom_minimum_size = Vector2(0, 64)
		field.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
		var send := Button.new()
		send.name = "Send"
		send.text = "Chat"
		send.custom_minimum_size = Vector2(108, 64)
		send.theme_type_variation = "SecondaryButton"
		send.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
		send.pressed.connect(_submit_chat)
		field.text_submitted.connect(func(_t: String): _submit_chat())
		row.add_child(field)
		row.add_child(send)
		row.z_index = 4
		$Root.add_child(row)


func set_room_status(_arg: Variant = null) -> void:
	var room := $Root.get_node_or_null("RoomStatus") as Label
	if room == null:
		return
	var n := ExploreNet.player_count()
	var who := "baker" if n == 1 else "bakers"
	room.text = "%s · %d %s" % [ExploreNet.status_text, maxi(n, 0), who]


func push_chat(display_name: String, body: String) -> void:
	var log := $Root.get_node_or_null("ChatLog") as Label
	if log == null:
		return
	var line := "%s: %s" % [display_name, body]
	var prev := log.text.strip_edges()
	if prev == "":
		log.text = line
	else:
		var parts := prev.split("\n")
		var keep: PackedStringArray = []
		var start := maxi(0, parts.size() - 2)
		for i in range(start, parts.size()):
			keep.append(parts[i])
		keep.append(line)
		log.text = "\n".join(keep)


func _submit_chat() -> void:
	var row := $Root.get_node_or_null("ChatRow")
	if row == null:
		return
	var field := row.get_node_or_null("Field") as LineEdit
	if field == null:
		return
	var body := field.text.strip_edges()
	if body == "":
		return
	field.text = ""
	chat_submitted.emit(body)


func on_collected(kind: String) -> void:
	var result := GameSave.record_explore_find()
	var delta := int(result.get("stamp_delta", 1))
	if result.get("bonus", false):
		NoticeService.info("Found a %s! Fresh Batch 2× stamps (+%d). Weekly find +1." % [kind, delta])
	else:
		NoticeService.info("Found a %s! Stamp +%d" % [kind, delta])
	if result.get("free", false):
		NoticeService.customer("Stamp card full — free drink on the house (game loop).")
	_refresh()
