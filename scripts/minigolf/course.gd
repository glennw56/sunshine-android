extends Node3D
## Slingshot putt. Touch anywhere and drag back, opposite the shot. A dotted
## line shows where the ball will go. Release putts. Dragging back onto the
## ball cancels. The camera stays put while you aim, follows the ball, then
## settles behind it. The Look button orbits. One hole is loaded at a time.

const Catalog := preload("res://scripts/minigolf/catalog.gd")
const Access := preload("res://scripts/minigolf/access.gd")
const HoleScript := preload("res://scripts/minigolf/hole.gd")
const BallScript := preload("res://scripts/minigolf/ball.gd")
const Bot := preload("res://scripts/minigolf/bot.gd")

const FLY := 0
const AIM := 1
const ROLL := 2
const BANNER := 3
const CARD := 4
const DONE := 5

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
	for _i in Catalog.hole_count():
		_scores.append(0)
		_stars.append(0)
		_holed.append(false)
	_ball = BallScript.new()
	add_child(_ball)
	if _hud.has_signal("view_requested"):
		_hud.view_requested.connect(_on_view)
		_hud.exit_requested.connect(_on_exit)
		_hud.continue_requested.connect(_on_continue)
	if _hud.has_signal("look_toggled"):
		_hud.look_toggled.connect(_on_look)
	var resume: Dictionary = {} if _bot else Access.load_round()
	if bool(resume.get("active", false)):
		_scores = resume.get("scores", _scores)
		_stars = resume.get("stars", _stars)
		_hole_index = clampi(int(resume.get("hole", 1)), 1, 18)
	var only := OS.get_environment("MINIGOLF_ONLY")
	if (_bot or _touch) and only != "":
		_hole_index = clampi(int(only), 1, 18)
	_begin_hole(_hole_index)
	_fit_camera()
	# 120 Hz plus CCD keeps a full putt from tunneling a thin rail.
	Engine.physics_ticks_per_second = 120
	Engine.max_physics_steps_per_frame = 8
	if _bot or _touch:
		Engine.time_scale = 1.0


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
	_touch_wait = 0.05
	_wall_done = false
	_wall_shot = false
	_wall_probe = false
	_wall_peak = -999.0
	_cancel_streak = 0
	_cam_locked = false
	_yaw = 0.0
	_yaw_target = 0.0
	_aim = Vector3(0, 0, -1)
	if _hole and is_instance_valid(_hole):
		var old := _hole
		_hole = null
		old.free()
	_hole = HoleScript.new()
	add_child(_hole)
	_hole.call("setup", index)
	_last_rest = _hole.call("tee_pos")
	_ball.call("park", _last_rest)
	_hole.call("arm", _ball)
	_state = FLY
	_fly_t = 0.0
	_hud.call("hide_banner")
	_hud.call("hide_scorecard")
	_hud.call("flash", "")
	_hud.call("set_status", index, Catalog.par(index), 0)
	if _bot or _touch:
		_fly_t = 2.0
		if _bot and (index == 1 or index == 4 or index == 10 or index == 14 or index == 18):
			_queue_shot("hole_%02d" % index)


func _physics_process(delta: float) -> void:
	if _hole == null or _ball == null:
		return
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
			_ball.call("park", _ball.global_position)
			_finish_hole(true)
		elif event == "oob":
			_ball.call("park", _last_rest)
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
			_place_camera(_ball.global_position, _yaw, 1.0)
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
			if _touch_wait <= 0.0 and _yaw_settled() and (_wall_mode and not _wall_done or ready):
				_bot_ready_wait = 0.0
				_touch_wait = 0.05
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
	if _look_mode or _cancelled or _power < 0.04:
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
	if _strokes >= Catalog.par(_hole_index) + Catalog.STROKE_CAP:
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
	if _strokes >= Catalog.par(_hole_index) + Catalog.STROKE_CAP:
		_finish_hole(false)
	else:
		_state = AIM
		_bot_wait = 0.15
		_touch_wait = 0.05
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
	Access.save_round(_hole_index + 1, _scores, _stars, _hole_index < 18)
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
	var total := 0
	for i in _hole_index:
		total += int(_scores[i])
	var best := Access.best_total()
	if final_card:
		best = Access.note_best(total)
		Access.clear_round()
	_hud.call("show_scorecard", "Scorecard" if final_card else "Front nine", _card_bbcode(final_card, total, best), "Back to the patio" if final_card else "Back nine")
	_state = CARD
	_card_hold = 0.8
	_queue_shot("scorecard_%d" % _hole_index)


