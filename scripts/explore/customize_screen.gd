extends Control
## Signup-gated avatar customize. Saves on the signed-in account (server first).
## Slot chips stay outside the scroller. One status line. A1 head mesh is untouched.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
const AvatarPreviewScript := preload("res://scripts/explore/avatar_preview.gd")
const StorefrontPhoto := preload("res://scripts/ui/storefront_photo.gd")

var _recipe: Dictionary = {}
var _saved_recipe: Dictionary = {}
var _saved_user := ""
var _saved_nick := ""
var _preview: VBoxContainer
var _status: Label
var _confirm: Panel
var _retry: Button
var _user: LineEdit
var _nick: LineEdit
var _choice_buttons: Dictionary = {}
var _slot_panels: Dictionary = {}
var _slot_chips: Dictionary = {}
var _slot_bar: VBoxContainer
var _edit_btn: Button
var _leave: Control
var _leave_path := ""
var _open_field := "skin"
var _profile_open := false
var _inspecting := false
var _saving := false
var _touch_px := 96
const _BLUSH := Color("e8b4b8")
const _WINE := Color("722F37")
const _CREAM := Color("FFF8F0")
const _PENDING := "Saved on this phone. Account sync pending."
## Older copy still names these slots "Bottoms" and "Pants".
const _LEGACY_SLOT_TITLES := {
	"bottoms": "Bottoms",
	"pants": "Pants",
}


func _ready() -> void:
	BakeryTheme.apply(self)
	if not ProfileStore.can_customize():
		if get_tree().current_scene == self:
			AppConfig.go("res://scenes/account/login.tscn")
		return
	await ProfileStore.refresh_from_server()
	_recipe = ProfileStore.current_avatar()
	_touch_px = _touch_floor_px()
	_build()
	_refresh_preview()


func _build() -> void:
	StorefrontPhoto.apply(get_node_or_null("Storefront") as TextureRect)
	var card := $Safe/Card
	card.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	var col := $Safe/Card/Pad/Col
	$Safe/Card/Pad/Col/Title.add_theme_color_override("font_color", BakeryTheme.WINE)
	$Safe/Card/Pad/Col/Title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	var copy := $Safe/Card/Pad/Col/Copy
	copy.text = "Pick a slot, then a piece."
	copy.add_theme_color_override("font_color", BakeryTheme.MUTED)
	copy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	col.add_theme_constant_override("separation", 8)
	$Safe.add_theme_constant_override("margin_left", 16)
	$Safe.add_theme_constant_override("margin_right", 16)
	$Safe.add_theme_constant_override("margin_top", 12)
	$Safe.add_theme_constant_override("margin_bottom", 12)
	$Safe/Card/Pad.add_theme_constant_override("margin_left", 12)
	$Safe/Card/Pad.add_theme_constant_override("margin_right", 12)
	$Safe/Card/Pad.add_theme_constant_override("margin_top", 10)
	$Safe/Card/Pad.add_theme_constant_override("margin_bottom", 10)
	_status = $Safe/Card/Pad/Col/Status
	_mount_save_confirm()
	_user = $Safe/Card/Pad/Col/Username
	_nick = $Safe/Card/Pad/Col/DisplayName
	_user.text = ProfileStore.username
	_nick.text = ProfileStore.display_name
	_user.placeholder_text = "Username"
	_nick.placeholder_text = "Display name"
	_apply_min_touch(_user)
	_apply_min_touch(_nick)
	_user.visible = false
	_nick.visible = false
	_user.text_changed.connect(_on_identity_edited)
	_nick.text_changed.connect(_on_identity_edited)
	var save := $Safe/Card/Pad/Col/Save
	_apply_min_touch(save)
	save.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	save.pressed.connect(_on_save)
	var explore := $Safe/Card/Pad/Col/Explore
	var back := $Safe/Card/Pad/Col/Back
	_style_quiet(explore)
	_style_quiet(back)
	explore.pressed.connect(_on_explore)
	back.pressed.connect(_on_menu)
	_mount_quiet_row(explore, back)
	_mount_preview()
	_fill_choices($Safe/Card/Pad/Col/Scroll/Choices)
	_sync_pants_chip()
	_mount_leave()
	_remember_saved()
	_present_status("")
	show_slot("skin")


