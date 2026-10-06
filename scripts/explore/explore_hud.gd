extends CanvasLayer
class_name ExploreHUD

signal leave_requested
signal toss_requested
signal jump_requested
signal pickup_requested
signal pet_requested
signal customize_requested
signal loyalty_requested
signal chat_submitted(body: String)

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const LookPad := preload("res://scripts/explore/look_pad.gd")
const ExploreVirtualJoystick := preload("res://scripts/explore/explore_virtual_joystick.gd")

@onready var _stamps: HBoxContainer = $Root/Top/Stamps
@onready var _status: Label = $Root/Status
@onready var _board: VBoxContainer = $Root/Board
@onready var _back: Button = $Root/Top/Back
@onready var _joy: ExploreVirtualJoystick = $Root/Joy
@onready var _hint: Label = $Root/Hint
@onready var _fresh_tip: Label = $Root/FreshTip
@onready var _look: LookPad = $Root/LookPad
@onready var _toss: Button = $Root/TossCookie

var _cookie_count: Label
var _cookie_refill: Button
var _refilling := false
var _empty_notice_msec: int = -4000
var _pumpkin_held := false
var _ping_label: Label
var _pumpkin_btn: Button
var _pet_btn: Button
var _holding_pet := false
var _ping_busy := false


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
	if not has_node("Root/Top/Loyalty"):
		var loyalty_btn := Button.new()
		loyalty_btn.name = "Loyalty"
		loyalty_btn.text = "Loyalty"
		loyalty_btn.theme_type_variation = "SecondaryButton"
		loyalty_btn.custom_minimum_size = Vector2(150, 64)
		loyalty_btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
		loyalty_btn.pressed.connect(func(): loyalty_requested.emit())
		$Root/Top.add_child(loyalty_btn)
	if _toss:
		_toss.theme_type_variation = "SecondaryButton"
		_toss.text = "Toss cookie"
		_toss.custom_minimum_size = Vector2(220, 96)
		_toss.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
		if _toss.has_signal("toss_pressed"):
			_toss.connect("toss_pressed", func(): toss_requested.emit())
		else:
			_toss.pressed.connect(func(): toss_requested.emit())
	_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_fresh_tip.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_ensure_jump()
	_layout_thumbs()
	_ensure_room_ui()
	_ensure_cookie_economy()
	_ensure_server_ping()
	_ensure_pumpkin_pickup()
	_ensure_pet_button()
	_refresh()
	set_room_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		leave_requested.emit()
		get_viewport().set_input_as_handled()


func joystick() -> ExploreVirtualJoystick:
	return _joy


func look_pad() -> LookPad:
	return _look


func _refresh() -> void:
	if _stamps:
		_stamps.visible = false
		for child in _stamps.get_children():
			child.queue_free()
	_status.text = ""
	_status.visible = false
	_fresh_tip.text = ""
	_fresh_tip.visible = false
	if _hint:
		_hint.visible = false
		_hint.text = ""
	for child in _board.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Local weekly board"
	title.add_theme_color_override("font_color", Color("fff6ea"))
	title.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_board.add_child(title)
	var rows: Array = GameSave.weekly_board()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Pick up treats, or hit another baker with a cookie."
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
		line.text = "%d. %s  ·  %d finds · %d hits" % [
			rank,
			str(row.get("name", "Guest")),
			int(row.get("finds", 0)),
			int(row.get("hits", 0)),
		]
		line.add_theme_color_override("font_color", Color("fff6ea"))
		line.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
		line.add_theme_constant_override("outline_size", 6)
		line.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		_board.add_child(line)
		rank += 1
		if rank > 5:
			break


