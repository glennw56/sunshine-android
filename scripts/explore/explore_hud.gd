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
	## Status already carries the live hunt; hide the duplicate so it cannot collide with the board.
	_fresh_tip.visible = not active
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
		if rank > 5:
			break


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
		_toss.z_index = 8


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