func _mount_preview() -> void:
	var host := $Safe/Card/Pad/Col/PreviewHost
	var frame := PanelContainer.new()
	frame.name = "PreviewFrame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _preview_frame_style())
	host.add_child(frame)
	_preview = AvatarPreviewScript.new()
	_preview.name = "AvatarPreview"
	frame.add_child(_preview)
	if _preview.has_method("frame_baker"):
		_preview.call("frame_baker", 0.80)
	var portrait := _preview.get_node_or_null("Portrait") as Control
	if portrait:
		portrait.custom_minimum_size = Vector2(0, 232)
		portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		portrait.tooltip_text = "Drag to turn. Tap to look closer."
	if _preview.has_signal("portrait_tapped"):
		_preview.connect("portrait_tapped", _on_portrait_tapped)


func _mount_quiet_row(explore: Button, back: Button) -> void:
	var row := HBoxContainer.new()
	row.name = "QuietRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var col := $Safe/Card/Pad/Col
	col.add_child(row)
	_edit_btn = Button.new()
	_edit_btn.name = "EditProfile"
	_edit_btn.text = "Edit profile"
	_edit_btn.focus_mode = Control.FOCUS_NONE
	_style_quiet(_edit_btn)
	_edit_btn.pressed.connect(_toggle_profile)
	row.add_child(_edit_btn)
	explore.reparent(row)
	back.reparent(row)
	for btn in [_edit_btn, explore, back]:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _fill_choices(box: VBoxContainer) -> void:
	box.add_theme_constant_override("separation", 8)
	var col := $Safe/Card/Pad/Col
	_slot_bar = VBoxContainer.new()
	_slot_bar.name = "SlotBar"
	_slot_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_bar.add_theme_constant_override("separation", 0)
	col.add_child(_slot_bar)
	col.move_child(_slot_bar, $Safe/Card/Pad/Col/Scroll.get_index())
	var chips := GridContainer.new()
	chips.name = "SlotChips"
	chips.columns = 3
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	_slot_bar.add_child(chips)
	var options_host := VBoxContainer.new()
	options_host.name = "SlotOptions"
	options_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_host.add_theme_constant_override("separation", 8)
	box.add_child(options_host)
	var slots: Array = [
		["Skin", "skin", CosContracts.SKINS],
		["Hair", "hair", CosContracts.HAIRS],
		["Hair color", "hair_color", CosContracts.HAIR_COLORS],
		["Top color", "outfit", CosContracts.OUTFITS],
		["Bottom style", "bottoms", CosContracts.BOTTOMS],
		["Pants color", "pants", CosContracts.PANTS],
		["Apron", "apron", CosContracts.APRONS],
		["Hat", "hat", CosContracts.HATS],
		["Accessory", "accessory", CosContracts.ACCESSORIES],
	]
	for slot in slots:
		var title := str(slot[0])
		var field := str(slot[1])
		var options: PackedStringArray = slot[2]
		var chip := Button.new()
		chip.text = title
		chip.focus_mode = Control.FOCUS_NONE
		chip.clip_text = false
		_apply_min_touch(chip)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		if _LEGACY_SLOT_TITLES.has(field):
			chip.tooltip_text = str(_LEGACY_SLOT_TITLES[field])
		var captured_field := field
		chip.pressed.connect(func(): show_slot(captured_field))
		chips.add_child(chip)
		_slot_chips[field] = chip
		var panel := VBoxContainer.new()
		panel.name = "Slot_%s" % field
		panel.visible = false
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 8)
		options_host.add_child(panel)
		var glyph_slot := field == "hair" or field == "hat" or field == "accessory"
		var grid := GridContainer.new()
		grid.columns = 2 if glyph_slot or options.size() <= 4 else 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		panel.add_child(grid)
		var buttons: Array = []
		for option in options:
			var btn := _make_choice(field, option, glyph_slot)
			grid.add_child(btn)
			buttons.append(btn)
		_choice_buttons[field] = buttons
		_slot_panels[field] = panel
		_paint_row(field)