func _ensure_jump() -> void:
	## Right-thumb Jump, above the cookie count. ScreenTouch so it works
	## while the stick and look pad already own two fingers. Space still jumps.
	var root := $Root as Control
	var jump := root.get_node_or_null("Jump") as Button
	if jump == null:
		var pad_script := load("res://scripts/explore/toss_pad.gd") as Script
		jump = pad_script.new() as Button
		jump.name = "Jump"
		root.add_child(jump)
	jump.text = "Jump"
	jump.theme_type_variation = "SecondaryButton"
	jump.focus_mode = Control.FOCUS_NONE
	jump.mouse_filter = Control.MOUSE_FILTER_STOP
	jump.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	jump.custom_minimum_size = Vector2(200, 80)
	jump.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	jump.anchor_left = 1.0
	jump.anchor_top = 1.0
	jump.anchor_right = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -236.0
	jump.offset_top = -372.0
	jump.offset_right = -16.0
	jump.offset_bottom = -284.0
	jump.z_index = 20
	if jump.has_signal("toss_pressed") and not jump.toss_pressed.is_connected(_on_jump):
		jump.toss_pressed.connect(_on_jump)
	elif not jump.pressed.is_connected(_on_jump):
		jump.pressed.connect(_on_jump)


func _on_jump() -> void:
	jump_requested.emit()


func _layout_thumbs() -> void:
	## Big fixed left stick + right-half look so older thumbs can move and
	## look at the same time. Chat lives above the stick, never on it.
	if _joy:
		_joy.anchor_left = 0.0
		_joy.anchor_top = 1.0
		_joy.anchor_right = 0.0
		_joy.anchor_bottom = 1.0
		_joy.offset_left = 8.0
		_joy.offset_top = -368.0
		_joy.offset_right = 336.0
		_joy.offset_bottom = -28.0
		_joy.z_index = 16
		_joy.mouse_filter = Control.MOUSE_FILTER_STOP
		$Root.move_child(_joy, $Root.get_child_count() - 1)
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
		_look.z_index = 1
	if _toss:
		## Right-side fire button. Center-bottom sat on the stick, so a
		## strafe tap never reached Toss and the left thumb had to stop.
		_toss.anchor_left = 1.0
		_toss.anchor_top = 1.0
		_toss.anchor_right = 1.0
		_toss.anchor_bottom = 1.0
		_toss.offset_left = -236.0
		_toss.offset_top = -220.0
		_toss.offset_right = -16.0
		_toss.offset_bottom = -96.0
		_toss.custom_minimum_size = Vector2(200, 100)
		_toss.z_index = 20
		_toss.mouse_filter = Control.MOUSE_FILTER_STOP
		_toss.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_toss.focus_mode = Control.FOCUS_NONE


func _exit_tree() -> void:
	if GameSave.throw_cookies_changed.is_connected(_on_throw_cookies_changed):
		GameSave.throw_cookies_changed.disconnect(_on_throw_cookies_changed)


func _ensure_cookie_economy() -> void:
	## Count sits just above Toss. Refill sits just below it, same thumb zone.
	var root := $Root as Control
	_cookie_count = root.get_node_or_null("CookieCount") as Label
	if _cookie_count == null:
		_cookie_count = Label.new()
		_cookie_count.name = "CookieCount"
		_cookie_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cookie_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cookie_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cookie_count.clip_contents = true
		_cookie_count.add_theme_color_override("font_color", Color("fff6ea"))
		_cookie_count.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
		_cookie_count.add_theme_constant_override("outline_size", 6)
		_cookie_count.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		root.add_child(_cookie_count)
	_cookie_refill = root.get_node_or_null("CookieRefill") as Button
	if _cookie_refill == null:
		var pad_script := load("res://scripts/explore/toss_pad.gd") as Script
		_cookie_refill = pad_script.new() as Button
		_cookie_refill.name = "CookieRefill"
		_cookie_refill.focus_mode = Control.FOCUS_NONE
		_cookie_refill.mouse_filter = Control.MOUSE_FILTER_STOP
		_cookie_refill.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_cookie_refill.theme_type_variation = "GoldButton"
		_cookie_refill.custom_minimum_size = Vector2(200, 72)
		_cookie_refill.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
		if _cookie_refill.has_signal("toss_pressed"):
			_cookie_refill.connect("toss_pressed", _on_cookie_refill)
		else:
			_cookie_refill.pressed.connect(_on_cookie_refill)
		root.add_child(_cookie_refill)
	_cookie_refill.text = AdTipService.cookie_refill_label()
	_layout_cookie_economy()
	if not GameSave.throw_cookies_changed.is_connected(_on_throw_cookies_changed):
		GameSave.throw_cookies_changed.connect(_on_throw_cookies_changed)
	_refresh_cookie_count()


