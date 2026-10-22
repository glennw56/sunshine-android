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
var _card_body: RichTextLabel
var _card_button: Button
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


func show_scorecard(title: String, body: String, button_text: String) -> void:
	_card_title.text = title
	_card_body.text = body
	_card_button.text = button_text
	_card.visible = true


func hide_scorecard() -> void:
	_card.visible = false


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
	var look := Button.new()
	look.text = "Look"
	look.toggle_mode = true
	look.theme_type_variation = "SecondaryButton"
	look.custom_minimum_size = Vector2(160, 96)
	look.add_theme_font_size_override("font_size", 28)
	look.toggled.connect(func(on: bool): look_toggled.emit(on))
	row.add_child(look)
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
	_card.offset_left = 24
	_card.offset_top = 120
	_card.offset_right = -24
	_card.offset_bottom = -150
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := ThemeLib.card_style()
	style.set_corner_radius_all(28)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_card.add_theme_stylebox_override("panel", style)
	root.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_card.add_child(box)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", ThemeLib.SIZE_TITLE)
	_card_title.add_theme_color_override("font_color", ThemeLib.WINE)
	box.add_child(_card_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_card_body = RichTextLabel.new()
	_card_body.bbcode_enabled = true
	_card_body.fit_content = true
	_card_body.scroll_active = false
	_card_body.custom_minimum_size = Vector2(0, 200)
	_card_body.add_theme_font_size_override("normal_font_size", 24)
	_card_body.add_theme_color_override("default_color", ThemeLib.INK)
	scroll.add_child(_card_body)
	_card_button = Button.new()
	_card_button.custom_minimum_size = Vector2(0, 78)
	_card_button.pressed.connect(func(): continue_requested.emit())
	box.add_child(_card_button)


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
