extends Control
## Signup-gated avatar customize. Saves on the signed-in account (server first).

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
const AvatarPreviewScript := preload("res://scripts/explore/avatar_preview.gd")
const StorefrontPhoto := preload("res://scripts/ui/storefront_photo.gd")

var _recipe: Dictionary = {}
var _preview: VBoxContainer
var _status: Label
var _confirm: PanelContainer
var _confirm_label: Label
var _user: LineEdit
var _nick: LineEdit
var _choice_buttons: Dictionary = {}
var _slot_panels: Dictionary = {}
var _slot_chips: Dictionary = {}
var _saving := false
const _BLUSH := Color("e8b4b8")
const _WINE := Color("722F37")
const _CREAM := Color("FFF8F0")


func _ready() -> void:
	BakeryTheme.apply(self)
	if not ProfileStore.can_customize():
		if get_tree().current_scene == self:
			AppConfig.go("res://scenes/account/login.tscn")
		return
	await ProfileStore.refresh_from_server()
	_recipe = ProfileStore.current_avatar()
	_build()
	_refresh_preview()


func _build() -> void:
	StorefrontPhoto.apply(get_node_or_null("Storefront") as TextureRect)
	var card := $Safe/Card
	card.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	$Safe/Card/Pad/Col/Title.add_theme_color_override("font_color", BakeryTheme.WINE)
	$Safe/Card/Pad/Col/Title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	$Safe/Card/Pad/Col/Copy.add_theme_color_override("font_color", BakeryTheme.MUTED)
	$Safe/Card/Pad/Col/Copy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	$Safe/Card/Pad/Col.add_theme_constant_override("separation", 14)
	$Safe.add_theme_constant_override("margin_left", 28)
	$Safe.add_theme_constant_override("margin_right", 28)
	$Safe.add_theme_constant_override("margin_top", 24)
	$Safe.add_theme_constant_override("margin_bottom", 24)
	$Safe/Card/Pad.add_theme_constant_override("margin_left", 20)
	$Safe/Card/Pad.add_theme_constant_override("margin_right", 20)
	$Safe/Card/Pad.add_theme_constant_override("margin_top", 18)
	$Safe/Card/Pad.add_theme_constant_override("margin_bottom", 18)
	$Safe/Card/Pad/Col/Copy.text = "Pick a slot, then a piece. Your look saves on this Sunshine account."
	_status = $Safe/Card/Pad/Col/Status
	_status.add_theme_color_override("font_color", _WINE)
	_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_mount_save_confirm()
	_user = $Safe/Card/Pad/Col/Username
	_nick = $Safe/Card/Pad/Col/DisplayName
	_user.text = ProfileStore.username
	_nick.text = ProfileStore.display_name
	_user.custom_minimum_size = Vector2(0, 56)
	_nick.custom_minimum_size = Vector2(0, 56)
	$Safe/Card/Pad/Col/Save.custom_minimum_size = Vector2(0, 72)
	$Safe/Card/Pad/Col/Save.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	$Safe/Card/Pad/Col/Explore.theme_type_variation = "SecondaryButton"
	$Safe/Card/Pad/Col/Explore.custom_minimum_size = Vector2(0, 64)
	$Safe/Card/Pad/Col/Explore.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	$Safe/Card/Pad/Col/Back.theme_type_variation = "SecondaryButton"
	$Safe/Card/Pad/Col/Back.custom_minimum_size = Vector2(0, 64)
	$Safe/Card/Pad/Col/Back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	$Safe/Card/Pad/Col/Save.pressed.connect(_on_save)
	$Safe/Card/Pad/Col/Explore.pressed.connect(_on_explore)
	$Safe/Card/Pad/Col/Back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_fill_choices($Safe/Card/Pad/Col/Scroll/Choices)
	var host := $Safe/Card/Pad/Col/PreviewHost
	var frame := PanelContainer.new()
	frame.name = "PreviewFrame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _preview_frame_style())
	host.add_child(frame)
	_preview = AvatarPreviewScript.new()
	_preview.name = "AvatarPreview"
	frame.add_child(_preview)
	var portrait := _preview.get_node_or_null("Portrait") as Control
	if portrait:
		portrait.custom_minimum_size = Vector2(0, 240)


