extends Node3D

const ExploreHUDScript := preload("res://scripts/explore/explore_hud.gd")
const RemoteBakerScript := preload("res://scripts/explore/remote_baker.gd")
const CookieProjectileScript := preload("res://scripts/explore/cookie_projectile.gd")

@onready var _player: PlayerExplorer = $Player
@onready var _world: BakeryWorld = $World
@onready var _hud: ExploreHUD = $HUD

var _remotes: Dictionary = {}


func _ready() -> void:
	if OS.get_name() == "iOS":
		## Stick, look, and toss each own one ScreenTouch index (same as Android
		## 0.1.76). Keep mouse emulation so menu buttons still receive taps.
		## Do not turn it off: iOS would then drop Control clicks.
		Input.emulate_mouse_from_touch = true
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
		if pad.has_signal("looking_changed"):
			pad.looking_changed.connect(_player.set_looking)
	if _hud.has_signal("toss_requested"):
		_hud.toss_requested.connect(func(): _player.toss_cookie())
	if _hud.has_signal("customize_requested"):
		_hud.customize_requested.connect(_open_customize)
	if _hud.has_signal("chat_submitted"):
		_hud.chat_submitted.connect(_on_chat)
	ExploreNet.room_changed.connect(_hud.set_room_status)
	ExploreNet.remote_updated.connect(_sync_remotes)
	ExploreNet.throw_received.connect(_on_net_throw)
	ExploreNet.impact_received.connect(_on_net_impact)
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
	if ExploreNet.impact_received.is_connected(_on_net_impact):
		ExploreNet.impact_received.disconnect(_on_net_impact)
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
		var baker: Node3D = _remotes.get(nid) as Node3D
		if baker == null or not is_instance_valid(baker):
			var spawned: Node3D = RemoteBakerScript.new()
			add_child(spawned)
			if spawned.has_method("setup"):
				spawned.call("setup", row)
			_remotes[nid] = spawned
		elif baker.has_method("apply_row"):
			baker.call("apply_row", row)
	var drop: Array = []
	for nid in _remotes.keys():
		if not seen.has(nid):
			drop.append(nid)
	for nid in drop:
		var gone: Node = _remotes[nid]
		_remotes.erase(nid)
		if gone and is_instance_valid(gone):
			gone.queue_free()
	_hud.set_room_status()


func _on_net_throw(payload: Dictionary) -> void:
	if str(payload.get("net_id", "")) == ExploreNet.net_id and ExploreNet.net_id != "":
		return
	var origin := _throw_origin(payload)
	var baker: Node3D = _remotes.get(str(payload.get("net_id", ""))) as Node3D
	if baker:
		if baker.has_method("play_throw"):
			baker.call("play_throw", true)
		if baker.has_method("hand_position"):
			origin = baker.call("hand_position")
	var proj_id := str(payload.get("proj_id", ""))
	if ExploreNet.saw_impact(proj_id):
		return
	var cookie := CookieProjectileScript.new()
	cookie.proj_id = proj_id
	cookie.owner_net_id = str(payload.get("net_id", ""))
	cookie.hits_local = true
	cookie.grace = 0.0
	add_child(cookie)
	cookie.global_position = origin
	cookie.velocity = _throw_velocity(payload)
	if not cookie.impacted.is_connected(_on_cookie_impact):
		cookie.impacted.connect(_on_cookie_impact)
	cookie.arm_from_net()


func _throw_origin(payload: Dictionary) -> Vector3:
	var nested: Variant = payload.get("origin")
	var ox := float(payload.get("ox", 0.0))
	var oy := float(payload.get("oy", 0.8))
	var oz := float(payload.get("oz", 11.0))
	if nested is Dictionary:
		ox = float(nested.get("x", ox))
		oy = float(nested.get("y", oy))
		oz = float(nested.get("z", oz))
	return Vector3(ox, oy, oz)


func _throw_velocity(payload: Dictionary) -> Vector3:
	var nested: Variant = payload.get("dir")
	var dx := float(payload.get("dx", 0.0))
	var dy := float(payload.get("dy", 0.08))
	var dz := float(payload.get("dz", -12.0))
	if nested is Dictionary:
		dx = float(nested.get("x", dx))
		dy = float(nested.get("y", dy))
		dz = float(nested.get("z", dz))
	var vel := Vector3(dx, dy, dz)
	if vel.length() < 0.2:
		vel = Vector3(0.0, 0.08, -12.0)
	elif vel.length() < 4.0:
		vel = vel.normalized() * 12.0
	return vel


func _on_cookie_impact(at: Vector3, id: String, who: String = "") -> void:
	ExploreNet.send_impact(at, id, who)


func _on_net_impact(payload: Dictionary) -> void:
	var proj_id := str(payload.get("proj_id", ""))
	var hit_id := str(payload.get("hit_net_id", ""))
	var at := Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.2)),
		float(payload.get("z", 11.0))
	)
	if hit_id == "" and _player and _player.global_position.distance_to(at) <= 2.4:
		hit_id = ExploreNet.net_id
	var burst := false
	for node in get_tree().get_nodes_in_group("cookie_projectile"):
		if str(node.get("proj_id")) == proj_id and node.has_method("burst_at"):
			node.call("burst_at", at, hit_id)
			burst = true
			break
	if not burst:
		var crumbs := CookieProjectileScript.new()
		add_child(crumbs)
		crumbs.proj_id = proj_id
		crumbs.hit_net_id = hit_id
		crumbs.global_position = at
		crumbs.burst_at(at, hit_id)
	_apply_hit_feel(hit_id, at)


func _apply_hit_feel(hit_id: String, at: Vector3) -> void:
	if _player and _player.has_method("apply_knockback"):
		var mine := hit_id != "" and hit_id == ExploreNet.net_id
		var near := _player.global_position.distance_to(at) <= 2.4
		if mine or (hit_id == "" and near):
			if _player.last_hit_msec == 0 or Time.get_ticks_msec() - _player.last_hit_msec > 160:
				_player.apply_knockback(at, 14.0)
			return
	if hit_id == "":
		return
	var baker: Node3D = _remotes.get(hit_id) as Node3D
	if baker and baker.has_method("apply_knockback"):
		if int(baker.get("last_hit_msec")) == 0 or Time.get_ticks_msec() - int(baker.get("last_hit_msec")) > 160:
			baker.call("apply_knockback", at, 14.0)
