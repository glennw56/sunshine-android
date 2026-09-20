extends Node3D

const ExploreHUDScript := preload("res://scripts/explore/explore_hud.gd")
const RemoteBakerScript := preload("res://scripts/explore/remote_baker.gd")
const CookieProjectileScript := preload("res://scripts/explore/cookie_projectile.gd")

@onready var _player: PlayerExplorer = $Player
@onready var _world: BakeryWorld = $World
@onready var _hud: ExploreHUD = $HUD

var _remotes: Dictionary = {}


func _ready() -> void:
	_player.collision_layer = 2
	_player.collision_mask = 1
	_world.setup(_player)
	AppConfig.warmup_ui_scenes()
	_hud.add_to_group("explore_hud")
	_hud.leave_requested.connect(_leave_to_menu)
	var joy = _hud.joystick()
	if joy:
		joy.vector_changed.connect(func(v: Vector2): _player.joy_vector = v)
	var pad = _hud.look_pad()
	if pad:
		pad.look_delta.connect(_player.apply_touch_look)
	if _hud.has_signal("toss_requested"):
		_hud.toss_requested.connect(func(): _player.toss_cookie())
	if _hud.has_signal("customize_requested"):
		_hud.customize_requested.connect(_open_customize)
	if _hud.has_signal("chat_submitted"):
		_hud.chat_submitted.connect(_on_chat)
	ExploreNet.room_changed.connect(_hud.set_room_status)
	ExploreNet.remote_updated.connect(_sync_remotes)
	ExploreNet.throw_received.connect(_on_net_throw)
	ExploreNet.chat_received.connect(_hud.push_chat)
	_player.call_deferred("snap_to_ground")
	ExploreNet.enter_patio(_player)
	_hud.set_room_status()


func _exit_tree() -> void:
	if is_instance_valid(_hud) and ExploreNet.room_changed.is_connected(_hud.set_room_status):
		ExploreNet.room_changed.disconnect(_hud.set_room_status)
	if ExploreNet.remote_updated.is_connected(_sync_remotes):
		ExploreNet.remote_updated.disconnect(_sync_remotes)
	if ExploreNet.throw_received.is_connected(_on_net_throw):
		ExploreNet.throw_received.disconnect(_on_net_throw)
	if is_instance_valid(_hud) and ExploreNet.chat_received.is_connected(_hud.push_chat):
		ExploreNet.chat_received.disconnect(_hud.push_chat)
	ExploreNet.leave_patio()


func _open_customize() -> void:
	if not ProfileStore.can_customize():
		AppConfig.go("res://scenes/account/login.tscn")
		return
	AppConfig.go("res://scenes/explore/customize.tscn")


func _leave_to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ExploreNet.leave_patio()
	AppConfig.go("res://scenes/main_menu.tscn")


func _on_chat(body: String) -> void:
	ExploreNet.send_chat(body)


func _sync_remotes() -> void:
	var seen: Dictionary = {}
	for nid in ExploreNet.remotes.keys():
		seen[nid] = true
		var row: Dictionary = ExploreNet.remotes[nid]
		var baker: RemoteBaker = _remotes.get(nid)
		if baker == null or not is_instance_valid(baker):
			baker = RemoteBakerScript.new()
			add_child(baker)
			baker.setup(row)
			_remotes[nid] = baker
		else:
			baker.apply_row(row)
	var drop: Array = []
	for nid in _remotes.keys():
		if not seen.has(nid):
			drop.append(nid)
	for nid in drop:
		var baker: RemoteBaker = _remotes[nid]
		_remotes.erase(nid)
		if baker and is_instance_valid(baker):
			baker.queue_free()
	_hud.set_room_status()


func _on_net_throw(payload: Dictionary) -> void:
	if str(payload.get("net_id", "")) == ExploreNet.net_id:
		return
	var cookie := CookieProjectileScript.new()
	add_child(cookie)
	cookie.proj_id = str(payload.get("proj_id", ""))
	cookie.global_position = Vector3(
		float(payload.get("ox", 0.0)),
		float(payload.get("oy", 0.8)),
		float(payload.get("oz", 11.0))
	)
	cookie.velocity = Vector3(
		float(payload.get("dx", 0.0)),
		float(payload.get("dy", 2.0)),
		float(payload.get("dz", -12.0))
	)