func _make_choice(field: String, option: String, glyph_slot: bool) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = false
	_apply_min_touch(btn)
	if glyph_slot:
		btn.custom_minimum_size = Vector2(btn.custom_minimum_size.x, maxf(btn.custom_minimum_size.y, float(_touch_px) + 28.0))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	btn.set_meta("choice", option)
	btn.text = "" if glyph_slot else option.capitalize()
	if glyph_slot:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.layout_mode = 1
		column.set_anchors_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 6
		column.offset_top = 4
		column.offset_right = -6
		column.offset_bottom = -4
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		var glyph := OptionGlyph.new()
		glyph.kind = field
		glyph.option = option
		glyph.tint = _glyph_tint(field)
		glyph.custom_minimum_size = Vector2(0, 52)
		glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(glyph)
		var caption := Label.new()
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.text = option.capitalize()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		caption.add_theme_color_override("font_color", _WINE)
		column.add_child(caption)
		btn.add_child(column)
		btn.set_meta("glyph", glyph)
	var check := Label.new()
	check.name = "Check"
	check.text = "✓"
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.layout_mode = 1
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	check.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	check.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	check.add_theme_color_override("font_color", _WINE)
	check.visible = false
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	check.offset_right = -8
	check.offset_top = 2
	btn.add_child(check)
	btn.set_meta("check", check)
	var captured := option
	var field_now := field
	btn.pressed.connect(func(): _pick(field_now, captured))
	return btn


func show_slot(field: String) -> void:
	_open_field = field
	for key in _slot_panels.keys():
		var panel: Variant = _slot_panels[key]
		if panel is CanvasItem:
			(panel as CanvasItem).visible = str(key) == field
	for key in _slot_chips.keys():
		var chip: Variant = _slot_chips[key]
		if chip is Button:
			_style_chip(chip as Button, str(key) == field)
	var scroll := $Safe/Card/Pad/Col/Scroll as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


func _paint_row(field: String) -> void:
	var buttons: Variant = _choice_buttons.get(field, [])
	if not buttons is Array:
		return
	var current := str(_recipe.get(field, ""))
	for btn in buttons:
		if not btn is Button:
			continue
		var choice := str((btn as Button).get_meta("choice", ""))
		_style_choice(btn as Button, choice == current, field, choice)


func _style_chip(btn: Button, on: bool) -> void:
	var box := _choice_box(on)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("focus", box)
	btn.add_theme_color_override("font_color", _WINE)
	btn.add_theme_color_override("font_hover_color", _WINE)
	btn.add_theme_color_override("font_pressed_color", _WINE)


func _style_choice(btn: Button, on: bool, field: String, choice: String) -> void:
	var swatch := _swatch(field, choice)
	var box := _flat_box()
	var ink := _WINE
	if swatch.a > 0.01:
		box.bg_color = swatch
		ink = _CREAM if swatch.get_luminance() < 0.42 else _WINE
	else:
		box.bg_color = _CREAM
	box.border_color = _WINE if on else _BLUSH
	box.set_border_width_all(4 if on else 2)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("focus", box)
	btn.add_theme_color_override("font_color", ink)
	btn.add_theme_color_override("font_hover_color", ink)
	btn.add_theme_color_override("font_pressed_color", ink)
	btn.modulate = Color.WHITE
	if btn.has_meta("check"):
		var check: Variant = btn.get_meta("check")
		if check is Label:
			(check as Label).visible = on
			(check as Label).add_theme_color_override("font_color", ink)
	if btn.has_meta("glyph"):
		var glyph: Variant = btn.get_meta("glyph")
		if glyph is OptionGlyph:
			(glyph as OptionGlyph).tint = _glyph_tint(field)
			(glyph as OptionGlyph).queue_redraw()


func _choice_box(on: bool) -> StyleBoxFlat:
	var box := _flat_box()
	box.bg_color = _BLUSH if on else _CREAM
	box.border_color = _WINE if on else _BLUSH
	box.set_border_width_all(4 if on else 2)
	return box


func _flat_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _CREAM
	box.border_color = _BLUSH
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.shadow_size = 0
	box.shadow_offset = Vector2.ZERO
	return box


func _swatch(field: String, option: String) -> Color:
	if option == "none":
		return Color(0, 0, 0, 0)
	if field == "skin":
		return CosContracts.SKIN_COLORS.get(option, Color(0, 0, 0, 0))
	if field == "hair_color":
		return CosContracts.HAIR_TINTS.get(option, Color(0, 0, 0, 0))
	if field == "outfit":
		return CosContracts.OUTFIT_COLORS.get(option, Color(0, 0, 0, 0))
	if field == "pants":
		return CosContracts.PANTS_COLORS.get(option, Color(0, 0, 0, 0))
	if field == "apron":
		if option == "grey":
			return Color("c5c0be")
		if option == "blush":
			return _BLUSH
		if option == "wine":
			return _WINE
	return Color(0, 0, 0, 0)


func _glyph_tint(field: String) -> Color:
	if field == "hair":
		return CosContracts.HAIR_TINTS.get(str(_recipe.get("hair_color", "brown")), Color("3d2418"))
	return _WINE