func _layout_cookie_economy() -> void:
	if _cookie_count:
		_cookie_count.anchor_left = 1.0
		_cookie_count.anchor_top = 1.0
		_cookie_count.anchor_right = 1.0
		_cookie_count.anchor_bottom = 1.0
		_cookie_count.offset_left = -236.0
		_cookie_count.offset_top = -276.0
		_cookie_count.offset_right = -16.0
		_cookie_count.offset_bottom = -228.0
		_cookie_count.z_index = 20
	if _cookie_refill:
		_cookie_refill.anchor_left = 1.0
		_cookie_refill.anchor_top = 1.0
		_cookie_refill.anchor_right = 1.0
		_cookie_refill.anchor_bottom = 1.0
		_cookie_refill.offset_left = -236.0
		_cookie_refill.offset_top = -88.0
		_cookie_refill.offset_right = -16.0
		_cookie_refill.offset_bottom = -12.0
		_cookie_refill.custom_minimum_size = Vector2(200, 72)
		_cookie_refill.z_index = 20
		_cookie_refill.focus_mode = Control.FOCUS_NONE


func _on_throw_cookies_changed(_count: int) -> void:
	_refresh_cookie_count()


func _refresh_cookie_count() -> void:
	var n := GameSave.throw_cookies
	if _cookie_count:
		_cookie_count.text = GameSave.cookie_count_label()
		var col := Color("f4c430") if n <= 0 else Color("fff6ea")
		_cookie_count.add_theme_color_override("font_color", col)
	if _toss:
		if _holding_pet:
			_toss.visible = false
		else:
			_toss.visible = true
			if _pumpkin_held:
				_toss.text = "Throw pumpkin"
			else:
				_toss.text = "Out of cookies" if n <= 0 else "Toss cookie"


func set_pumpkin_state(near_bin: bool, holding: bool) -> void:
	_pumpkin_held = holding
	if _pumpkin_btn:
		_pumpkin_btn.visible = AppConfig.test_world and near_bin and not holding
	_refresh_cookie_count()


func _ensure_pumpkin_pickup() -> void:
	if not AppConfig.test_world:
		return
	var root := $Root as Control
	_pumpkin_btn = root.get_node_or_null("PumpkinPickup") as Button
	if _pumpkin_btn == null:
		var pad_script := load("res://scripts/explore/toss_pad.gd") as Script
		_pumpkin_btn = pad_script.new() as Button
		_pumpkin_btn.name = "PumpkinPickup"
		root.add_child(_pumpkin_btn)
	_pumpkin_btn.text = "Pick up pumpkin"
	_pumpkin_btn.theme_type_variation = "SecondaryButton"
	_pumpkin_btn.focus_mode = Control.FOCUS_NONE
	_pumpkin_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_pumpkin_btn.visible = false
	_pumpkin_btn.custom_minimum_size = Vector2(280, 72)
	_pumpkin_btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_pumpkin_btn.anchor_left = 0.0
	_pumpkin_btn.anchor_top = 1.0
	_pumpkin_btn.anchor_right = 0.0
	_pumpkin_btn.anchor_bottom = 1.0
	_pumpkin_btn.offset_left = 16.0
	_pumpkin_btn.offset_top = -460.0
	_pumpkin_btn.offset_right = 320.0
	_pumpkin_btn.offset_bottom = -380.0
	_pumpkin_btn.z_index = 22
	if _pumpkin_btn.has_signal("toss_pressed") and not _pumpkin_btn.toss_pressed.is_connected(_on_pumpkin_pickup):
		_pumpkin_btn.toss_pressed.connect(_on_pumpkin_pickup)
	elif not _pumpkin_btn.pressed.is_connected(_on_pumpkin_pickup):
		_pumpkin_btn.pressed.connect(_on_pumpkin_pickup)


func _on_pumpkin_pickup() -> void:
	pickup_requested.emit()


func set_pet_state(near: bool, holding: bool) -> void:
	_holding_pet = holding
	if _pet_btn:
		_pet_btn.visible = AppConfig.test_world and (holding or (near and not _pumpkin_held))
		_pet_btn.text = "Put down" if holding else "Pick up"
	_refresh_cookie_count()


