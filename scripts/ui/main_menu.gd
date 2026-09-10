extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

@onready var _logo: TextureRect = $Safe/VBox/Logo
@onready var _subtitle: Label = $Safe/VBox/Subtitle
@onready var _order: Button = $Safe/VBox/OrderButton
@onready var _tip: Button = $Safe/VBox/TipButton
@onready var _explore: Button = $Safe/VBox/ExploreButton
@onready var _gear: Button = $Safe/VBox/Footer/Gear
@onready var _settings: PanelContainer = $Settings
@onready var _url_edit: LineEdit = $Settings/Pad/VBox/Url
@onready var _mode_edit: OptionButton = $Settings/Pad/VBox/Mode
@onready var _name_edit: LineEdit = $Settings/Pad/VBox/PlayerName


func _ready() -> void:
	BakeryTheme.apply(self)
	_gear.theme_type_variation = "SecondaryButton"
	$Settings/Pad/VBox/Close.theme_type_variation = "SecondaryButton"
	_logo.texture = load("res://assets/branding/sunshine-logo-girl.jpg")
	_subtitle.text = "%s\n%s" % [AppConfig.bakery_name, AppConfig.bakery_address]
	_order.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/order/order.tscn"))
	_tip.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/tip_ad/tip_ad.tscn"))
	_explore.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/explore/explore_3d.tscn"))
	_gear.pressed.connect(_toggle_settings)
	$Settings/Pad/VBox/Save.pressed.connect(_save_settings)
	$Settings/Pad/VBox/Close.pressed.connect(func(): _settings.visible = false)
	_url_edit.text = AppConfig.order_base_url
	_name_edit.text = GameSave.player_name
	_mode_edit.clear()
	for mode in ["mock", "test", "live"]:
		_mode_edit.add_item(mode)
		if mode == AppConfig.ad_mode:
			_mode_edit.select(_mode_edit.item_count - 1)
	_settings.visible = false


func _toggle_settings() -> void:
	_settings.visible = not _settings.visible


func _save_settings() -> void:
	AppConfig.save_user_overrides({
		"order_base_url": _url_edit.text.strip_edges(),
		"ad_mode": _mode_edit.get_item_text(_mode_edit.selected),
	})
	GameSave.set_player_name(_name_edit.text)
	_settings.visible = false
	NoticeService.info("Saved on this device. Env vars still win if set.")
