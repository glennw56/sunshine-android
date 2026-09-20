extends Control
## Signup-gated avatar customize. Saves forever on the signed-in account vault.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")
const StorefrontPhoto := preload("res://scripts/ui/storefront_photo.gd")

var _recipe: Dictionary = {}
var _avatar: AvatarBody
var _status: Label
var _user: LineEdit
var _nick: LineEdit


func _ready() -> void:
	BakeryTheme.apply(self)
	if not ProfileStore.can_customize():
		NoticeService.info("Sign in with phone to save your look forever.")
		if get_tree().current_scene == self:
			AppConfig.go("res://scenes/account/login.tscn")
		return
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
	_status = $Safe/Card/Pad/Col/Status
	_status.add_theme_color_override("font_color", BakeryTheme.WINE)
	_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
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
	var world := SubViewport.new()
	world.size = Vector2i(560, 480)
	world.transparent_bg = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Node3D.new()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, 28, 0)
	light.light_energy = 1.05
	root.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0.22, 0.98, 1.35)
	cam.look_at_from_position(cam.position, Vector3(0, 0.78, 0))
	root.add_child(cam)
	_avatar = AvatarBodyScript.new()
	_avatar.position = Vector3(0, 0, 0)
	_avatar.scale = Vector3(1.35, 1.35, 1.35)
	root.add_child(_avatar)
	world.add_child(root)
	host.add_child(world)
	var rect := TextureRect.new()
	rect.texture = world.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(0, 280)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(rect)


func _fill_choices(box: VBoxContainer) -> void:
	_choice_row(box, "Skin", "skin", CosContracts.SKINS)
	_choice_row(box, "Hair", "hair", CosContracts.HAIRS)
	_choice_row(box, "Hair color", "hair_color", CosContracts.HAIR_COLORS)
	_choice_row(box, "Outfit", "outfit", CosContracts.OUTFITS)
	_choice_row(box, "Apron", "apron", CosContracts.APRONS)
	_choice_row(box, "Hat", "hat", CosContracts.HATS)
	_choice_row(box, "Accessory", "accessory", CosContracts.ACCESSORIES)


func _choice_row(box: VBoxContainer, title: String, field: String, options: PackedStringArray) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	label.add_theme_color_override("font_color", BakeryTheme.WINE)
	box.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for option in options:
		var btn := Button.new()
		btn.text = option.capitalize()
		btn.theme_type_variation = "SecondaryButton"
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		var captured := option
		btn.pressed.connect(func(): _pick(field, captured))
		row.add_child(btn)
	box.add_child(row)


func _pick(field: String, value: String) -> void:
	_recipe[field] = value
	_recipe = CosContracts.sanitize_avatar(_recipe)
	_refresh_preview()


func _refresh_preview() -> void:
	if _avatar:
		_avatar.rebuild(_recipe)


func _on_save() -> void:
	var user_err := ProfileStore.set_username(_user.text)
	if user_err != "":
		_status.text = user_err
		return
	var name_err := ProfileStore.set_display_name(_nick.text)
	if name_err != "":
		_status.text = name_err
		return
	ProfileStore.save_avatar(_recipe, true)
	_status.text = "Look saved to this Sunshine account."
	NoticeService.info("Your look is saved.")


func _on_explore() -> void:
	_on_save()
	if _status.text.begins_with("Look saved") or _status.text == "":
		AppConfig.go("res://scenes/explore/explore_3d.tscn")
