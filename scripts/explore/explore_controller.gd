extends Node3D

@onready var _player: PlayerExplorer = $Player
@onready var _world: BakeryWorld = $World
@onready var _hud: ExploreHUD = $HUD


func _ready() -> void:
	_player.collision_layer = 2
	_player.collision_mask = 1
	_world.setup(_player)
	_hud.add_to_group("explore_hud")
	_hud.leave_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_hud.joystick().vector_changed.connect(func(v: Vector2): _player.joy_vector = v)
	var pad := _hud.look_pad()
	if pad:
		pad.look_delta.connect(_player.apply_touch_look)
	if GameSave.is_fresh_batch_active():
		NoticeService.info(
			"Fresh Batch is on (9–11 America/Chicago). Extra croissants & drinks indoors and out. First 3 finds: 2× stamps."
		)
