extends Node3D
## Slingshot putt. Touch anywhere and drag back, opposite the shot. A dotted
## line shows where the ball will go. Release putts. Dragging back onto the
## ball cancels. The camera stays put while you aim, follows the ball, then
## settles behind it, leaning toward the cup with the ball low in the frame.
## Pinch zooms. A damped ray keeps the view in front of walls and props
## without riding the rail tops. View hole orbits the hole. One hole at a time.

const Catalog := preload("res://scripts/minigolf/catalog.gd")
const Access := preload("res://scripts/minigolf/access.gd")
const Scores := preload("res://scripts/minigolf/scores.gd")
const HoleScript := preload("res://scripts/minigolf/hole.gd")
const BallScript := preload("res://scripts/minigolf/ball.gd")
const Bot := preload("res://scripts/minigolf/bot.gd")

const FLY := 0
const AIM := 1
const ROLL := 2
const BANNER := 3
const CARD := 4
const DONE := 5
const VIEW := 6
# About 1.9x the old 2.45 m lens, from a steeper pitch, so a portrait phone
# shows the lane and the cup. Pinch stays inside the near and far stops.
# A pull-in never sits on the rail tops, and it does not dive into the ball.
const CAM_NEAR := 2.6
const CAM_FAR := 7.4
const CAM_DEFAULT := 4.7
const CAM_PITCH := 52.0
const CAM_MIN_DIST := 1.7
const CAM_LAYER := 1 << 20
const VIEW_NEAR := 3.4
const VIEW_FAR := 14.0

signal round_finished(results: Array)

@onready var _cam: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD

var _state := FLY
var _hole: Node3D
var _ball: RigidBody3D
var _hole_index := 1
var _strokes := 0
var _scores: Array = []
var _stars: Array = []
var _holed: Array = []
var _oob: Array = []
var _yaw := 0.0
var _aim := Vector3(0, 0, -1)
var _power := 0.0
var _dragging := false
var _drag_from := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _pointer_down := false
var _drag_right := Vector3.RIGHT
var _drag_forward := Vector3(0, 0, -1)
var _cancelled := false
var _look_mode := false
var _yaw_target := 0.0
var _camera_hold := false
var _touch := false
var _touch_phase := 0
var _touch_step := 0
var _touch_from := Vector2.ZERO
var _touch_to := Vector2.ZERO
var _touch_hold := false
var _touch_busy := false
var _gesture_lock := false
var _cam_locked := false
var _locked_xform := Transform3D.IDENTITY
var _wall_mode := false
var _wall_done := false
var _wall_shot := false
var _wall_probe := false
var _wall_peak := -999.0
var _wall_failures := 0
var _touch_wait := 0.45
var _cancel_streak := 0
var _planned_aim := Vector3(0, 0, -1)
var _planned_power := 0.0
var _aim_dots: Array[MeshInstance3D] = []
var _fly_t := 0.0
var _rest_t := 0.0
var _banner_t := 0.0
var _flash_t := 0.0
var _last_rest := Vector3.ZERO
var _bot := false
var _bot_bias := 0.0
var _shot_oob := false
var _bot_wp := 0
var _bot_dist := 999.0
var _bot_wait := 0.0
var _bot_stage := 0
var _bot_ready_wait := 0.0
var _card_hold := 0.0
var _card_final := false
var _cam_user_dist := CAM_DEFAULT
var _cam_dist := CAM_DEFAULT
var _cam_target := CAM_DEFAULT
var _cam_lift := 0.0
var _spawn_at := Vector3.ZERO
var _spawn_kind := ""
var _spawn_frames := 0
var _pinch_span := 0.0
var _pointers: Dictionary = {}
var _view_yaw := 0.2
var _view_pitch := 46.0
var _view_dist := 9.0
var _view_focus := Vector3.ZERO
var _view_press := Vector2.ZERO
var _view_moved := false
var _decor: Array[MeshInstance3D] = []
var _decor_alpha: Dictionary = {}


func _ready() -> void:
	add_to_group("minigolf_course")
	_bot = OS.get_environment("MINIGOLF_BOT") == "1"
	_touch = OS.get_environment("MINIGOLF_TOUCH") == "1"
	_wall_mode = OS.get_environment("MINIGOLF_WALL") == "1"
	if _touch:
		Input.emulate_mouse_from_touch = false
		Input.emulate_touch_from_mouse = false
	_block_walk_controls()
	if not _bot and not _touch and AppConfig and not AppConfig.test_world:
		AppConfig.go("res://scenes/explore/explore_3d.tscn")
		return
	if not _bot and not _touch and not Access.is_unlocked():
		AppConfig.go(AppConfig.explore_scene_path())
		return
	_build_sky()
	_aim_mesh()
	_blank_scores()
	_ball = BallScript.new()
	add_child(_ball)
	_connect_hud()
	# A saved hole is never restored. Exit, a later gate entry, and a process
	# restart all begin at hole 1. The 24h unlock is a different key.
	Access.clear_round()
	var only := OS.get_environment("MINIGOLF_ONLY")
	if (_bot or _touch) and only != "":
		_hole_index = clampi(int(only), 1, 18)
	_begin_hole(_hole_index)
	print("ROUND start hole %d strokes %d unlocked %s" % [_hole_index, _strokes, Access.is_unlocked()])
	_fit_camera()
	# CCD on the ball plus solid boxes stop tunneling. Keep the 60 Hz step
	# the holes were tuned at, and don't drop physics steps on a long frame.
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	if _bot or _touch:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	_disconnect_hud()
	Access.clear_round()


func _blank_scores() -> void:
	_scores.clear()
	_stars.clear()
	_holed.clear()
	_oob.clear()
	for _i in Catalog.hole_count():
		_scores.append(0)
		_stars.append(0)
		_holed.append(false)
		_oob.append(0)


func _connect_hud() -> void:
	if _hud == null:
		return
	if _hud.has_signal("view_requested"):
		_bind(_hud.view_requested, _on_view)
		_bind(_hud.exit_requested, _on_exit)
		_bind(_hud.continue_requested, _on_continue)
	if _hud.has_signal("play_again_requested"):
		_bind(_hud.play_again_requested, _on_play_again)
	if _hud.has_signal("look_toggled"):
		_bind(_hud.look_toggled, _on_look)


func _disconnect_hud() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	if _hud.has_signal("view_requested"):
		_unbind(_hud.view_requested, _on_view)
		_unbind(_hud.exit_requested, _on_exit)
		_unbind(_hud.continue_requested, _on_continue)
	if _hud.has_signal("play_again_requested"):
		_unbind(_hud.play_again_requested, _on_play_again)
	if _hud.has_signal("look_toggled"):
		_unbind(_hud.look_toggled, _on_look)


func _bind(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)


func _unbind(sig: Signal, cb: Callable) -> void:
	if sig.is_connected(cb):
		sig.disconnect(cb)