func _card_bbcode(final_card: bool, total: int, best: int) -> String:
	var last := 18 if final_card else 9
	var first := 1 if not final_card else 1
	var lines := ""
	if final_card:
		first = 1
		last = 18
	var sub := 0
	for i in range(first - 1, last):
		var stars := "★".repeat(int(_stars[i]))
		lines += "%d  %s    par %d    %d  %s\n" % [i + 1, Catalog.hole_name(i + 1), Catalog.par(i + 1), int(_scores[i]), stars]
		sub += int(_scores[i])
	var best_line := "Best —" if best <= 0 else "Best %d" % best
	if final_card:
		var front := 0
		var back := 0
		for i in 9:
			front += int(_scores[i])
			back += int(_scores[i + 9])
		lines += "\nOut %d    In %d    Total %d\n%s" % [front, back, total, best_line]
	else:
		lines += "\nOut %d    Par 23\n%s" % [sub, best_line]
	return lines


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


func _on_view() -> void:
	if _state != AIM:
		return
	_fly_t = 0.0
	_state = FLY


func _on_exit() -> void:
	if _state != DONE:
		Access.save_round(_hole_index, _scores, _stars, true)
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
	if _state == AIM and _cam_locked and not _look_mode:
		_cam.global_transform = _locked_xform
		return
	if _state == ROLL:
		var vel: Vector3 = _ball.linear_velocity
		vel.y = 0.0
		if vel.length() > 0.5:
			var face := atan2(vel.x, -vel.z)
			_yaw = lerp_angle(_yaw, face, 1.0 - exp(-2.6 * delta))
		_yaw_target = _yaw
		_place_camera(_ball.global_position, _yaw, 1.0)
	elif _state == AIM:
		if not _gesture_lock and _touch_phase == 0 and not (_dragging and not _look_mode):
			_yaw = lerp_angle(_yaw, _yaw_target, 1.0 - exp(-8.0 * delta))
		_place_camera(_ball.global_position, _yaw, 1.0)
	elif _state == FLY:
		var cup: Vector3 = _hole.call("cup_pos")
		var tee: Vector3 = _hole.call("tee_pos")
		var u := clampf(_fly_t / 2.0, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var from := cup + Vector3(0.4, 2.1, -2.6)
		var to := _camera_pos(tee, 0.0, 2.55)
		_cam.global_position = from.lerp(to, u)
		var look := cup.lerp(tee, u)
		if _cam.global_position.distance_to(look) > 0.2:
			_cam.look_at(look + Vector3(0, 0.1, 0), Vector3.UP)


func _place_camera(focus: Vector3, yaw: float, blend: float) -> void:
	var pos := _camera_pos(focus, yaw, 2.45)
	_cam.global_position = _cam.global_position.lerp(pos, blend)
	if _cam.global_position.distance_to(focus) > 0.2:
		_cam.look_at(focus + Vector3(0, 0.08, 0), Vector3.UP)


func _camera_pos(focus: Vector3, yaw: float, dist: float) -> Vector3:
	var aim := Vector3(sin(yaw), 0.0, -cos(yaw))
	var pitch := deg_to_rad(40.0)
	return focus - aim * dist * cos(pitch) + Vector3.UP * dist * sin(pitch)


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
	_capture_drag_axes()
	var space := get_world_3d().direct_space_state
	var cup: Vector3 = _hole.call("cup_pos")
	var plan: Dictionary = Bot.choose(_hole_index, _ball.global_position, cup, _hole, _bot_wp, _bot_bias, space, _ball.get_rid())
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
	# One drag sample per frame. The camera transform stays at the press pose.
	if _touch_phase == 0:
		return
	if _touch_phase == 1:
		_parse_touch(true, _touch_from)
		_touch_phase = 2
		_touch_step = 0
	elif _touch_phase == 2:
		_touch_step += 1
		var u := clampf(float(_touch_step) / 4.0, 0.0, 1.0)
		_parse_drag(_touch_from.lerp(_touch_to, u))
		if _touch_step >= 4:
			if _touch_hold:
				_touch_phase = 0
			else:
				_touch_phase = 3
	elif _touch_phase == 3:
		_parse_touch(false, _touch_to)
		_touch_phase = 0
		_touch_busy = false
	elif _touch_phase == 4:
		var ball_at := _cam.unproject_position(_ball.global_position)
		_parse_drag(ball_at)
		_touch_phase = 5
	elif _touch_phase == 5:
		var ball_at := _cam.unproject_position(_ball.global_position)
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
	return _dragging and _power > 0.12 and _touch_phase == 0 and not _cancelled


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
	_rest_t = 0.0
	var tee: Vector3 = _hole.call("tee_pos")
	_last_rest = tee
	_ball.call("park", tee)
	_hud.call("flash", "")
	_hud.call("set_status", _hole_index, Catalog.par(_hole_index), 0)
	_state = AIM
	_touch_wait = 0.15
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
		_:
			return "done"

