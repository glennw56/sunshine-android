extends Node3D
## Drag back and release. The camera sits about 40 degrees behind the ball
## and orbits to the aim while the finger is down. One hole is loaded at a time.

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
var _fly_t := 0.0
var _rest_t := 0.0
var _banner_t := 0.0
var _flash_t := 0.0
var _last_rest := Vector3.ZERO
var _aim_line: MeshInstance3D
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
	_bot = OS.get_environment("MINIGOLF_BOT") == "1"
	if not _bot and AppConfig and not AppConfig.test_world:
		AppConfig.go("res://scenes/explore/explore_3d.tscn")
		return
	if not _bot and not Access.is_unlocked():
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
	var resume: Dictionary = {} if _bot else Access.load_round()
	if bool(resume.get("active", false)):
		_scores = resume.get("scores", _scores)
		_stars = resume.get("stars", _stars)
		_hole_index = clampi(int(resume.get("hole", 1)), 1, 18)
	var only := OS.get_environment("MINIGOLF_ONLY")
	if _bot and only != "":
		_hole_index = clampi(int(only), 1, 18)
	_begin_hole(_hole_index)
	if _bot:
		Engine.time_scale = 1.0
		Engine.max_physics_steps_per_frame = 2


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
	_aim_line = MeshInstance3D.new()
	_aim_line.name = "AimLine"
	var box := BoxMesh.new()
	box.size = Vector3(0.028, 0.012, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff6ea")
	box.material = mat
	_aim_line.mesh = box
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.visible = false
	add_child(_aim_line)


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
	_yaw = 0.0
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
	if _bot:
		_fly_t = 2.0
		if index == 1 or index == 4 or index == 10 or index == 14 or index == 18:
			_queue_shot("hole_%02d" % index)


func _physics_process(delta: float) -> void:
	if _hole == null or _ball == null:
		return
	if _state == ROLL:
		var event := str(_hole.call("poll"))
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
		elif event == "":
			if bool(_ball.call("is_slow")):
				_rest_t += delta
			else:
				_rest_t = 0.0
			if _rest_t > 0.32 or _roll_time_exceeded():
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
	elif _state == CARD and _bot:
		_card_hold -= delta
		if _card_hold <= 0.0 and not _card_final:
			_on_continue()
		elif _card_hold <= 0.0 and _card_final and _state == CARD:
			_state = DONE
			round_finished.emit(_results())
			Engine.time_scale = 1.0
	_aim_visual()
	_power_widget()


func _unhandled_input(event: InputEvent) -> void:
	if _bot:
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
		if _over_ui():
			return
		_dragging = true
		_drag_from = _event_pos(event)
		_power = 0.0
	elif _dragging and _moved(event):
		_apply_drag(_event_pos(event))
	elif _dragging and _released(event):
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
	var delta := at - _drag_from
	var right := _cam.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var forward := -_cam.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var pulled := right * delta.x + forward * (-delta.y)
	var shot := -pulled
	if shot.length() < 22.0:
		_power = 0.0
		return
	_aim = Vector3(shot.x, 0, shot.z).normalized()
	_power = clampf(shot.length() / 230.0, 0.0, 1.0)
	_yaw = atan2(_aim.x, -_aim.z)


func _release_shot() -> void:
	if _power < 0.02:
		_power = 0.0
		return
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
	if _bot:
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
	_banner_t = 0.45 if _bot else 1.35
	print("HOLE %02d %s par %d strokes %d %s stars %d at %s" % [
		_hole_index, Catalog.hole_name(_hole_index), par_n, _strokes,
		"PASS" if holed else "FAIL", _stars[_hole_index - 1],
		_ball.global_position,
	])
	Access.save_round(_hole_index + 1, _scores, _stars, _hole_index < 18)
	if _bot and OS.get_environment("MINIGOLF_ONLY") != "":
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
	if _state == ROLL:
		var vel: Vector3 = _ball.linear_velocity
		vel.y = 0.0
		if vel.length() > 0.5:
			var face := atan2(vel.x, -vel.z)
			_yaw = lerp_angle(_yaw, face, 1.0 - exp(-2.6 * delta))
		_place_camera(_ball.global_position, _yaw, 1.0)
	elif _state == AIM:
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
	var show := _state == AIM and _power > 0.05
	_aim_line.visible = show
	if not show:
		return
	var length := 0.45 + _power * 1.05
	_aim_line.scale = Vector3(1, 1, length)
	_aim_line.global_position = _ball.global_position + _aim * (length * 0.5)
	_aim_line.look_at(_aim_line.global_position + _aim, Vector3.UP)


func _power_widget() -> void:
	if _hud == null or not _hud.has_method("set_power"):
		return
	var at := _cam.unproject_position(_ball.global_position)
	_hud.call("set_power", _power, at, _state == AIM and _dragging)


func _queue_shot(tag: String) -> void:
	if not _bot:
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
	print("SHOT ", path)