func _preview_frame_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _CREAM
	box.border_color = _BLUSH
	box.set_border_width_all(4)
	box.set_corner_radius_all(18)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.shadow_size = 0
	return box


func _mount_save_confirm() -> void:
	var col := $Safe/Card/Pad/Col
	_confirm = Panel.new()
	_confirm.name = "SaveConfirm"
	_confirm.clip_contents = true
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size = Vector2(0, _touch_px + 8)
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_confirm)
	col.move_child(_confirm, _status.get_index())
	_status.reparent(_confirm)
	_status.layout_mode = 1
	_status.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status.offset_left = 12
	_status.offset_top = 6
	_status.offset_right = -12
	_status.offset_bottom = -6
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.clip_text = true
	_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_status.add_theme_color_override("font_color", _WINE)
	_retry = Button.new()
	_retry.name = "Retry"
	_retry.text = "Retry"
	_retry.focus_mode = Control.FOCUS_NONE
	_retry.visible = false
	_apply_min_touch(_retry)
	_retry.layout_mode = 1
	_retry.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_retry.offset_left = -float(_touch_px) - 8.0
	_retry.offset_right = -8
	_retry.offset_top = -float(_touch_px) * 0.5
	_retry.offset_bottom = float(_touch_px) * 0.5
	_retry.pressed.connect(_on_save)
	_confirm.add_child(_retry)


func _present_status(text: String) -> void:
	if _status == null:
		return
	_status.text = text
	var pending := text == _PENDING
	if _retry:
		_retry.visible = pending
	if _status:
		_status.offset_right = (-float(_touch_px) - 16.0) if pending else -12.0
	if _confirm == null:
		return
	var band := _flat_box()
	band.set_corner_radius_all(16)
	band.content_margin_left = 12
	band.content_margin_right = 12
	band.content_margin_top = 8
	band.content_margin_bottom = 8
	if text == "" or text == "Unsaved":
		band.bg_color = _CREAM
		band.border_color = _BLUSH
		band.set_border_width_all(2)
	else:
		band.bg_color = _BLUSH
		band.border_color = _WINE
		band.set_border_width_all(3)
	_confirm.add_theme_stylebox_override("panel", band)


func _pick(field: String, value: String) -> void:
	_recipe[field] = value
	_recipe = CosContracts.sanitize_avatar(_recipe)
	if field == "bottoms":
		_sync_pants_chip()
		if value == "pants":
			show_slot("pants")
		elif _open_field == "pants":
			show_slot("bottoms")
	_paint_row(field)
	if field == "hair_color":
		_paint_row("hair")
	_refresh_preview()
	_note_dirty()


func _sync_pants_chip() -> void:
	var chip: Variant = _slot_chips.get("pants", null)
	if chip is CanvasItem:
		(chip as CanvasItem).visible = str(_recipe.get("bottoms", "skirt")) == "pants"


func _refresh_preview() -> void:
	if _preview and _preview.has_method("show_recipe"):
		_preview.call("show_recipe", _recipe, _nick.text if _nick else ProfileStore.display_name)


func _on_save() -> void:
	if _saving:
		return
	var user_err := ProfileStore.set_username(_user.text)
	if user_err != "":
		_present_status(user_err)
		return
	var name_err := ProfileStore.set_display_name(_nick.text)
	if name_err != "":
		_present_status(name_err)
		return
	_saving = true
	_present_status("Saving…")
	await ProfileStore.save_avatar(_recipe, true)
	_recipe = ProfileStore.current_avatar()
	for field in _choice_buttons.keys():
		_paint_row(str(field))
	_refresh_preview()
	_remember_saved()
	_saving = false
	if ProfileStore.last_remote_ok:
		_present_status("Saved to account")
	else:
		_present_status(_PENDING)


func _on_explore() -> void:
	_request_leave(AppConfig.explore_scene_path())


func _on_menu() -> void:
	_request_leave("res://scenes/main_menu.tscn")


func _toggle_profile() -> void:
	_profile_open = not _profile_open
	_user.visible = _profile_open
	_nick.visible = _profile_open
	if _slot_bar:
		_slot_bar.visible = not _profile_open
	var scroll := $Safe/Card/Pad/Col/Scroll as CanvasItem
	if scroll:
		scroll.visible = not _profile_open
	if _edit_btn:
		_edit_btn.text = "Close profile" if _profile_open else "Edit profile"


func _on_identity_edited(_text: String) -> void:
	_note_dirty()


