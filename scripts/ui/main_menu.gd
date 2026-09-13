extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const VoxelMenuWorld := preload("res://scripts/ui/voxel_menu_world.gd")

@onready var _logo: TextureRect = $Safe/VBox/Hero/Pad/Col/Logo
@onready var _title: Label = $Safe/VBox/Hero/Pad/Col/Title
@onready var _subtitle: Label = $Safe/VBox/Hero/Pad/Col/Subtitle
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
	_mount_voxel_backdrop()
	_style_block_chrome()
	_gear.theme_type_variation = "SecondaryButton"
	$Settings/Pad/VBox/Close.theme_type_variation = "SecondaryButton"
	_logo.texture = load("res://assets/branding/sunshine-logo-girl.jpg")
	_title.text = AppConfig.bakery_name
	_subtitle.text = "Irondale, Alabama"
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


func _mount_voxel_backdrop() -> void:
	var host := SubViewportContainer.new()
	host.name = "VoxelBackdrop"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var world := Node3D.new()
	world.set_script(VoxelMenuWorld)
	vp.add_child(world)
	host.add_child(vp)
	add_child(host)
	move_child(host, 0)
	var bg := get_node_or_null("Bg") as ColorRect
	if bg:
		bg.color = Color(1, 0.965, 0.918, 0.28)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wash := get_node_or_null("Wash") as ColorRect
	if wash:
		wash.color = Color(0.91, 0.706, 0.722, 0.38)
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_block_chrome() -> void:
	var hero := get_node_or_null("Safe/VBox/Hero") as PanelContainer
	if hero:
		hero.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_subtitle.add_theme_font_size_override("font_size", 16)
	_order.custom_minimum_size = Vector2(0, 76)
	_order.add_theme_font_size_override("font_size", 22)
	_tip.theme_type_variation = "SecondaryButton"
	_explore.theme_type_variation = "SecondaryButton"
	for btn in [_tip, _explore]:
		btn.custom_minimum_size = Vector2(0, 58)
		btn.add_theme_font_size_override("font_size", 18)
	var hint := get_node_or_null("Safe/VBox/Hint") as Label
	if hint:
		hint.visible = false
	var copy := get_node_or_null("Safe/VBox/Footer/Copy") as Label
	if copy:
		copy.visible = false
	if _logo:
		_logo.custom_minimum_size = Vector2(132, 132)
	_settings.add_theme_stylebox_override("panel", BakeryTheme.card_style())


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