func _ensure_pet_button() -> void:
	if not AppConfig.test_world:
		return
	var root := $Root as Control
	_pet_btn = root.get_node_or_null("PetButton") as Button
	if _pet_btn == null:
		var pad_script := load("res://scripts/explore/toss_pad.gd") as Script
		_pet_btn = pad_script.new() as Button
		_pet_btn.name = "PetButton"
		root.add_child(_pet_btn)
	_pet_btn.text = "Pick up"
	_pet_btn.theme_type_variation = "SecondaryButton"
	_pet_btn.focus_mode = Control.FOCUS_NONE
	_pet_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_pet_btn.visible = false
	_pet_btn.custom_minimum_size = Vector2(320, 148)
	_pet_btn.add_theme_font_size_override("font_size", 32)
	_pet_btn.add_theme_color_override("font_color", Color("3a2218"))
	_pet_btn.add_theme_color_override("font_hover_color", Color("3a2218"))
	_pet_btn.add_theme_color_override("font_pressed_color", Color("3a2218"))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("fff1d6")
	plate.border_color = Color("722F37")
	plate.set_border_width_all(4)
	plate.set_corner_radius_all(22)
	plate.content_margin_left = 16.0
	plate.content_margin_right = 16.0
	var plate_down := plate.duplicate() as StyleBoxFlat
	plate_down.bg_color = Color("f0d7b0")
	_pet_btn.add_theme_stylebox_override("normal", plate)
	_pet_btn.add_theme_stylebox_override("hover", plate)
	_pet_btn.add_theme_stylebox_override("pressed", plate_down)
	_pet_btn.add_theme_stylebox_override("focus", plate)
	_pet_btn.anchor_left = 0.0
	_pet_btn.anchor_top = 1.0
	_pet_btn.anchor_right = 0.0
	_pet_btn.anchor_bottom = 1.0
	_pet_btn.offset_left = 20.0
	_pet_btn.offset_top = -540.0
	_pet_btn.offset_right = 340.0
	_pet_btn.offset_bottom = -392.0
	_pet_btn.z_index = 30
	if _pet_btn.has_signal("toss_pressed") and not _pet_btn.toss_pressed.is_connected(_on_pet_button):
		_pet_btn.toss_pressed.connect(_on_pet_button)
	elif not _pet_btn.pressed.is_connected(_on_pet_button):
		_pet_btn.pressed.connect(_on_pet_button)


func _on_pet_button() -> void:
	pet_requested.emit()


func _ensure_server_ping() -> void:
	## Client RTT to the existing Explore health URL. No server config change.
	if not AppConfig.test_world:
		return
	var root := $Root as Control
	_ping_label = root.get_node_or_null("ServerPing") as Label
	if _ping_label == null:
		_ping_label = Label.new()
		_ping_label.name = "ServerPing"
		_ping_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_ping_label)
	_ping_label.text = "Ping …"
	_ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ping_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ping_label.add_theme_color_override("font_color", Color("FFF8F0"))
	_ping_label.add_theme_color_override("font_outline_color", Color("722F37"))
	_ping_label.add_theme_constant_override("outline_size", 8)
	_ping_label.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_ping_label.anchor_left = 0.0
	_ping_label.anchor_top = 0.0
	_ping_label.anchor_right = 0.0
	_ping_label.anchor_bottom = 0.0
	_ping_label.offset_left = 16.0
	_ping_label.offset_top = 84.0
	_ping_label.offset_right = 280.0
	_ping_label.offset_bottom = 128.0
	_ping_label.z_index = 24
	_poll_server_ping()


func _poll_server_ping() -> void:
	if _ping_busy or not is_inside_tree() or _ping_label == null:
		return
	_ping_busy = true
	var http := HTTPRequest.new()
	http.timeout = 2.5
	http.use_threads = true
	add_child(http)
	var started := Time.get_ticks_msec()
	var err := http.request(AppConfig.explore_health_url())
	if err != OK:
		_show_ping(-1)
		http.queue_free()
		_ping_busy = false
		_schedule_ping()
		return
	var completed: Array = await http.request_completed
	var elapsed := Time.get_ticks_msec() - started
	if is_instance_valid(http):
		http.queue_free()
	if not is_inside_tree() or _ping_label == null:
		_ping_busy = false
		return
	var ok := int(completed[0]) == HTTPRequest.RESULT_SUCCESS and int(completed[1]) > 0
	_show_ping(elapsed if ok else -1)
	_ping_busy = false
	_schedule_ping()