func _build_sky() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7eb8e8")
	sky_mat.sky_horizon_color = Color("f6d5c6")
	sky_mat.ground_horizon_color = Color("e8b4b8")
	sky_mat.ground_bottom_color = Color("c9a898")
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	we.background_mode = Environment.BG_SKY
	we.sky = sky
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color.WHITE
	we.ambient_light_energy = 1.0
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.fog_enabled = true
	we.fog_light_color = Color("f7e6da")
	we.fog_density = 0.012
	we.fog_aerial_perspective = 0.15
	we.fog_mode = Environment.FOG_MODE_DEPTH
	we.fog_depth_begin = 14.0
	we.fog_depth_end = 42.0
	we.ssao_enabled = false
	we.glow_enabled = false
	env.environment = we
	add_child(env)


func _aim_mesh() -> void:
	var root := Node3D.new()
	root.name = "AimDots"
	add_child(root)
	var mesh := SphereMesh.new()
	mesh.radius = 0.034
	mesh.height = 0.068
	mesh.radial_segments = 16
	mesh.rings = 8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fffaf4")
	mesh.material = mat
	for _i in 16:
		var dot := MeshInstance3D.new()
		dot.mesh = mesh
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		dot.scale = Vector3.ONE
		root.add_child(dot)
		_aim_dots.append(dot)


func _begin_hole(index: int) -> void:
	_hole_index = index
	_strokes = 0
	_bot_wp = 0
	_bot_bias = 0.0
	_bot_stage = 0
	_bot_ready_wait = 0.0
	_bot_dist = 999.0
	_power = 0.0
	_dragging = false
	_pointer_down = false
	_cancelled = false
	_touch_busy = false
	_touch_phase = 0
	_touch_wait = 0.0
	_wall_done = false
	_wall_shot = false
	_wall_probe = false
	_wall_peak = -999.0
	_cancel_streak = 0
	_cam_locked = false
	_yaw = 0.0
	_yaw_target = 0.0
	_aim = Vector3(0, 0, -1)
	_decor.clear()
	_decor_alpha.clear()
	if _hole and is_instance_valid(_hole):
		var old := _hole
		_hole = null
		old.free()
	_hole = HoleScript.new()
	add_child(_hole)
	_hole.call("setup", index)
	_spawn_ball(_hole.call("tee_pos"), "tee")
	_hole.call("arm", _ball)
	# Hole 4's loop and hole 18's climb start down at the green, so a low
	# rail clamp stops them. Hole 7's side rail throws a full putt over
	# the back unless the clamp stays on up the face.
	var clamp_y := 0.45
	if index == 4 or index == 18:
		# Both climbs start down at the green. The clamp stops them.
		clamp_y = 0.0
	elif index == 7:
		clamp_y = 1.30
	_ball.set("rail_clamp_y", clamp_y)
	_collect_decor()
	_cam_target = _cam_user_dist
	_snap_camera()
	print("TEE hole %d ball %s" % [index, _last_rest])
	_state = FLY
	_fly_t = 0.0
	_hud.call("hide_banner")
	_hud.call("hide_scorecard")
	_hud.call("flash", "")
	_hud.call("set_status", index, Catalog.par(index), 0)
	print("HUD hole %d par %d strokes 0" % [index, Catalog.par(index)])
	print("CAM hole %d dist %.2f user %.2f lift %.2f" % [_hole_index, _cam_dist, _cam_user_dist, _cam_lift])
	if _bot or _touch:
		_fly_t = 2.0
		if _bot and (index == 1 or index == 4 or index == 10 or index == 14 or index == 18):
			_queue_shot("hole_%02d" % index)


func _spawn_ball(at: Vector3, kind: String) -> void:
	_last_rest = at
	_spawn_at = at
	_spawn_kind = kind
	# A new hole's collision flush can copy the old pose back for a tick.
	# Re-apply across the next physics frames, then log where it actually sits.
	_spawn_frames = 3
	_ball.call("park", at)


func _hold_spawn() -> void:
	if _spawn_frames <= 0 or _ball == null or _spawn_kind == "":
		return
	var launched := not bool(_ball.freeze) or bool(_ball.get("_launch_pending"))
	if not launched and _ball.global_position.distance_to(_spawn_at) > 0.03:
		_ball.call("park", _spawn_at)
	var support := _ball_support()
	_spawn_frames -= 1
	# Log once the felt is in the physics space. A putt can start on the
	# next idle frame, so do not wait past the first real surface.
	if support != "none" or _spawn_frames == 0 or launched:
		_log_spawn(support)
		_spawn_kind = ""
		_spawn_frames = 0


