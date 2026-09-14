extends Control
## Phone Continue → POST bakery-drinks login. No text-code step. Skip stays guest.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

@onready var _phone: LineEdit = $Safe/Card/Pad/Col/Phone
@onready var _continue: Button = $Safe/Card/Pad/Col/Continue
@onready var _skip: Button = $Safe/Card/Pad/Col/Skip
@onready var _loyalty: CheckBox = $Safe/Card/Pad/Col/Loyalty
@onready var _status: Label = $Safe/Card/Pad/Col/Status
@onready var _title: Label = $Safe/Card/Pad/Col/Title
@onready var _copy: Label = $Safe/Card/Pad/Col/Copy


func _ready() -> void:
	BakeryTheme.apply(self)
	_style()
	if AccountClient.should_skip_login() and get_tree().current_scene == self:
		_go_home()
		return
	_continue.pressed.connect(_on_continue)
	_skip.pressed.connect(_on_skip)
	_phone.text_submitted.connect(func(_t: String): _on_continue())
	if GameSave.square_phone != "":
		_phone.text = AccountClient.format_phone(GameSave.square_phone)


func _style() -> void:
	var bg := get_node_or_null("Storefront") as TextureRect
	if bg:
		bg.texture = load("res://assets/branding/storefront-hero.jpg")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := get_node_or_null("Safe/Card") as PanelContainer
	if card:
		card.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", 30)
	_copy.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_copy.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", BakeryTheme.WINE)
	_continue.custom_minimum_size = Vector2(0, 64)
	_continue.add_theme_font_size_override("font_size", 20)
	_skip.theme_type_variation = "SecondaryButton"
	_skip.custom_minimum_size = Vector2(0, 52)
	_loyalty.add_theme_color_override("font_color", BakeryTheme.INK)
	_phone.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_phone.secret = false


func _on_continue() -> void:
	var e164 := AccountClient.normalize_phone(_phone.text)
	if e164 == "":
		_status.text = "Enter a US phone number (10 digits)."
		return
	_busy(true, "Looking up Square customer…")
	var result: Dictionary = await AccountClient.login_or_signup(e164, _loyalty.button_pressed)
	if not result.get("ok", false):
		_busy(false, str(result.get("error", "Square login failed.")))
		return
	var created := bool(result.get("created", false))
	NoticeService.info("Account created on Square." if created else "Signed in.")
	_go_home()


func _on_skip() -> void:
	AccountClient.skip_as_guest()
	_go_home()


func _busy(on: bool, message: String) -> void:
	_continue.disabled = on
	_skip.disabled = on
	_phone.editable = not on
	_status.text = message


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
