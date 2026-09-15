extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

@onready var _total: Label = $Safe/VBox/Total
@onready var _mode: Label = $Safe/VBox/Mode
@onready var _play: Button = $Safe/VBox/Play
@onready var _back: Button = $Safe/VBox/Header/Back


func _ready() -> void:
	BakeryTheme.apply(self)
	_back.theme_type_variation = "SecondaryButton"
	_back.custom_minimum_size = Vector2(120, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_play.theme_type_variation = "GoldButton"
	_play.custom_minimum_size = Vector2(0, 76)
	_play.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	var header_title := get_node_or_null("Safe/VBox/Header/Title") as Label
	if header_title:
		header_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	var pitch := get_node_or_null("Safe/VBox/Pitch") as Label
	if pitch:
		pitch.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	var not_you := get_node_or_null("Safe/VBox/NotYou") as Label
	if not_you:
		not_you.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_mode.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_total.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_play.pressed.connect(_on_play)
	AdTipService.tip_credited.connect(func(_n: int): _refresh())
	_refresh()


func _refresh() -> void:
	_mode.text = AdTipService.describe() + "\nApp id (test default): %s" % AppConfig.admob_app_id
	_total.text = "Staff jar this week: %d FREE TIP%s\nAll-time: %d" % [
		GameSave.staff_tips_week,
		"" if GameSave.staff_tips_week == 1 else "S",
		GameSave.staff_tips,
	]


func _on_play() -> void:
	_play.disabled = true
	var result := await AdTipService.play_rewarded()
	_play.disabled = false
	if not result.get("ok", false):
		NoticeService.info(str(result.get("error", "No tip credited.")))
	_refresh()
