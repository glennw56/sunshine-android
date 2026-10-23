extends CanvasLayer
## Phone HUD. Hole, par, and strokes stay in the top bar. A side power meter
## and a dotted aim line show the putt. Scorecards use the pastry-card colors.

const ThemeLib := preload("res://scripts/ui/bakery_theme.gd")

var _hole: Label
var _par: Label
var _strokes: Label
var _flash: Label
var _banner: Label
var _card: PanelContainer
var _card_title: Label
var _card_best: Label
var _card_rows: VBoxContainer
var _card_summary: VBoxContainer
var _card_continue: Button
var _card_again: Button
var _card_exit: Button
var _look: Button
var _lines: Array[PanelContainer] = []
var _power: Control
var _power_value := 0.0
var _show_power := false
var _cancelling := false
var _aim_points := PackedVector2Array()
var _show_aim := false
var _hint: Label

signal view_requested
signal exit_requested
signal continue_requested
signal play_again_requested
signal look_toggled(on: bool)


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	ThemeLib.apply(root)
	_bar(root)
	_hint_label(root)
	_banner_label(root)
	_flash_label(root)
	_buttons(root)
	_scorecard(root)
	_power = Control.new()
	_power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power.set_anchors_preset(Control.PRESET_FULL_RECT)
	_power.draw.connect(_draw_power)
	root.add_child(_power)


func set_status(hole: int, par: int, strokes: int) -> void:
	_hole.text = "Hole %d/18" % hole
	_par.text = "Par %d" % par
	_strokes.text = "Strokes %d" % strokes
	var over := strokes > par and strokes > 0
	_strokes.add_theme_color_override("font_color", Color("c43838") if over else ThemeLib.WINE)


func set_power(power: float, _at: Vector2, show: bool, cancelling: bool = false) -> void:
	_power_value = clampf(power, 0.0, 1.0)
	_cancelling = cancelling
	_show_power = show or cancelling
	_power.queue_redraw()


func set_aim_screen(points: PackedVector2Array, show: bool) -> void:
	_aim_points = points
	_show_aim = show and points.size() > 0
	_power.queue_redraw()


func set_hint(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = text != ""


func flash(text: String) -> void:
	_flash.text = text
	_flash.visible = text != ""


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func hide_banner() -> void:
	_banner.visible = false


func show_scorecard(card: Dictionary) -> void:
	_card_title.text = str(card.get("title", "Scorecard"))
	var banner := ""
	if bool(card.get("new_best", false)):
		banner = "New best!"
	elif int(card.get("best", 0)) > 0:
		banner = "Best %d" % int(card.get("best", 0))
	_card_best.text = banner
	_card_best.visible = banner != ""
	var rows: Array = card.get("rows", [])
	var shown := 0
	for i in _lines.size():
		var line := _lines[i]
		if i < rows.size():
			_fill_line(line, rows[i])
			line.visible = true
			shown += 1
		else:
			line.visible = false
	_fill_summary(card)
	var final_card := bool(card.get("final", false))
	_card_continue.visible = not final_card
	_card_continue.text = str(card.get("continue_text", "Back nine"))
	_card.visible = true
	call_deferred("_report_card", shown)


func hide_scorecard() -> void:
	_card.visible = false


func reset_chrome() -> void:
	hide_scorecard()
	hide_banner()
	flash("")
	set_hint("")
	set_power(0.0, Vector2.ZERO, false, false)
	set_aim_screen(PackedVector2Array(), false)
	if _look:
		_look.set_pressed_no_signal(false)


func _bar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16
	bar.offset_top = 18
	bar.offset_right = -16
	bar.offset_bottom = 96
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	_hole = _pill(bar, "Hole 1/18")
	_par = _pill(bar, "Par 2")
	_strokes = _pill(bar, "Strokes 0")


func _pill(parent: Node, text: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := ThemeLib.card_style()
	style.set_corner_radius_all(18)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", ThemeLib.SIZE_BODY)
	label.add_theme_color_override("font_color", ThemeLib.WINE)
	panel.add_child(label)
	return label


func _hint_label(root: Control) -> void:
	_hint = Label.new()
	_hint.visible = false
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_top = 108
	_hint.offset_bottom = 168
	_hint.offset_left = -420
	_hint.offset_right = 420
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 32)
	_hint.add_theme_color_override("font_color", ThemeLib.CREAM)
	_hint.add_theme_color_override("font_outline_color", ThemeLib.WINE)
	_hint.add_theme_constant_override("outline_size", 10)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)


func _banner_label(root: Control) -> void:
	_banner = Label.new()
	_banner.visible = false
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_top = -80
	_banner.offset_bottom = 20
	_banner.offset_left = -280
	_banner.offset_right = 280
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_color", ThemeLib.CREAM)
	_banner.add_theme_color_override("font_outline_color", ThemeLib.WINE)
	_banner.add_theme_constant_override("outline_size", 16)
	root.add_child(_banner)