func _fill_choices(box: VBoxContainer) -> void:
	box.add_theme_constant_override("separation", 16)
	var intro := Label.new()
	intro.text = "Slots"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	intro.add_theme_color_override("font_color", _WINE)
	box.add_child(intro)
	var chips := GridContainer.new()
	chips.name = "SlotChips"
	chips.columns = 3
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 12)
	box.add_child(chips)
	var options_host := VBoxContainer.new()
	options_host.name = "SlotOptions"
	options_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_host.add_theme_constant_override("separation", 12)
	box.add_child(options_host)
	var slots: Array = [
		["Skin", "skin", CosContracts.SKINS],
		["Hair", "hair", CosContracts.HAIRS],
		["Hair color", "hair_color", CosContracts.HAIR_COLORS],
		["Outfit", "outfit", CosContracts.OUTFITS],
		["Bottoms", "bottoms", CosContracts.BOTTOMS],
		["Pants", "pants", CosContracts.PANTS],
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
		chip.custom_minimum_size = Vector2(0, 64)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		var captured_field := field
		chip.pressed.connect(func(): show_slot(captured_field))
		chips.add_child(chip)
		_slot_chips[field] = chip
		var panel := VBoxContainer.new()
		panel.name = "Slot_%s" % field
		panel.visible = false
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 12)
		options_host.add_child(panel)
		var heading := Label.new()
		heading.text = title
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
		heading.add_theme_color_override("font_color", _WINE)
		panel.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2 if options.size() <= 4 else 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		panel.add_child(grid)
		var buttons: Array = []
		for option in options:
			var btn := Button.new()
			btn.text = option.capitalize()
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(0, 72)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
			btn.set_meta("choice", option)
			var captured := option
			var field_now := field
			btn.pressed.connect(func(): _pick(field_now, captured))
			grid.add_child(btn)
			buttons.append(btn)
		_choice_buttons[field] = buttons
		_slot_panels[field] = panel
		_paint_row(field)
	show_slot("skin")


func show_slot(field: String) -> void:
	for key in _slot_panels.keys():
		var panel: Variant = _slot_panels[key]
		if panel is CanvasItem:
			(panel as CanvasItem).visible = str(key) == field
	for key in _slot_chips.keys():
		var chip: Variant = _slot_chips[key]
		if chip is Button:
			_style_chip(chip as Button, str(key) == field)


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


func _style_choice(btn: Button, on: bool, field: String, choice: String) -> void:
	var box := _choice_box(on)
	var swatch := _swatch(field, choice)
	if swatch.a > 0.01:
		box.bg_color = box.bg_color.lerp(swatch, 0.22 if not on else 0.35)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("focus", box)
	btn.add_theme_color_override("font_color", _WINE)
	btn.modulate = Color.WHITE


func _choice_box(on: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _BLUSH if on else _CREAM
	box.border_color = _WINE if on else _BLUSH
	box.set_border_width_all(4 if on else 2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _swatch(field: String, option: String) -> Color:
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


func _preview_frame_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _CREAM
	box.border_color = _BLUSH
	box.set_border_width_all(4)
	box.set_corner_radius_all(18)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _mount_save_confirm() -> void:
	var col := $Safe/Card/Pad/Col
	_confirm = PanelContainer.new()
	_confirm.name = "SaveConfirm"
	_confirm.visible = false
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var band := StyleBoxFlat.new()
	band.bg_color = _BLUSH
	band.border_color = _WINE
	band.set_border_width_all(3)
	band.set_corner_radius_all(16)
	band.content_margin_left = 16
	band.content_margin_right = 16
	band.content_margin_top = 12
	band.content_margin_bottom = 12
	_confirm.add_theme_stylebox_override("panel", band)
	_confirm_label = Label.new()
	_confirm_label.name = "SaveConfirmText"
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_confirm_label.add_theme_color_override("font_color", _WINE)
	_confirm.add_child(_confirm_label)
	col.add_child(_confirm)
	col.move_child(_confirm, _status.get_index())


func _present_status(text: String) -> void:
	_status.text = text
	if _confirm == null or _confirm_label == null:
		return
	_confirm_label.text = text
	_confirm.visible = text.strip_edges() != ""


func _pick(field: String, value: String) -> void:
	_recipe[field] = value
	_recipe = CosContracts.sanitize_avatar(_recipe)
	_paint_row(field)
	_refresh_preview()


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
	_present_status("Saving your look…")
	await ProfileStore.save_avatar(_recipe, true)
	_recipe = ProfileStore.current_avatar()
	for field in _choice_buttons.keys():
		_paint_row(str(field))
	_refresh_preview()
	_saving = false
	if ProfileStore.last_remote_ok:
		if ProfileStore.last_remote_source == "square":
			_present_status("Look saved on your Sunshine account.")
		elif ProfileStore.last_remote_source == "explore" or ProfileStore.last_remote_source == "file":
			_present_status("Look saved. We'll keep it on Square the next time the bakery answers.")
		else:
			_present_status("Look saved on your Sunshine account.")
	elif AccountClient.has_session_token():
		_present_status("Saved on this phone. Could not reach the bakery yet.")
	else:
		_present_status("Saved on this phone. Sign in to keep it on your Sunshine account.")


func _on_explore() -> void:
	await _on_save()
	if _status.text.begins_with("Look saved") or _status.text.begins_with("Saved on this phone"):
		AppConfig.go(AppConfig.explore_scene_path())