func _ball_support() -> String:
	var space := get_world_3d().direct_space_state
	if space == null or _ball == null:
		return "none"
	var origin := _ball.global_position + Vector3(0, 0.2, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, -0.5, 0))
	query.collision_mask = 1
	query.exclude = [_ball.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return "none"
	var col: Object = hit.collider
	return str(col.name) if col is Node else "?"


func _log_spawn(support: String) -> void:
	var pos: Vector3 = _ball.global_position
	print("SPAWN hole %d %s ball %s support %s" % [_hole_index, _spawn_kind, pos, support])
	var on_felt := support.begins_with("Green") or support.begins_with("Bowl") or support.begins_with("Chute")
	var hole10_bad := _hole_index == 10 and (absf(pos.x) > 0.08 or pos.z < -2.2 or support.begins_with("Conveyor"))
	if _spawn_kind == "tee" and (not on_felt or hole10_bad):
		print("SPAWN BAD hole %d %s ball %s support %s" % [_hole_index, _spawn_kind, pos, support])


func _physics_process(delta: float) -> void:
	if _hole == null or _ball == null:
		return
	_hold_spawn()
	if _state == ROLL and _ball:
		_wall_peak = maxf(_wall_peak, _ball.global_position.y)
	if _state == ROLL:
		var event := str(_hole.call("poll"))
		var settled := false
		if event == "":
			if bool(_ball.call("is_slow")):
				_rest_t += delta
			else:
				_rest_t = 0.0
			settled = _rest_t > 0.32 or _roll_time_exceeded()
		if _wall_probe and (event != "" or settled):
			_finish_wall_probe()
			return
		if event == "cup":
			_shot_cup_drop()
			_ball.call("park", _ball.global_position)
			_finish_hole(true)
		elif event == "oob":
			_oob[_hole_index - 1] = int(_oob[_hole_index - 1]) + 1
			print("OOB hole %d count %d strokes %d" % [_hole_index, int(_oob[_hole_index - 1]), _strokes])
			_spawn_ball(_last_rest, "oob")
			_flash_t = 1.1
			_hud.call("flash", "Out of bounds")
			if _bot and not _shot_oob:
				_shot_oob = true
				_queue_shot("oob")
			_end_roll(false)
		elif settled:
			_ball.call("park", _ball.global_position)
			_end_roll(false)
	_update_camera(delta)


var _roll_started := 0


func _roll_time_exceeded() -> bool:
	return Time.get_ticks_msec() - _roll_started > 14000


func _shot_budget() -> int:
	return Catalog.par(_hole_index) + Catalog.STROKE_CAP


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_hud.call("flash", "")
	if _state == FLY:
		_fly_t += delta
		if _fly_t >= 2.0:
			_state = AIM
			_yaw_target = _yaw_toward_cup()
			_snap_camera()
	elif _state == BANNER:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_after_banner()
	elif _state == AIM and _bot:
		_bot_wait -= delta
		if _bot_wait <= 0.0:
			if bool(Bot.ready(_hole_index, _hole)) or _bot_ready_wait > 3.0:
				_bot_ready_wait = 0.0
				_bot_putt()
			else:
				_bot_ready_wait += delta
	elif _state == AIM and _touch:
		var armed := OS.get_environment("MINIGOLF_TOUCH_ARM") == "1"
		if armed and not _touch_busy and not _dragging and _touch_phase == 0:
			_touch_wait -= delta
			var ready := bool(Bot.ready(_hole_index, _hole)) or _bot_ready_wait > 3.0
			if _touch_wait <= 0.0 and (_wall_mode and not _wall_done or ready):
				_bot_ready_wait = 0.0
				_touch_wait = 0.0
				_wall_shot = _wall_mode and not _wall_done
				_start_touch_putt(false)
			elif not bool(Bot.ready(_hole_index, _hole)):
				_bot_ready_wait += delta
		_touch_pump()
	elif _state == CARD and (_bot or _touch):
		_card_hold -= delta
		if _card_hold <= 0.0 and not _card_final:
			_on_continue()
		elif _card_hold <= 0.0 and _card_final and _state == CARD:
			_state = DONE
			round_finished.emit(_results())
			Engine.time_scale = 1.0
	_aim_visual()
	_power_widget()
	_refresh_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _blocks_walk_action(event):
		get_viewport().set_input_as_handled()
		return
	_track_pointer(event)
	if _state == VIEW:
		_view_input(event)
		get_viewport().set_input_as_handled()
		return
	if _pointers.size() >= 2:
		if _dragging:
			_pointer_down = false
			_dragging = false
			_cancelled = true
			_power = 0.0
			_release_camera_lock()
		get_viewport().set_input_as_handled()
		return
	if _bot and not _touch:
		if event.is_action_pressed("ui_cancel"):
			_on_exit()
		if _state == FLY and (event is InputEventMouseButton or event is InputEventScreenTouch):
			_fly_t = 2.0
		return
	if _state == FLY and _pressed(event):
		_fly_t = 2.0
		return
	if _state != AIM:
		return
	if _pressed(event):
		if _pointer_down:
			return
		if _over_ui():
			return
		_pointer_down = true
		_dragging = true
		_cancelled = false
		_drag_from = _event_pos(event)
		_last_pointer = _drag_from
		_power = 0.0
		_capture_drag_axes()
	elif _dragging and _moved(event):
		_apply_drag(_event_pos(event))
	elif _dragging and _released(event):
		_pointer_down = false
		_dragging = false
		_release_shot()


func _pressed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _released(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false


func _moved(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or (event is InputEventScreenDrag)


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.ZERO


func _over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _apply_drag(at: Vector2) -> void:
	var rel := at - _last_pointer
	_last_pointer = at
	if _look_mode:
		_power = 0.0
		_cancelled = true
		_yaw -= rel.x / _span() * PI
		_yaw_target = _yaw
		return
	var delta := at - _drag_from
	var pulled := _drag_right * delta.x + _drag_forward * (-delta.y)
	var ball_at := _cam.unproject_position(_ball.global_position)
	if at.distance_to(ball_at) <= _cancel_radius():
		_power = 0.0
		_cancelled = true
		return
	_cancelled = false
	if pulled.length() < _deadzone():
		_power = 0.0
		return
	var shot := Vector3(-pulled.x, 0.0, -pulled.z)
	if shot.length() < 0.001:
		_power = 0.0
		return
	_aim = shot.normalized()
	_power = clampf(pulled.length() / _full_pull(), 0.0, 1.0)


func _release_shot() -> void:
	if _look_mode or _cancelled or _power < 0.015:
		if _touch and _planned_power > 0.0:
			print("TOUCH cancel hole %d power %.2f cancelled %s planned %.2f" % [_hole_index, _power, _cancelled, _planned_power])
			_planned_power = 0.0
		_power = 0.0
		_cancelled = false
		_gesture_lock = false
		_cam_locked = false
		if _wall_shot:
			_wall_shot = false
			_wall_done = true
			_wall_failures += 1
			print("WALL hole %d FAIL cancel" % _hole_index)
			return
		if _touch:
			_cancel_streak += 1
			if _cancel_streak >= 6:
				_cancel_streak = 0
				_strokes = Catalog.par(_hole_index) + Catalog.STROKE_CAP
				_finish_hole(false)
		return
	_release_camera_lock()
	if _touch:
		Engine.time_scale = 1.0
		var align := _aim.dot(_planned_aim) if _planned_aim.length() > 0.5 else 1.0
		print("TOUCH hole %d power %.2f planned %.2f align %.3f aim %s at %s" % [_hole_index, _power, _planned_power, align, _aim, _ball.global_position])
		if _wall_shot:
			_wall_probe = true
			_wall_shot = false
			_wall_peak = _ball.global_position.y
		_cancel_streak = 0
	if _hole:
		var cup_at: Vector3 = _hole.call("cup_pos")
		_bot_dist = _ball.global_position.distance_to(cup_at)
	if _strokes >= _shot_budget():
		return
	_strokes += 1
	_hud.call("set_status", _hole_index, Catalog.par(_hole_index), _strokes)
	_last_rest = _ball.global_position
	_ball.call("launch", _aim, Catalog.putt_speed(_power))
	_power = 0.0
	_rest_t = 0.0
	_roll_started = Time.get_ticks_msec()
	_state = ROLL


func _bot_putt() -> void:
	var space := get_world_3d().direct_space_state
	var cup: Vector3 = _hole.call("cup_pos")
	var plan: Dictionary = Bot.choose(_hole_index, _ball.global_position, cup, _hole, _bot_wp, _bot_bias, space, _ball.get_rid())
	_bot_wp = int(plan.get("wp", _bot_wp))
	_aim = plan["dir"]
	_power = float(plan["power"])
	_yaw = atan2(_aim.x, -_aim.z)
	var show_ring := _hole_index == 1 or _hole_index == 4 or _hole_index == 14
	if show_ring and _bot_stage == 0:
		_dragging = true
		_bot_stage = 1
		_bot_wait = 0.35
		_queue_shot("aim_%02d" % _hole_index)
		return
	_bot_stage = 0
	_dragging = false
	var before := _ball.global_position.distance_to(cup)
	print("PUTT hole %d power %.2f aim %s from %s" % [_hole_index, _power, _aim, _ball.global_position])
	_release_shot()
	_bot_dist = before


func _end_roll(holed: bool) -> void:
	if holed:
		_finish_hole(true)
		return
	_last_rest = _ball.global_position
	if _bot or _touch:
		var cup: Vector3 = _hole.call("cup_pos")
		var now := _ball.global_position.distance_to(cup)
		if now > _bot_dist - 0.2:
			_bot_bias = -_bot_bias + (0.35 if _bot_bias >= 0.0 else -0.35)
			if absf(_bot_bias) > 1.4:
				_bot_bias = 0.2
		else:
			_bot_bias *= 0.4
		_bot_dist = now
	if _strokes >= _shot_budget():
		_finish_hole(false)
	else:
		_state = AIM
		_bot_wait = 0.15
		_touch_wait = 0.0
		_yaw_target = _yaw_toward_cup()


func _finish_hole(holed: bool) -> void:
	if holed and _hole_index == 18:
		_hole.call("celebrate")
		_queue_shot("confetti")
	var par_n := Catalog.par(_hole_index)
	_scores[_hole_index - 1] = _strokes
	_stars[_hole_index - 1] = Catalog.stars_for(par_n, _strokes, holed)
	_holed[_hole_index - 1] = holed
	var title := Catalog.result_name(par_n, _strokes, holed)
	_hud.call("show_banner", title)
	_state = BANNER
	_banner_t = 0.45 if (_bot or _touch) else 1.35
	print("HOLE %02d %s par %d strokes %d %s stars %d at %s" % [
		_hole_index, Catalog.hole_name(_hole_index), par_n, _strokes,
		"PASS" if holed else "FAIL", _stars[_hole_index - 1],
		_ball.global_position,
	])
	if (_bot or _touch) and OS.get_environment("MINIGOLF_ONLY") != "":
		_state = DONE
		round_finished.emit(_results())
		Engine.time_scale = 1.0


func _after_banner() -> void:
	_hud.call("hide_banner")
	if _hole_index == 9 or _hole_index == 18:
		_show_card(_hole_index == 18)
		return
	_advance()


func _show_card(final_card: bool) -> void:
	_card_final = final_card
	var payload := _card_payload(final_card)
	if final_card:
		var recorded: Dictionary = Scores.record_round(int(payload["total"]), Catalog.PAR_TOTAL)
		payload["new_best"] = bool(recorded.get("new_best", false))
		payload["best"] = int(recorded.get("best", 0))
		Access.clear_round()
		print("BOARD saved strokes %d plus %s new_best %s" % [
			int(payload["total"]),
			Scores.format_plus(int(payload["total"]) - Catalog.PAR_TOTAL),
			payload["new_best"],
		])
		var stored: Array = recorded.get("entries", [])
		for i in stored.size():
			var row: Dictionary = stored[i]
			print("BOARD row %d %s %d %s %s" % [
				i + 1,
				str(row.get("name", "")),
				int(row.get("strokes", 0)),
				Scores.format_plus(int(row.get("plus", 0))),
				str(row.get("date", "")),
			])
	else:
		payload["best"] = Scores.best_strokes()
	_hud.call("show_scorecard", payload)
	_state = CARD
	_card_hold = 0.8
	_queue_shot("scorecard_113" if final_card else "scorecard_out_113")


func _card_payload(final_card: bool) -> Dictionary:
	var last := 18 if final_card else 9
	var rows: Array = []
	var out_s := 0
	var in_s := 0
	var out_p := 0
	var in_p := 0
	for i in last:
		var par_n := Catalog.par(i + 1)
		var strokes := int(_scores[i])
		var plus := strokes - par_n
		var oob_n := int(_oob[i])
		rows.append({
			"hole": i + 1,
			"name": Catalog.hole_name(i + 1),
			"par": par_n,
			"strokes": strokes,
			"plus": plus,
			"oob": oob_n,
		})
		print("SCORECARD hole %d par %d strokes %d plus %d oob %d" % [i + 1, par_n, strokes, plus, oob_n])
		if i < 9:
			out_s += strokes
			out_p += par_n
		else:
			in_s += strokes
			in_p += par_n
	var total := out_s + (in_s if final_card else 0)
	var total_par := (out_p + in_p) if final_card else out_p
	if final_card:
		print("SCORECARD out %d par %d in %d par %d total %d par %d plus %d" % [
			out_s, out_p, in_s, in_p, total, total_par, total - total_par,
		])
	else:
		print("SCORECARD out %d par %d plus %d" % [out_s, out_p, out_s - out_p])
	return {
		"title": "Scorecard" if final_card else "Front nine",
		"rows": rows,
		"final": final_card,
		"out_strokes": out_s,
		"out_par": out_p,
		"in_strokes": in_s,
		"in_par": in_p,
		"total": total,
		"total_par": total_par,
		"new_best": false,
		"best": 0,
		"continue_text": "Back nine",
	}


func _advance() -> void:
	if _hole_index >= 18:
		_state = DONE
		round_finished.emit(_results())
		return
	_begin_hole(_hole_index + 1)


func _on_continue() -> void:
	_hud.call("hide_scorecard")
	if _card_final:
		_on_exit()
		return
	_advance()


func _on_play_again() -> void:
	start_fresh_round()


func start_fresh_round() -> void:
	Access.clear_round()
	_blank_scores()
	_strokes = 0
	_card_final = false
	_card_hold = 0.0
	_banner_t = 0.0
	_flash_t = 0.0
	_fly_t = 0.0
	_rest_t = 0.0
	_look_mode = false
	_cam_user_dist = CAM_DEFAULT
	_cam_dist = CAM_DEFAULT
	_cam_target = CAM_DEFAULT
	_cam_lift = 0.0
	_pointers.clear()
	_pinch_span = 0.0
	_dragging = false
	_pointer_down = false
	_cancelled = false
	_camera_hold = false
	_wall_done = false
	_wall_shot = false
	_wall_probe = false
	if _hud and is_instance_valid(_hud):
		_hud.call("reset_chrome")
	_begin_hole(1)
	print("ROUND fresh hole %d strokes %d unlocked %s" % [_hole_index, _strokes, Access.is_unlocked()])


func _on_view() -> void:
	if _state == VIEW:
		_exit_view()
		return
	if _state != AIM:
		return
	_enter_view()


func _enter_view() -> void:
	var tee: Vector3 = _hole.call("tee_pos")
	var cup: Vector3 = _hole.call("cup_pos")
	_view_focus = (tee + cup) * 0.5
	_view_focus.y = maxf(tee.y, cup.y)
	_view_yaw = 0.35
	_view_pitch = 46.0
	_view_dist = clampf(8.5, VIEW_NEAR, VIEW_FAR)
	_view_moved = false
	_state = VIEW
	_place_view_camera()


func _exit_view() -> void:
	_state = AIM
	_yaw_target = _yaw_toward_cup()
	_cam_locked = false
	_snap_camera()


func open_view_hole() -> void:
	_enter_view()


func set_view_zoom(dist: float) -> void:
	_view_dist = clampf(dist, VIEW_NEAR, VIEW_FAR)
	if _state == VIEW:
		_place_view_camera()


func _on_exit() -> void:
	Access.clear_round()
	Access.set_return(Vector3(0.0, 0.2, -96.0), 0.0)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	if AppConfig:
		AppConfig.go(AppConfig.explore_scene_path())


func _results() -> Array:
	var rows: Array = []
	for i in Catalog.hole_count():
		rows.append({
			"hole": i + 1,
			"name": Catalog.hole_name(i + 1),
			"par": Catalog.par(i + 1),
			"strokes": int(_scores[i]),
			"stars": int(_stars[i]),
			"holed": bool(_holed[i]),
		})
	return rows


func _update_camera(delta: float) -> void:
	if _camera_hold:
		return
	if _state == VIEW:
		_place_view_camera()
		_fade_decor(delta)
		return
	if _state == AIM and _cam_locked and not _look_mode:
		_cam.global_transform = _locked_xform
		return
	if _state == ROLL:
		var vel: Vector3 = _ball.linear_velocity
		vel.y = 0.0
		var cup_yaw := _yaw_toward_cup()
		if vel.length() > 0.45:
			var face := atan2(vel.x, -vel.z)
			# Follow the roll, but keep leaning toward the cup so a bounce
			# cannot spin the lens around.
			var desired := lerp_angle(face, cup_yaw, 0.42)
			var step := clampf(angle_difference(desired, _yaw), -1.15 * delta, 1.15 * delta)
			_yaw += step
		else:
			_yaw = lerp_angle(_yaw, cup_yaw, 1.0 - exp(-1.6 * delta))
		_yaw_target = _yaw
		_place_camera(_ball.global_position, _yaw, delta)
	elif _state == AIM:
		if not _gesture_lock and _touch_phase == 0 and not (_dragging and not _look_mode):
			_yaw = lerp_angle(_yaw, _yaw_target, 1.0 - exp(-3.2 * delta))
		_place_camera(_ball.global_position, _yaw, delta)
	elif _state == FLY:
		var cup: Vector3 = _hole.call("cup_pos")
		var tee: Vector3 = _hole.call("tee_pos")
		var u := clampf(_fly_t / 2.0, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var from := cup + Vector3(0.4, 3.4, -3.2)
		var to := _camera_offset(tee, 0.0, _cam_user_dist)
		_cam.global_position = from.lerp(to, u)
		var look := cup.lerp(_look_target(tee, _cam.global_position), u)
		if _cam.global_position.distance_to(look) > 0.2:
			_cam.look_at(look, Vector3.UP)
	if _state == AIM or _state == ROLL:
		_fade_decor(delta)


func _place_camera(focus: Vector3, yaw: float, delta: float) -> void:
	var resolved := _clear_distance(focus, yaw, _cam_user_dist)
	# Ignore a tiny change so a rail edge cannot flicker the lens.
	if absf(resolved - _cam_target) < 0.16:
		resolved = _cam_target
	_cam_target = resolved
	var gap := _cam_target - _cam_dist
	# Pull-in is damped. Letting the distance back out is slower, so a
	# grazing rail cannot bounce the lens.
	var rate := 1.6
	if gap < -1.1:
		rate = 4.2
	elif gap < -0.05:
		rate = 2.4
	_cam_dist = lerpf(_cam_dist, _cam_target, 1.0 - exp(-rate * delta))
	_cam_dist = clampf(_cam_dist, 0.85, _cam_user_dist)
	var pos := _camera_pose(focus, yaw, _cam_dist)
	var lift := _rail_lift(pos, focus)
	_cam_lift = lerpf(_cam_lift, lift, 1.0 - exp(-5.0 * delta))
	pos.y += _cam_lift
	_cam.global_position = pos
	var look := _look_target(focus, pos)
	if pos.distance_to(look) > 0.15:
		_cam.look_at(look, Vector3.UP)


func _snap_camera() -> void:
	if _ball == null or _cam == null:
		return
	_cam_target = _clear_distance(_ball.global_position, _yaw, _cam_user_dist)
	_cam_dist = _cam_target
	var pos := _camera_pose(_ball.global_position, _yaw, _cam_dist)
	_cam_lift = _rail_lift(pos, _ball.global_position)
	pos.y += _cam_lift
	_cam.global_position = pos
	var look := _look_target(_ball.global_position, pos)
	if pos.distance_to(look) > 0.15:
		_cam.look_at(look, Vector3.UP)


func _look_target(focus: Vector3, cam_pos: Vector3) -> Vector3:
	# A point between the ball and the cup, high enough that the ball sits
	# in the lower middle. The lead shrinks when a wall has pulled the lens
	# in, so raising the camera over a rail does not push the ball off the
	# bottom of the frame.
	var ahead := Vector3(sin(_yaw), 0.0, -cos(_yaw))
	if _hole != null:
		var cup: Vector3 = _hole.call("cup_pos")
		var to_cup := cup - focus
		to_cup.y = 0.0
		if to_cup.length() > 0.45:
			ahead = to_cup.normalized()
	var back := focus - cam_pos
	back.y = 0.0
	var horiz := maxf(back.length(), 0.25)
	var height := cam_pos.y - focus.y
	var lead := clampf(horiz * 0.30, 0.12, 0.85)
	var lead_dir := ahead
	if back.length() > 0.05:
		var blended := back.normalized().lerp(ahead, 0.45)
		if blended.length() > 0.001:
			lead_dir = blended.normalized()
	var ball_ang := atan2(maxf(height, 0.05), horiz)
	var look_ang := maxf(ball_ang - deg_to_rad(12.5), deg_to_rad(5.0))
	var rise := height - tan(look_ang) * (horiz + lead)
	rise = clampf(rise, -0.1, 0.95)
	return focus + Vector3.UP * rise + lead_dir * lead


func _camera_pose(focus: Vector3, yaw: float, dist: float) -> Vector3:
	var pos := _camera_offset(focus, yaw, dist)
	# Visual rail tops sit under about 0.4 m. Stay above them.
	var floor_y := focus.y + 1.05
	if pos.y < floor_y:
		pos.y = floor_y
	return pos


func _rail_lift(pos: Vector3, focus: Vector3) -> float:
	if _ball == null or not is_inside_tree():
		return 0.0
	var space := get_world_3d().direct_space_state
	if space == null:
		return 0.0
	var extra := 0.0
	var trial := pos
	for _step in 8:
		var query := PhysicsRayQueryParameters3D.create(trial, focus + Vector3.UP * 0.12)
		query.collision_mask = 1
		query.exclude = [_ball.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not _occludes_ball(hit):
			return extra
		extra += 0.18
		trial.y += 0.18
		if trial.y > focus.y + 3.2:
			return extra
	return extra


func _occludes_ball(hit: Dictionary) -> bool:
	var col: Object = hit.collider
	var label := str(col.name) if col is Node else ""
	if label.begins_with("Green") or label.begins_with("Bowl") or label.begins_with("Chute") or label.begins_with("Cup"):
		return false
	var normal: Vector3 = hit.normal
	if normal.y > 0.72:
		return false
	return label.begins_with("Rails") or label.begins_with("Obstacles") or label.begins_with("Solid")


func _place_view_camera() -> void:
	var pitch := deg_to_rad(clampf(_view_pitch, 22.0, 68.0))
	var dist := clampf(_view_dist, VIEW_NEAR, VIEW_FAR)
	var offset := Vector3(sin(_view_yaw) * cos(pitch), sin(pitch), cos(_view_yaw) * cos(pitch)) * dist
	var pos := _view_focus + offset
	pos.y = maxf(pos.y, _view_focus.y + 0.9)
	_cam.global_position = pos
	if pos.distance_to(_view_focus) > 0.2:
		_cam.look_at(_view_focus + Vector3(0, 0.15, 0), Vector3.UP)


func _view_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			_view_press = touch.position
			_view_moved = false
		elif not _view_moved and _pointers.size() < 2 and touch.position.distance_to(_view_press) < 18.0:
			_exit_view()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != 0 or _pointers.size() >= 2:
			return
		_orbit_by(drag.relative)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_view_press = mouse.position
			_view_moved = false
		elif not _view_moved and mouse.position.distance_to(_view_press) < 18.0:
			_exit_view()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_orbit_by((event as InputEventMouseMotion).relative)


func _orbit_by(rel: Vector2) -> void:
	if rel.length() > 3.0:
		_view_moved = true
	var span := _span()
	_view_yaw -= rel.x / span * PI
	_view_pitch = clampf(_view_pitch + rel.y / span * 70.0, 22.0, 68.0)


func _camera_offset(focus: Vector3, yaw: float, dist: float) -> Vector3:
	var aim := Vector3(sin(yaw), 0.0, -cos(yaw))
	var pitch := deg_to_rad(CAM_PITCH)
	return focus - aim * dist * cos(pitch) + Vector3.UP * dist * sin(pitch)


func _clear_distance(focus: Vector3, yaw: float, dist: float) -> float:
	var desired := _camera_offset(focus, yaw, dist)
	var origin := focus + Vector3.UP * 0.42
	var delta := desired - origin
	var length := delta.length()
	if length < 0.2 or _ball == null or not is_inside_tree():
		return dist
	var space := get_world_3d().direct_space_state
	if space == null:
		return dist
	var dir := delta / length
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var lift := side.cross(dir).normalized()
	# The centre ray decides. A side ray only counts when something is really
	# in front of the lens, so a rail crown beside the lane cannot twitch it.
	var center_clear := _ray_clear(space, origin, dir, length)
	var clear := center_clear
	var starts: Array[Vector3] = [
		origin + side * 0.16,
		origin - side * 0.16,
		origin + lift * 0.1,
	]
	for start in starts:
		var side_clear := _ray_clear(space, start, dir, length)
		if side_clear < center_clear - 0.55:
			clear = minf(clear, side_clear)
	var resolved := minf(dist * clear / length, dist)
	# Stay on the wide lens unless a real wall is closer. Never stretch the
	# distance back out past the ray: that puts the lens inside the wall.
	if resolved >= CAM_MIN_DIST:
		return resolved
	return maxf(resolved, 0.0)


func _ray_clear(space: PhysicsDirectSpaceState3D, start: Vector3, dir: Vector3, length: float) -> float:
	var clear := length
	var exclude: Array[RID] = [_ball.get_rid()]
	var end := start + dir * length
	for _step in 6:
		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.collision_mask = 1 | CAM_LAYER
		query.exclude = exclude
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var col: Object = hit.collider
		if col is CollisionObject3D:
			exclude.append((col as CollisionObject3D).get_rid())
		if not _camera_blocks(hit):
			continue
		var at: Vector3 = hit.position
		var along := (at - start).dot(dir)
		if along > 0.1:
			clear = minf(clear, along - 0.42)
		break
	return clear


func _camera_blocks(hit: Dictionary) -> bool:
	var col: Object = hit.collider
	# Props fade instead of yanking the lens onto the ball.
	if col is Node and (col as Node).has_meta("fade_mesh"):
		return false
	var label := str(col.name) if col is Node else ""
	if label.begins_with("Green") or label.begins_with("Bowl") or label.begins_with("Chute") or label.begins_with("Cup"):
		return false
	# Rails are short. Pulling in for a lip snapped the lens onto the ball.
	# The pose stays above them, and a blocked view steps the camera up.
	if label.begins_with("Rails"):
		return false
	var normal: Vector3 = hit.normal
	if normal.y > 0.55:
		return false
	return true


func _track_pointer(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pointers[touch.index] = touch.position
		else:
			_pointers.erase(touch.index)
		_apply_pinch()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pointers.has(drag.index):
			_pointers[drag.index] = drag.position
			_apply_pinch()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.08)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.08)


func _zoom_by(scale: float) -> void:
	if _state == VIEW:
		_view_dist = clampf(_view_dist * scale, VIEW_NEAR, VIEW_FAR)
	else:
		_cam_user_dist = clampf(_cam_user_dist * scale, CAM_NEAR, CAM_FAR)


func _apply_pinch() -> void:
	if _pointers.size() < 2:
		_pinch_span = 0.0
		return
	var pts: Array = _pointers.values()
	var span: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
	if _pinch_span > 8.0 and span > 8.0:
		_zoom_by(span / _pinch_span)
	_pinch_span = span


func _collect_decor() -> void:
	_decor.clear()
	_decor_alpha.clear()
	if _hole == null:
		return
	for node in _hole.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not _decor_owner(mi):
			continue
		if mi.get_parent() != null and str(mi.get_parent().name) == "CamBlock":
			continue
		_decor.append(mi)
		_decor_alpha[mi] = 1.0
		var shape := mi.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		if shape == null or shape.data.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = "CamBlock"
		body.collision_layer = CAM_LAYER
		body.collision_mask = 0
		body.set_meta("fade_mesh", mi)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)


func _decor_owner(mi: Node) -> bool:
	var n: Node = mi
	while n != null and n != self:
		var label := str(n.name)
		if label.begins_with("Decor") or label.begins_with("HoleSign"):
			return true
		if label in ["WeddingCake", "Roses", "SunTopper", "LedgePiping", "GiantDonut", "GiantCroissant", "MixingBowl", "BowlLegs", "Storefront", "ShopWalls", "Awning", "Counter", "PipingStation", "FrostingTubes", "NozzleRings", "GreenMug", "WindmillTower", "Oven", "Lattice", "FlourSack", "ArchSign", "Pennant"]:
			return true
		n = n.get_parent()
	return false


func _fade_decor(delta: float) -> void:
	if _cam == null or _ball == null or _decor.is_empty() or not is_inside_tree():
		return
	var blocking := {}
	var space := get_world_3d().direct_space_state
	if space != null:
		var origin := _ball.global_position + Vector3.UP * 0.42
		var end := _cam.global_position
		var exclude: Array[RID] = [_ball.get_rid()]
		for _step in 8:
			var query := PhysicsRayQueryParameters3D.create(end, origin)
			query.collision_mask = CAM_LAYER
			query.exclude = exclude
			query.hit_from_inside = true
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			var col: Object = hit.collider
			if col is CollisionObject3D:
				exclude.append((col as CollisionObject3D).get_rid())
			if col is Node and (col as Node).has_meta("fade_mesh"):
				var mesh: Object = (col as Node).get_meta("fade_mesh")
				if mesh is MeshInstance3D:
					blocking[mesh] = true
	for mi in _decor:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		var target := 0.12 if blocking.has(mi) else 1.0
		var alpha := lerpf(float(_decor_alpha.get(mi, 1.0)), target, 1.0 - exp(-8.0 * delta))
		_decor_alpha[mi] = alpha
		var shown := alpha > 0.96
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var color := mat.albedo_color
			color.a = alpha
			mat.albedo_color = color
			if mat.alpha_scissor_threshold > 0.0:
				continue
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if shown else BaseMaterial3D.TRANSPARENCY_ALPHA


func _shot_cup_drop() -> void:
	if OS.get_environment("MINIGOLF_CUP_SHOT") != "1" or _cam == null or _ball == null:
		return
	OS.set_environment("MINIGOLF_CUP_SHOT", "0")
	var focus: Vector3 = _ball.global_position
	_camera_hold = true
	_cam.global_position = focus + Vector3(0.62, 0.18, 0.38)
	_cam.look_at(focus, Vector3.UP)
	call_deferred("_save_cup_shot")


func _save_cup_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/minigolf")
	var path := "/opt/cursor/artifacts/minigolf/cup_drop.png"
	img.save_png(path)
	print("CUP_SHOT ", path, " ", img.get_width(), "x", img.get_height(), " ball ", _ball.global_position)


func _aim_visual() -> void:
	var show := _state == AIM and _dragging and not _look_mode and not _cancelled and _power > 0.04
	var reach := 0.55 + _power * 2.6
	var screen := PackedVector2Array()
	for i in _aim_dots.size():
		var dot := _aim_dots[i]
		var along := 0.18 + float(i) * 0.2
		if not show or along > reach:
			dot.visible = false
			continue
		var world := _ball.global_position + _aim * along + Vector3.UP * 0.025
		dot.visible = true
		dot.global_position = world
		dot.scale = Vector3.ONE
		if not _cam.is_position_behind(world):
			screen.append(_cam.unproject_position(world))
	if _hud and _hud.has_method("set_aim_screen"):
		_hud.call("set_aim_screen", screen, show)


func _power_widget() -> void:
	if _hud == null or not _hud.has_method("set_power"):
		return
	var at := _cam.unproject_position(_ball.global_position)
	var aiming := _state == AIM and _dragging and not _look_mode
	_hud.call("set_power", _power, at, aiming and _power > 0.04, aiming and _cancelled)


func _queue_shot(tag: String) -> void:
	if not _bot and not _touch:
		return
	call_deferred("_save_shot", tag)


func _save_shot(tag: String) -> void:
	var frames := 10 if tag == "confetti" else 1
	for _i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/minigolf")
	var path := "/opt/cursor/artifacts/minigolf/%s.png" % tag
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())


func _on_look(on: bool) -> void:
	_look_mode = on
	if on:
		_power = 0.0
		_cancelled = true
		_cam_locked = false
		_yaw_target = _yaw


func _refresh_hint() -> void:
	if _hud == null or not _hud.has_method("set_hint"):
		return
	if _state == VIEW:
		_hud.call("set_hint", "Drag to orbit. Pinch to zoom. Tap to putt.")
		return
	if _state != AIM:
		_hud.call("set_hint", "")
		return
	if _look_mode:
		_hud.call("set_hint", "Drag to look around. Tap Look again to putt.")
	elif _dragging and _cancelled:
		_hud.call("set_hint", "Release to cancel")
	elif _dragging and _power > 0.04:
		_hud.call("set_hint", "Release to putt")
	else:
		_hud.call("set_hint", "Pull back anywhere to putt")


func _block_walk_controls() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	var tree := get_tree()
	if tree == null:
		return
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != self and (node is ExploreVirtualJoystick or node.get_class() == "ExploreVirtualJoystick"):
			node.hide()
			if node is Control:
				(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in node.get_children():
			stack.append(child)


func _blocks_walk_action(event: InputEvent) -> bool:
	return event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_forward") or event.is_action("move_back")


func _span() -> float:
	var size := get_viewport().get_visible_rect().size
	return maxf(240.0, minf(size.x, size.y))


func _full_pull() -> float:
	return _span() * 0.42


func _deadzone() -> float:
	# Short putts are a small drag. The old zone ate anything under about
	# 11 percent power, so a tap-in never released.
	return _span() * 0.008


func _cancel_radius() -> float:
	return _span() * 0.09


func _safe_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	return Rect2(Vector2(40.0, 180.0), Vector2(maxf(80.0, size.x - 180.0), maxf(80.0, size.y - 360.0)))


func _capture_drag_axes() -> void:
	_drag_right = _flat_axis(_cam.global_transform.basis.x)
	_drag_forward = _flat_axis(-_cam.global_transform.basis.z)
	if not _look_mode:
		_cam_locked = true
		_locked_xform = _cam.global_transform
		_gesture_lock = true


func _release_camera_lock() -> void:
	if _cam_locked:
		var drift := _cam.global_position.distance_to(_locked_xform.origin)
		print("CAM drift %.4f" % drift)
	_cam_locked = false
	_gesture_lock = false


func _flat_axis(axis: Vector3) -> Vector3:
	axis.y = 0.0
	if axis.length() < 0.01:
		return Vector3(0, 0, -1)
	return axis.normalized()


func _yaw_toward_cup() -> float:
	if _hole == null or _ball == null:
		return _yaw
	var cup: Vector3 = _hole.call("cup_pos")
	var flat := cup - _ball.global_position
	flat.y = 0.0
	if flat.length() < 0.2:
		return _yaw
	return atan2(flat.x, -flat.z)


func _yaw_settled() -> bool:
	return absf(angle_difference(_yaw, _yaw_target)) < 0.08


func _screen_delta(dir: Vector3, power: float) -> Vector2:
	var pulled := -dir * (power * _full_pull())
	var dx := pulled.dot(_drag_right)
	var dy := -pulled.dot(_drag_forward)
	return Vector2(dx, dy)


func _place_gesture(delta: Vector2) -> Vector2:
	var ball_at := _cam.unproject_position(_ball.global_position)
	var perp := Vector2(-delta.y, delta.x)
	if perp.length() < 1.0:
		perp = Vector2(1, 0)
	perp = perp.normalized()
	var safe := _safe_rect()
	var gap := _cancel_radius() + 56.0
	for sign_i in 2:
		var sign := 1.0 if sign_i == 0 else -1.0
		for extra_i in 4:
			var extra := float(extra_i) * 80.0
			var start: Vector2 = ball_at + perp * sign * (gap + extra)
			start = _shift_into(start, delta, safe)
			var end: Vector2 = start + delta
			if not safe.has_point(start) or not safe.has_point(end):
				continue
			if end.distance_to(ball_at) <= _cancel_radius() + 12.0:
				continue
			if _segment_hits_ball(start, end, ball_at):
				continue
			return start
	return safe.position + safe.size * 0.35


func _shift_into(start: Vector2, delta: Vector2, safe: Rect2) -> Vector2:
	var end := start + delta
	var shift := Vector2.ZERO
	var min_p := Vector2(minf(start.x, end.x), minf(start.y, end.y))
	var max_p := Vector2(maxf(start.x, end.x), maxf(start.y, end.y))
	var limit := safe.position + safe.size
	if min_p.x < safe.position.x:
		shift.x += safe.position.x - min_p.x
	elif max_p.x > limit.x:
		shift.x -= max_p.x - limit.x
	if min_p.y < safe.position.y:
		shift.y += safe.position.y - min_p.y
	elif max_p.y > limit.y:
		shift.y -= max_p.y - limit.y
	return start + shift


func _segment_hits_ball(start: Vector2, end: Vector2, ball_at: Vector2) -> bool:
	var span := end - start
	var len2 := span.length_squared()
	if len2 < 1.0:
		return start.distance_to(ball_at) <= _cancel_radius()
	var t := clampf((ball_at - start).dot(span) / len2, 0.0, 1.0)
	return start.lerp(end, t).distance_to(ball_at) <= _cancel_radius()


func _start_touch_putt(hold: bool) -> void:
	if _ball == null or _hole == null or _touch_busy:
		return
	_yaw = _yaw_target
	_snap_camera()
	_capture_drag_axes()
	var space := get_world_3d().direct_space_state
	var cup: Vector3 = _hole.call("cup_pos")
	var plan: Dictionary = Bot.choose(_hole_index, _ball.global_position, cup, _hole, _bot_wp, _bot_bias, space, _ball.get_rid())
	if not _wall_shot:
		_bot_wp = int(plan.get("wp", _bot_wp))
	var dir: Vector3 = plan["dir"]
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	var power := float(plan["power"])
	if _wall_shot:
		dir = Vector3.RIGHT
		power = 1.0
	_planned_aim = dir
	_planned_power = power
	var delta := _screen_delta(dir, power)
	_touch_from = _place_gesture(delta)
	_touch_to = _touch_from + delta
	var ball_at := _cam.unproject_position(_ball.global_position)
	print("GESTURE hole %d power %.2f from %s to %s ball %s dist %.0f" % [_hole_index, power, _touch_from, _touch_to, ball_at, _touch_to.distance_to(ball_at)])
	_touch_hold = hold
	_touch_step = 0
	_touch_phase = 1
	_touch_busy = true
	_gesture_lock = true


func _touch_pump() -> void:
	# The whole drag is one frame so a moving gate is in the same pose the
	# direct putt would see. The camera stays at the press transform.
	if _touch_phase == 0:
		return
	if _touch_phase == 1:
		_parse_touch(true, _touch_from)
		for step in 4:
			var u := clampf(float(step + 1) / 4.0, 0.0, 1.0)
			_parse_drag(_touch_from.lerp(_touch_to, u))
		if _touch_hold:
			_touch_phase = 0
		else:
			_parse_touch(false, _touch_to)
			_touch_phase = 0
			_touch_busy = false
	elif _touch_phase == 4:
		var ball_at := _cam.unproject_position(_ball.global_position)
		_parse_drag(ball_at)
		_parse_touch(false, ball_at)
		_touch_phase = 0
		_touch_busy = false
		_gesture_lock = false


func _event_space(logical: Vector2) -> Vector2:
	# unproject_position is in canvas space. parse_input_event expects the
	# window's pixel space and stretches it back. Real touches already arrive
	# in canvas space, so only injected events need this conversion.
	var visible := get_viewport().get_visible_rect().size
	var win := Vector2(get_window().size)
	if visible.x < 1.0 or visible.y < 1.0 or win.x < 1.0 or win.y < 1.0:
		return logical
	return Vector2(logical.x * win.x / visible.x, logical.y * win.y / visible.y)


func _parse_touch(pressed: bool, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = _event_space(at)
	Input.parse_input_event(ev)


func _parse_drag(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = _event_space(at)
	ev.relative = _event_space(at) - _event_space(_last_pointer)
	Input.parse_input_event(ev)


func hold_camera(hold: bool) -> void:
	_camera_hold = hold


func open_aim_preview() -> void:
	_start_touch_putt(true)


func aim_preview_ready() -> bool:
	return _dragging and _power > 0.05 and _touch_phase == 0 and not _cancelled


func cancel_aim_preview() -> void:
	if not _pointer_down:
		return
	_touch_phase = 4
	_touch_busy = true


func aim_preview_idle() -> bool:
	return not _dragging and not _pointer_down and _touch_phase == 0


func wall_failures() -> int:
	return _wall_failures


func _finish_wall_probe() -> void:
	var launched := _wall_peak > 1.15
	if launched:
		_wall_failures += 1
	print("WALL hole %d peak_y %.2f launched %s at %s" % [
		_hole_index, _wall_peak, "1" if launched else "0", _ball.global_position,
	])
	_wall_probe = false
	_wall_done = true
	_wall_shot = false
	_strokes = 0
	_bot_wp = 0
	_bot_bias = 0.0
	_rest_t = 0.0
	_spawn_ball(_hole.call("tee_pos"), "reset")
	_hud.call("flash", "")
	_hud.call("set_status", _hole_index, Catalog.par(_hole_index), 0)
	_state = AIM
	_touch_wait = 0.0
	_cam_locked = false
	_yaw_target = _yaw_toward_cup()


func _fit_camera() -> void:
	if _cam == null:
		return
	# KEEP_HEIGHT holds the vertical FOV on a tall phone. The root viewport
	# is the course camera; there is no SubViewport to stretch.
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.fov = 52.0
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(720, 1280)
	var win := window.size
	var visible := get_viewport().get_visible_rect().size
	print("VIEW win ", win, " visible ", visible, " fov ", _cam.fov, " keep ", _cam.keep_aspect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree() and _cam:
		_fit_camera()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# The live hole stays put if the process does. The saved resume does not,
		# so a kill, or the next walk through the gate, starts at hole 1.
		if is_inside_tree():
			Access.clear_round()
			if what == NOTIFICATION_APPLICATION_PAUSED:
				print("ROUND pause cleared")


func play_state() -> String:
	match _state:
		FLY:
			return "fly"
		AIM:
			return "aim"
		ROLL:
			return "roll"
		BANNER:
			return "banner"
		CARD:
			return "card"
		VIEW:
			return "view"
		_:
			return "done"

