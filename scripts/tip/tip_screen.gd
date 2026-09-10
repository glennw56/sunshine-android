extends Control

@onready var _total: Label = $Safe/VBox/Total
@onready var _mode: Label = $Safe/VBox/Mode
@onready var _play: Button = $Safe/VBox/Play
@onready var _back: Button = $Safe/VBox/Header/Back


func _ready() -> void:
	_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
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
