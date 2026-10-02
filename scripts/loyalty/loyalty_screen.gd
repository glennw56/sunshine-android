extends Control
## Square Loyalty. Balance is GameSave.loyalty_points from login / AccountClient.refresh().
## Explore pickup counters stay off this screen.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
const AvatarPreviewScript := preload("res://scripts/explore/avatar_preview.gd")

const JOIN_LINE := "Sign in / join loyalty to earn points"
const HOW_IT_WORKS := (
	"Earn 1 point for every $1.00 you spend, before tax.\n\n"
	+ "100 points: a free Fruit Tea.\n\n"
	+ "200 points: $10.00 off the entire sale.\n\n"
	+ "Join from the sign-in screen. Keep “Join Sunshine’s Bakery loyalty / save your orders” checked."
)

var _preview: VBoxContainer
var _phone: Label

@onready var _points: Label = $Safe/Col/Scroll/Card/Pad/Col/Points
@onready var _track: LoyaltyTrack = $Safe/Col/Scroll/Card/Pad/Col/Track
@onready var _how_title: Label = $Safe/Col/Scroll/Card/Pad/Col/HowTitle
@onready var _how: Label = $Safe/Col/Scroll/Card/Pad/Col/HowBody
@onready var _join: Button = $Safe/Col/Scroll/Card/Pad/Col/Join
@onready var _back: Button = $Safe/Col/Header/Back
@onready var _title: Label = $Safe/Col/Header/Title


func _ready() -> void:
	BakeryTheme.apply(self)
	_style()
	_mount_avatar()
	_refresh_avatar()
	_paint()
	if not ProfileStore.avatar_changed.is_connected(_on_avatar_changed):
		ProfileStore.avatar_changed.connect(_on_avatar_changed)
	if AccountClient.is_logged_in():
		_refresh_balance()


func _style() -> void:
	var card := $Safe/Col/Scroll/Card as PanelContainer
	card.add_theme_stylebox_override("panel", _card_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_HERO)
	_points.add_theme_color_override("font_color", BakeryTheme.WINE)
	_points.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_how_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_how_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_how.add_theme_color_override("font_color", BakeryTheme.INK)
	_how.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_how.text = HOW_IT_WORKS
	_back.theme_type_variation = "SecondaryButton"
	_back.custom_minimum_size = Vector2(128, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_join.custom_minimum_size = Vector2(0, 72)
	_join.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_join.text = "Sign in / join loyalty"
	if not _join.pressed.is_connected(_on_join):
		_join.pressed.connect(_on_join)


func _card_style() -> StyleBoxFlat:
	var style := BakeryTheme.card_style()
	style.set_corner_radius_all(28)
	style.border_color = Color(BakeryTheme.BLUSH, 0.95)
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _mount_avatar() -> void:
	## Same portrait node the player maker uses. Explore's baker is this AvatarBody.
	var host := $Safe/Col/Scroll/Card/Pad/Col/PreviewHost as VBoxContainer
	_preview = AvatarPreviewScript.new()
	_preview.name = "AvatarPreview"
	host.add_child(_preview)
	var phone := Label.new()
	phone.name = "Phone"
	phone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phone.autowrap_mode = TextServer.AUTOWRAP_OFF
	phone.add_theme_color_override("font_color", BakeryTheme.WINE)
	phone.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	phone.visible = false
	host.add_child(phone)
	_phone = phone


func _recipe() -> Dictionary:
	var raw: Dictionary = GameSave.avatar_recipe
	if raw.is_empty():
		raw = ProfileStore.current_avatar()
	return CosContracts.sanitize_avatar(raw)


func _refresh_avatar() -> void:
	if _preview and _preview.has_method("show_recipe"):
		_preview.call("show_recipe", _recipe())


func _on_avatar_changed(recipe_now: Dictionary) -> void:
	if _preview and _preview.has_method("show_recipe") and not recipe_now.is_empty():
		_preview.call("show_recipe", recipe_now)
	else:
		_refresh_avatar()


func _paint() -> void:
	var enrolled := GameSave.shows_loyalty_balance()
	var phone := ""
	if AccountClient.is_logged_in():
		phone = AccountClient.format_phone(GameSave.square_phone)
	if _phone:
		_phone.text = phone
		_phone.visible = phone != ""
	if enrolled:
		var total := GameSave.loyalty_points
		_points.text = "1 point" if total == 1 else "%d points" % total
		_join.visible = false
	else:
		_points.text = JOIN_LINE
		_join.visible = true
	if _track:
		_track.set_balance(GameSave.loyalty_points if enrolled else 0, enrolled)


func _refresh_balance() -> void:
	await AccountClient.refresh()
	if is_inside_tree():
		_paint()


func _on_join() -> void:
	AccountClient.logout()
	AppConfig.go("res://scenes/account/login.tscn")