func _on_portrait_tapped() -> void:
	_inspecting = not _inspecting
	if _preview == null or not _preview.has_method("frame_baker"):
		return
	if _inspecting:
		_preview.call("frame_baker", 0.84, 1.2, 0.78)
	else:
		_preview.call("frame_baker", 0.80)


func _note_dirty() -> void:
	if _saving:
		return
	if _is_dirty():
		_present_status("Unsaved")
	elif _status and _status.text == "Unsaved":
		_present_status("")


func _is_dirty() -> bool:
	if _user == null or _nick == null:
		return false
	if not CosContracts.avatar_equals(_recipe, _saved_recipe):
		return true
	if _user.text.strip_edges() != _saved_user.strip_edges():
		return true
	if _nick.text.strip_edges() != _saved_nick.strip_edges():
		return true
	return false


func _remember_saved() -> void:
	_saved_recipe = CosContracts.sanitize_avatar(_recipe)
	_saved_user = _user.text if _user else ""
	_saved_nick = _nick.text if _nick else ""


func _request_leave(path: String) -> void:
	if not _is_dirty():
		AppConfig.go(path)
		return
	_leave_path = path
	if _leave:
		_leave.visible = true


func _mount_leave() -> void:
	var dim := ColorRect.new()
	dim.name = "LeaveDialog"
	dim.visible = false
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_right = 0
	dim.offset_bottom = 0
	dim.color = Color(0.16, 0.06, 0.09, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.layout_mode = 1
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _preview_frame_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Save your look before leaving?"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	title.add_theme_color_override("font_color", _WINE)
	box.add_child(title)
	var save := Button.new()
	save.text = "Save"
	save.focus_mode = Control.FOCUS_NONE
	_apply_min_touch(save)
	save.pressed.connect(_on_leave_save)
	box.add_child(save)
	var discard := Button.new()
	discard.text = "Discard"
	discard.focus_mode = Control.FOCUS_NONE
	_style_quiet(discard)
	discard.pressed.connect(_on_leave_discard)
	box.add_child(discard)
	var stay := Button.new()
	stay.text = "Keep editing"
	stay.focus_mode = Control.FOCUS_NONE
	_style_quiet(stay)
	stay.pressed.connect(func(): dim.visible = false)
	box.add_child(stay)
	_leave = dim


func _on_leave_save() -> void:
	await _on_save()
	if _status and _status.text.begins_with("Saved"):
		if _leave:
			_leave.visible = false
		AppConfig.go(_leave_path)
	elif _leave:
		_leave.visible = false


func _on_leave_discard() -> void:
	if _leave:
		_leave.visible = false
	AppConfig.go(_leave_path)


func _style_quiet(btn: Button) -> void:
	var box := _flat_box()
	box.bg_color = Color(_CREAM, 0.72)
	box.border_color = Color(_BLUSH, 1.0)
	box.set_border_width_all(2)
	btn.theme_type_variation = ""
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("focus", box)
	btn.add_theme_color_override("font_color", _WINE)
	btn.add_theme_color_override("font_hover_color", _WINE)
	btn.add_theme_color_override("font_pressed_color", _WINE)
	btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_apply_min_touch(btn)


func _apply_min_touch(ctrl: Control) -> void:
	var floor := float(_touch_px)
	ctrl.custom_minimum_size = Vector2(maxf(ctrl.custom_minimum_size.x, 0.0), maxf(ctrl.custom_minimum_size.y, floor))


func _touch_floor_px() -> int:
	## 720-wide canvas. On a 360dp-wide phone, 48dp is 96 viewport pixels.
	## Grow that floor when this window's dpi makes 48dp taller than 96.
	var floor_px := 96
	var dpi := float(DisplayServer.screen_get_dpi())
	var win := DisplayServer.window_get_size()
	var view_w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 720))
	if dpi >= 120.0 and win.x > 0 and view_w > 1.0:
		var dp_per_vp := (float(win.x) / view_w) * (160.0 / dpi)
		if dp_per_vp > 0.01:
			floor_px = maxi(floor_px, int(ceil(48.0 / dp_per_vp)))
	return floor_px


func touch_targets_ok() -> bool:
	var floor_px := _touch_floor_px()
	var short := _controls_shorter_than(self, floor_px)
	if short != "":
		push_error("TOUCH %s" % short)
		return false
	print("TOUCH customize floor=%dpx (48dp on a 360dp-wide phone is 96px at this 720 canvas)" % floor_px)
	return true


