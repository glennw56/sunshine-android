extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

@onready var _card: PanelContainer = $Safe/Stack/Center/Card
@onready var _logo_frame: PanelContainer = $Safe/Stack/Center/Card/Pad/Col/LogoWrap/LogoFrame
@onready var _title: Label = $Safe/Stack/Center/Card/Pad/Col/Title
@onready var _pitch: Label = $Safe/Stack/Center/Card/Pad/Col/Pitch
@onready var _play: Button = $Safe/Stack/Center/Card/Pad/Col/Play
@onready var _back: Button = $Safe/Stack/Header/Back
@onready var _total: Label = $Safe/Stack/Center/Card/Pad/Col/Total
@onready var _mode: Label = $Safe/Stack/Center/Card/Pad/Col/Mode


func _ready() -> void:
	BakeryTheme.apply(self)
	_style_sheet()
	_fit_card()
	resized.connect(_fit_card)
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_play.pressed.connect(_on_play)
	AdTipService.tip_credited.connect(func(_n: int): _refresh())
	_refresh()


func _fit_card() -> void:
	var max_w := maxf(300.0, size.x - 80.0)
	_card.custom_minimum_size.x = minf(520.0, max_w)


func _style_sheet() -> void:
	_card.add_theme_stylebox_override("panel", _sheet_style())
	_logo_frame.add_theme_stylebox_override("panel", _logo_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_HERO)
	_pitch.add_theme_color_override("font_color", BakeryTheme.INK)
	_pitch.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back.theme_type_variation = "SecondaryButton"
	_back.custom_minimum_size = Vector2(120, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_play.theme_type_variation = "GoldButton"
	_play.custom_minimum_size = Vector2(0, 80)
	_play.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	var not_you := get_node_or_null("Safe/Stack/Center/Card/Pad/Col/NotYou") as Label
	if not_you:
		not_you.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_mode.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_total.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)


func _sheet_style() -> StyleBoxFlat:
	var s := BakeryTheme.card_style()
	s.set_corner_radius_all(28)
	s.content_margin_left = 28
	s.content_margin_top = 28
	s.content_margin_right = 28
	s.content_margin_bottom = 28
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 10)
	s.border_color = Color(BakeryTheme.BLUSH, 0.9)
	s.set_border_width_all(2)
	return s


func _logo_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("fffaf3")
	s.border_color = BakeryTheme.BLUSH
	s.set_border_width_all(3)
	s.set_corner_radius_all(66)
	s.content_margin_left = 8
	s.content_margin_top = 8
	s.content_margin_right = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0.42, 0.18, 0.24, 0.12)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _refresh() -> void:
	_mode.visible = false
	_mode.text = ""
	_total.visible = false
	_total.text = ""
	var not_you := get_node_or_null("Safe/Stack/Center/Card/Pad/Col/NotYou") as CanvasItem
	if not_you:
		not_you.visible = false


func _on_play() -> void:
	_play.disabled = true
	var result := await AdTipService.play_rewarded()
	_play.disabled = false
	if not result.get("ok", false):
		if result.get("skipped", false):
			NoticeService.info("Tip skipped.")
		else:
			NoticeService.info("Could not send a tip.")
	_refresh()