func _flash_label(root: Control) -> void:
	_flash = Label.new()
	_flash.visible = false
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.offset_top = 110
	_flash.offset_bottom = 170
	_flash.offset_left = -260
	_flash.offset_right = 260
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_theme_font_size_override("font_size", ThemeLib.SIZE_TITLE)
	_flash.add_theme_color_override("font_color", ThemeLib.CREAM)
	_flash.add_theme_color_override("font_outline_color", Color("8a3d2a"))
	_flash.add_theme_constant_override("outline_size", 10)
	root.add_child(_flash)


func _buttons(root: Control) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_top = -132
	row.offset_bottom = -24
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(row)
	_look = Button.new()
	_look.text = "Look"
	_look.toggle_mode = true
	_look.theme_type_variation = "SecondaryButton"
	_look.custom_minimum_size = Vector2(160, 96)
	_look.add_theme_font_size_override("font_size", 28)
	_look.toggled.connect(func(on: bool): look_toggled.emit(on))
	row.add_child(_look)
	var view := Button.new()
	view.text = "View hole"
	view.custom_minimum_size = Vector2(0, 96)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_theme_font_size_override("font_size", 28)
	view.pressed.connect(func(): view_requested.emit())
	row.add_child(view)
	var leave := Button.new()
	leave.text = "Exit"
	leave.theme_type_variation = "SecondaryButton"
	leave.custom_minimum_size = Vector2(160, 96)
	leave.add_theme_font_size_override("font_size", 28)
	leave.pressed.connect(func(): exit_requested.emit())
	row.add_child(leave)


func _scorecard(root: Control) -> void:
	_card = PanelContainer.new()
	_card.visible = false
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.offset_left = 12
	_card.offset_top = 12
	_card.offset_right = -12
	_card.offset_bottom = -12
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.clip_contents = true
	var style := ThemeLib.card_style()
	style.set_corner_radius_all(28)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", style)
	root.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.add_child(box)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 30)
	_card_title.add_theme_color_override("font_color", ThemeLib.WINE)
	box.add_child(_card_title)
	_card_best = Label.new()
	_card_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_best.add_theme_font_size_override("font_size", 26)
	_card_best.add_theme_color_override("font_color", ThemeLib.WINE)
	_card_best.visible = false
	box.add_child(_card_best)
	box.add_child(_header_line())
	_card_rows = VBoxContainer.new()
	_card_rows.add_theme_constant_override("separation", 1)
	_card_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_card_rows)
	for i in 18:
		var line := _data_line(i)
		_lines.append(line)
		_card_rows.add_child(line)
	_card_summary = VBoxContainer.new()
	_card_summary.add_theme_constant_override("separation", 0)
	box.add_child(_card_summary)
	for title in ["Out", "In", "Total"]:
		_card_summary.add_child(_summary_line(title))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	_card_continue = _card_button(buttons, "Back nine", false)
	_card_continue.pressed.connect(func(): continue_requested.emit())
	_card_again = _card_button(buttons, "Play again", false)
	_card_again.pressed.connect(func(): play_again_requested.emit())
	_card_exit = _card_button(buttons, "Exit", true)
	_card_exit.pressed.connect(func(): exit_requested.emit())


func _header_line() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, 28)
	for spec in [["#", 40], ["Hole", 0], ["Par", 52], ["Str", 52], ["+/-", 58], ["OB", 44]]:
		var label := Label.new()
		label.text = str(spec[0])
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", ThemeLib.WINE)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if str(spec[0]) == "Hole":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			label.custom_minimum_size = Vector2(int(spec[1]), 0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)
	return row


func _data_line(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 40)
	var tone := StyleBoxFlat.new()
	tone.bg_color = Color(ThemeLib.BLUSH, 0.45) if index % 2 == 0 else Color(ThemeLib.CREAM, 0.01)
	tone.content_margin_left = 4
	tone.content_margin_right = 4
	tone.content_margin_top = 1
	tone.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", tone)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	for spec in [["hole", 40], ["name", 0], ["par", 52], ["strokes", 52], ["plus", 58], ["oob", 44]]:
		var label := Label.new()
		label.name = str(spec[0])
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", ThemeLib.INK)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if str(spec[0]) == "name":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.clip_text = true
		else:
			label.custom_minimum_size = Vector2(int(spec[1]), 0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)
	return panel


func _summary_line(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = title
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 28)
	for spec in [["title", 90], ["strokes", 90], ["par", 120], ["plus", 80]]:
		var label := Label.new()
		label.name = str(spec[0])
		label.custom_minimum_size = Vector2(int(spec[1]), 0)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", ThemeLib.WINE)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
	return row