func _controls_shorter_than(node: Node, floor_px: int) -> String:
	if node is BaseButton or node is LineEdit:
		var ctrl := node as Control
		var tall := ctrl.custom_minimum_size.y
		if tall > 0.0 and tall + 0.5 < float(floor_px):
			return "%s min %.0f < %d" % [str(ctrl.name), tall, floor_px]
	for child in node.get_children():
		var found := _controls_shorter_than(child, floor_px)
		if found != "":
			return found
	return ""


class OptionGlyph extends Control:
	var kind := ""
	var option := ""
	var tint := Color("3d2418")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.42
		if rad < 4.0:
			return
		if kind == "hair":
			_draw_hair(c, rad)
		elif kind == "hat":
			_draw_hat(c, rad)
		else:
			_draw_accessory(c, rad)

	func _draw_hair(c: Vector2, rad: float) -> void:
		var face := Color("f7d3b8")
		if option == "none":
			draw_circle(c, rad * 0.72, face)
			draw_line(c + Vector2(-rad * 0.7, -rad * 0.7), c + Vector2(rad * 0.7, rad * 0.7), Color("722F37"), 3.0)
			return
		var hair := tint
		if option == "bangs":
			draw_circle(c + Vector2(0, -rad * 0.12), rad * 0.82, hair)
			draw_circle(c + Vector2(0, rad * 0.28), rad * 0.58, face)
		elif option == "short":
			draw_circle(c + Vector2(0, -rad * 0.05), rad * 0.8, hair)
			draw_circle(c + Vector2(0, rad * 0.32), rad * 0.52, face)
		elif option == "bun":
			draw_circle(c + Vector2(0, rad * 0.12), rad * 0.68, face)
			draw_circle(c + Vector2(0, -rad * 0.72), rad * 0.36, hair)
		else:
			draw_circle(c + Vector2(0, -rad * 0.05), rad * 0.86, hair)
			draw_circle(c + Vector2(-rad * 0.48, rad * 0.28), rad * 0.34, hair)
			draw_circle(c + Vector2(rad * 0.48, rad * 0.28), rad * 0.34, hair)
			draw_circle(c + Vector2(0, rad * 0.22), rad * 0.48, face)

	func _draw_hat(c: Vector2, rad: float) -> void:
		if option == "none":
			draw_circle(c, rad * 0.7, Color("fff8f0"))
			draw_line(c + Vector2(-rad * 0.7, -rad * 0.7), c + Vector2(rad * 0.7, rad * 0.7), Color("722F37"), 3.0)
		elif option == "sun":
			draw_circle(c + Vector2(0, rad * 0.08), rad * 0.95, Color("e6b14a"))
			draw_circle(c + Vector2(0, -rad * 0.18), rad * 0.42, Color("c9922e"))
		elif option == "beanie":
			draw_circle(c + Vector2(0, rad * 0.15), rad * 0.62, Color("f7d3b8"))
			draw_circle(c + Vector2(0, -rad * 0.2), rad * 0.7, Color("722F37"))
		else:
			draw_circle(c + Vector2(-rad * 0.36, 0), rad * 0.4, Color("e8b4b8"))
			draw_circle(c + Vector2(rad * 0.36, 0), rad * 0.4, Color("e8b4b8"))
			draw_circle(c, rad * 0.16, Color("722F37"))

	func _draw_accessory(c: Vector2, rad: float) -> void:
		if option == "none":
			draw_circle(c, rad * 0.7, Color("fff8f0"))
			draw_line(c + Vector2(-rad * 0.7, -rad * 0.7), c + Vector2(rad * 0.7, rad * 0.7), Color("722F37"), 3.0)
		elif option == "glasses":
			draw_arc(c + Vector2(-rad * 0.38, 0), rad * 0.32, 0, TAU, 24, Color("722F37"), 3.0)
			draw_arc(c + Vector2(rad * 0.38, 0), rad * 0.32, 0, TAU, 24, Color("722F37"), 3.0)
			draw_line(c + Vector2(-rad * 0.06, -rad * 0.04), c + Vector2(rad * 0.06, -rad * 0.04), Color("722F37"), 3.0)
		elif option == "flower":
			var petal := Color("f0c43a")
			for i in 6:
				var a := float(i) / 6.0 * TAU
				draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.42, rad * 0.28, petal)
			draw_circle(c, rad * 0.22, Color("4a2a12"))
		else:
			draw_rect(Rect2(c.x - rad * 0.9, c.y - rad * 0.28, rad * 1.8, rad * 0.56), Color("e8b4b8"))