func _schedule_ping() -> void:
	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(_poll_server_ping)


func _show_ping(ms: int) -> void:
	if _ping_label == null:
		return
	if ms < 0:
		_ping_label.text = "Ping —"
		return
	_ping_label.text = "Ping %d ms" % ms


func show_out_of_cookies() -> void:
	_refresh_cookie_count()
	var now := Time.get_ticks_msec()
	if now - _empty_notice_msec < 1600:
		return
	_empty_notice_msec = now
	var how := "Watch an ad for +200."
	if AdTipService.cookie_refill_label().begins_with("Get"):
		how = "Tap Get +200 to refill."
	NoticeService.info("Out of throw cookies. %s" % how)


func refill_throw_cookies() -> Dictionary:
	if _refilling:
		return {"ok": false, "error": "An ad is already playing."}
	_refilling = true
	if _cookie_refill:
		_cookie_refill.disabled = true
	var result: Dictionary = await AdTipService.play_rewarded_cookies()
	_refilling = false
	if is_instance_valid(_cookie_refill):
		_cookie_refill.disabled = false
	if not is_inside_tree():
		return result
	if result.get("ok", false):
		NoticeService.info("+200 throw cookies. You have %d." % int(result.get("throw_cookies", GameSave.throw_cookies)))
	else:
		var err := str(result.get("error", "Could not add throw cookies."))
		if err != "An ad is already playing.":
			NoticeService.info(err)
	_refresh_cookie_count()
	return result


func _on_cookie_refill() -> void:
	await refill_throw_cookies()


func _ensure_room_ui() -> void:
	_free_legacy_chat()
	if $Root.get_node_or_null("ChatDock") != null:
		return
	var dock := PanelContainer.new()
	dock.name = "ChatDock"
	dock.anchor_left = 0.0
	dock.anchor_top = 0.0
	dock.anchor_right = 0.46
	dock.anchor_bottom = 0.0
	## Compact top-left card. Ends well above the 368px left-stick zone.
	dock.offset_left = 10.0
	dock.offset_top = 236.0
	dock.offset_right = -8.0
	dock.offset_bottom = 508.0
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.z_index = 3
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = Color(0.29, 0.11, 0.16, 0.38)
	dock_style.corner_radius_top_left = 10
	dock_style.corner_radius_top_right = 10
	dock_style.corner_radius_bottom_left = 10
	dock_style.corner_radius_bottom_right = 10
	dock_style.content_margin_left = 8
	dock_style.content_margin_top = 6
	dock_style.content_margin_right = 8
	dock_style.content_margin_bottom = 6
	dock.add_theme_stylebox_override("panel", dock_style)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	dock.add_child(col)
	var room := Label.new()
	room.name = "RoomStatus"
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_theme_color_override("font_color", Color("fff6ea"))
	room.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
	room.add_theme_constant_override("outline_size", 6)
	room.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	col.add_child(room)
	var scroll := ScrollContainer.new()
	scroll.name = "ChatLog"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 132)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(lines)
	col.add_child(scroll)
	var mods := HBoxContainer.new()
	mods.name = "ModRow"
	mods.add_theme_constant_override("separation", 10)
	mods.visible = false
	mods.mouse_filter = Control.MOUSE_FILTER_STOP
	_mod_link(mods, "MuteLast", "Mute", _mute_last)
	_mod_link(mods, "BlockLast", "Block", _block_last)
	_mod_link(mods, "ReportLast", "Report", _report_last)
	col.add_child(mods)
	var row := HBoxContainer.new()
	row.name = "ChatRow"
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var field := LineEdit.new()
	field.name = "Field"
	field.placeholder_text = "Say hi…"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 40)
	field.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	var send := Button.new()
	send.name = "Send"
	send.text = "Send"
	send.flat = true
	send.custom_minimum_size = Vector2(68, 40)
	send.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	send.pressed.connect(_submit_chat)
	field.text_submitted.connect(func(_t: String): _submit_chat())
	row.add_child(field)
	row.add_child(send)
	col.add_child(row)
	$Root.add_child(dock)
	if _joy:
		$Root.move_child(_joy, $Root.get_child_count() - 1)