func _card_button(parent: Node, text: String, secondary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	if secondary:
		button.theme_type_variation = "SecondaryButton"
	parent.add_child(button)
	return button


func _fill_line(panel: PanelContainer, row: Variant) -> void:
	var data: Dictionary = row
	var box := panel.get_child(0)
	var par_n := int(data.get("par", 0))
	var strokes := int(data.get("strokes", 0))
	var plus := int(data.get("plus", strokes - par_n))
	var oob_n := int(data.get("oob", 0))
	_set_cell(box, "hole", str(int(data.get("hole", 0))))
	_set_cell(box, "name", str(data.get("name", "")))
	_set_cell(box, "par", str(par_n))
	_set_cell(box, "strokes", str(strokes))
	_set_cell(box, "plus", _plus_text(plus))
	_set_cell(box, "oob", str(oob_n) if oob_n > 0 else "·")
	var strokes_label := box.get_node("strokes") as Label
	var plus_label := box.get_node("plus") as Label
	var over := Color("c43838") if plus > 0 else ThemeLib.INK
	strokes_label.add_theme_color_override("font_color", over)
	plus_label.add_theme_color_override("font_color", over)


func _fill_summary(card: Dictionary) -> void:
	var final_card := bool(card.get("final", false))
	_write_summary("Out", int(card.get("out_strokes", 0)), int(card.get("out_par", 0)))
	_write_summary("In", int(card.get("in_strokes", 0)), int(card.get("in_par", 0)))
	_write_summary("Total", int(card.get("total", 0)), int(card.get("total_par", 0)))
	var inn := _card_summary.get_node("In") as CanvasItem
	var total := _card_summary.get_node("Total") as CanvasItem
	inn.visible = final_card
	total.visible = final_card


func _write_summary(title: String, strokes: int, par_n: int) -> void:
	var row := _card_summary.get_node(title)
	_set_cell(row, "title", title)
	_set_cell(row, "strokes", str(strokes))
	_set_cell(row, "par", "Par %d" % par_n)
	_set_cell(row, "plus", _plus_text(strokes - par_n))


func _set_cell(row: Node, cell: String, text: String) -> void:
	var label := row.get_node(cell) as Label
	label.text = text


func _plus_text(plus: int) -> String:
	if plus > 0:
		return "+%d" % plus
	if plus == 0:
		return "E"
	return str(plus)


func _report_card(shown: int) -> void:
	if _card == null or not _card.visible:
		return
	var card_rect := _card.get_global_rect()
	var last := _lines[shown - 1] if shown > 0 else null
	var last_rect := last.get_global_rect() if last else Rect2()
	var buttons := _card_exit.get_global_rect()
	var inside := card_rect.encloses(last_rect) and card_rect.encloses(buttons) if last else false
	print("CARD rect ", card_rect, " rows ", shown, " last ", last_rect, " buttons ", buttons, " inside ", inside)


func _draw_power() -> void:
	if _show_aim:
		for point in _aim_points:
			_power.draw_circle(point, 18.0, Color("5c2a2a"))
			_power.draw_circle(point, 11.0, Color("fffaf4"))
	if not _show_power:
		return
	var size := _power.size
	var meter_h := clampf(size.y * 0.42, 220.0, 520.0)
	var meter := Rect2(size.x - 108.0, (size.y - meter_h) * 0.5, 64.0, meter_h)
	_power.draw_rect(meter, Color(0.29, 0.11, 0.16, 0.55), true)
	var inner := meter.grow(-6.0)
	_power.draw_rect(inner, Color(1, 0.96, 0.91, 0.35), true)
	var col := Color("7dce6a")
	if _power_value > 0.72:
		col = Color("d64545")
	elif _power_value > 0.42:
		col = Color("e0b04a")
	if _cancelling:
		col = Color(1, 1, 1, 0.25)
	var fill_h := inner.size.y * _power_value
	var fill := Rect2(inner.position.x, inner.position.y + inner.size.y - fill_h, inner.size.x, fill_h)
	if fill_h > 1.0:
		_power.draw_rect(fill, col, true)
	var font := ThemeDB.fallback_font
	var label := "Cancel" if _cancelling else "Power"
	_power.draw_string(font, Vector2(meter.position.x - 8.0, meter.position.y - 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 28, Color("fff6ea"))
	if not _cancelling and _power_value > 0.02:
		var pct := "%d" % int(round(_power_value * 100.0))
		_power.draw_string(font, Vector2(meter.position.x, meter.position.y + meter.size.y + 36.0), pct, HORIZONTAL_ALIGNMENT_LEFT, 64.0, 28, Color("fff6ea"))
