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
	# Right-half drag to look on touch devices.
	_hud.get_node("Root/LookCatch").gui_input.connect(_on_look_gui)


func _on_look_gui(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_player.apply_touch_look(event.relative)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_player.apply_touch_look(event.relative)