func _free_legacy_chat() -> void:
	for node_name in ["ChatLog", "ChatRow", "RoomStatus", "MuteLast", "BlockLast", "ReportLast"]:
		var old := $Root.get_node_or_null(node_name)
		if old:
			old.queue_free()


func _mod_link(host: Node, node_name: String, label: String, cb: Callable) -> void:
	var btn := LinkButton.new()
	btn.name = node_name
	btn.text = label
	btn.underline = LinkButton.UNDERLINE_MODE_NEVER
	btn.add_theme_color_override("font_color", Color("e8b4b8"))
	btn.add_theme_color_override("font_hover_color", Color("fff6ea"))
	btn.add_theme_color_override("font_pressed_color", Color("fff6ea"))
	btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	btn.custom_minimum_size = Vector2(0, 28)
	btn.pressed.connect(cb)
	host.add_child(btn)


func _show_mute(display_name: String) -> void:
	var mods := $Root.get_node_or_null("ChatDock/Col/ModRow") as CanvasItem
	if mods:
		mods.visible = true
	for node_name in ["MuteLast", "BlockLast", "ReportLast"]:
		var btn := $Root.get_node_or_null("ChatDock/Col/ModRow/" + node_name) as LinkButton
		if btn:
			btn.set_meta("who", display_name)
			btn.visible = true


func _mod_who() -> String:
	var btn := $Root.get_node_or_null("ChatDock/Col/ModRow/MuteLast") as LinkButton
	return str(btn.get_meta("who", "")) if btn else ""


func _hide_moderation() -> void:
	var mods := $Root.get_node_or_null("ChatDock/Col/ModRow") as CanvasItem
	if mods:
		mods.visible = false


func _mute_last() -> void:
	var who := _mod_who()
	if who == "":
		return
	ExploreNet.mute_display_name(who)
	push_chat("Patio", "Muted %s." % who)
	_hide_moderation()


func _block_last() -> void:
	var who := _mod_who()
	if who == "":
		return
	ExploreNet.block_display_name(who)
	push_chat("Patio", "Blocked %s. You will not see their chat." % who)
	_hide_moderation()


func _report_last() -> void:
	var who := _mod_who()
	if who == "":
		return
	ExploreNet.send_report(who, "unwanted chat")
	push_chat("Patio", "Reported %s to patio staff." % who)
	_hide_moderation()


func set_room_status(_arg: Variant = null) -> void:
	var room := $Root.get_node_or_null("ChatDock/Col/RoomStatus") as Label
	if room == null:
		return
	var n := ExploreNet.player_count()
	var who := "baker" if n == 1 else "bakers"
	room.text = "%s · %d %s" % [ExploreNet.status_text, maxi(n, 0), who]


func push_chat(display_name: String, body: String) -> void:
	var lines := $Root.get_node_or_null("ChatDock/Col/ChatLog/Lines") as VBoxContainer
	if lines == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_color_override("font_color", Color("e8b4b8") if display_name != "Patio" else Color("f4c430"))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", Color("fff6ea"))
	body_lbl.add_theme_color_override("font_outline_color", Color(0.29, 0.173, 0.165, 1))
	body_lbl.add_theme_constant_override("outline_size", 4)
	body_lbl.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)
	row.add_child(body_lbl)
	lines.add_child(row)
	while lines.get_child_count() > 40:
		var oldest := lines.get_child(0)
		lines.remove_child(oldest)
		oldest.queue_free()
	var scroll := $Root.get_node_or_null("ChatDock/Col/ChatLog") as ScrollContainer
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	if display_name != "" and display_name != "Patio":
		_show_mute(display_name)


func _submit_chat() -> void:
	var row := $Root.get_node_or_null("ChatDock/Col/ChatRow")
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


func on_baker_hit(_hits: int) -> void:
	## The weekly board still updates. No toast when a cookie hits another baker.
	_refresh()


func on_collected(kind: String) -> void:
	GameSave.record_explore_find()
	NoticeService.info("Found a %s." % kind)
	_refresh()
