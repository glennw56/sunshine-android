extends SceneTree
## Phone-resolution touch play of the mini golf course.
## Drag events go through the real slingshot controls. No direct launches.
##   godot --path . -s res://tools/minigolf_touch.gd

const Access := preload("res://scripts/minigolf/access.gd")
const SHOTS := "/opt/cursor/artifacts/minigolf"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	OS.set_environment("MINIGOLF_BOT", "0")
	OS.set_environment("MINIGOLF_TOUCH", "1")
	OS.set_environment("MINIGOLF_TOUCH_ARM", "0")
	if OS.get_environment("MINIGOLF_WALL") == "":
		OS.set_environment("MINIGOLF_WALL", "1")
	var cfg: Node = root.get_node("AppConfig")
	cfg.set("test_world", true)
	Access.grant()
	Access.clear_round()
	var fast := OS.get_environment("MINIGOLF_TOUCH_FAST") == "1"
	if fast:
		OS.set_environment("MINIGOLF_TOUCH_ARM", "1")
	else:
		_phone(1080, 2400)
	var packed := load("res://scenes/minigolf/course.tscn") as PackedScene
	var course := packed.instantiate()
	root.add_child(course)
	current_scene = course
	if not await _wait_state(course, "aim", 8.0):
		push_error("TOUCH never reached aim")
		quit(1)
		return
	if OS.get_environment("MINIGOLF_TOUCH_FAST") == "1":
		var results: Array = await course.round_finished
		_write(results)
		var tally := _tally(results)
		var walls := int(course.call("wall_failures"))
		print("PLAYTHROUGH total %d failed %d wall_failures %d" % [tally.x, tally.y, walls])
		quit(0 if tally.y == 0 and walls == 0 else 2)
		return
	for _i in 12:
		await process_frame
	course.call("hold_camera", true)
	var ball := course.get_node("GolfBall") as Node3D
	var cam := course.get_node("Camera3D") as Camera3D
	var at: Vector3 = ball.global_position
	cam.global_position = at + Vector3(0.04, 0.06, 0.22)
	cam.look_at(at, Vector3.UP)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot("ball_closeup")
	_measure_ball(cam, at)
	course.call("hold_camera", false)
	for _i in 8:
		await process_frame
	if not await _preview(course, "aim_ui"):
		push_error("TOUCH portrait aim preview failed")
		quit(1)
		return
	_phone(2400, 1080)
	for _i in 10:
		await process_frame
	if not await _preview(course, "aim_landscape"):
		push_error("TOUCH landscape aim preview failed")
		quit(1)
		return
	_phone(1080, 2400)
	for _i in 8:
		await process_frame
	if OS.get_environment("MINIGOLF_TOUCH_SHOTS_ONLY") == "1":
		print("TOUCH shots only")
		quit(0)
		return
	OS.set_environment("MINIGOLF_TOUCH_ARM", "1")
	var results: Array = await course.round_finished
	_write(results)
	var tally := _tally(results)
	var walls := int(course.call("wall_failures"))
	print("PLAYTHROUGH total %d failed %d wall_failures %d" % [tally.x, tally.y, walls])
	quit(0 if tally.y == 0 and walls == 0 else 2)


func _preview(course: Node, tag: String) -> bool:
	course.call("open_aim_preview")
	var started := Time.get_ticks_msec()
	while not bool(course.call("aim_preview_ready")):
		if Time.get_ticks_msec() - started > 4000:
			return false
		await process_frame
	await RenderingServer.frame_post_draw
	_shot(tag)
	course.call("cancel_aim_preview")
	started = Time.get_ticks_msec()
	while not bool(course.call("aim_preview_idle")):
		if Time.get_ticks_msec() - started > 4000:
			return false
		await process_frame
	return true


func _wait_state(course: Node, want: String, seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while str(course.call("play_state")) != want:
		if Time.get_ticks_msec() - started > int(seconds * 1000.0):
			return false
		await process_frame
	return true


func _phone(width: int, height: int) -> void:
	# Same stretch the phone build uses, so a squashed sphere shows up here.
	# The viewport has to match the window. A 480x800 buffer stretched onto
	# a 1080x2400 window is what turns the ball into an oval.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(width, height)
	DisplayServer.window_set_size(Vector2i(width, height))
	print("TOUCH window ", DisplayServer.window_get_size(), " root ", root.size, " scale ", root.content_scale_factor, " visible ", root.get_visible_rect().size)


func _measure_ball(cam: Camera3D, at: Vector3) -> void:
	var center := cam.unproject_position(at)
	var right := cam.unproject_position(at + Vector3(0.06, 0.0, 0.0))
	var up := cam.unproject_position(at + Vector3(0.0, 0.06, 0.0))
	var dx := center.distance_to(right)
	var dy := center.distance_to(up)
	var ratio := dx / dy if dy > 1.0 else 0.0
	print("BALL_SCREEN dx %.1f dy %.1f ratio %.3f" % [dx, dy, ratio])


func _shot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("TOUCH screenshot failed " + tag)
		return
	var path := "%s/%s.png" % [SHOTS, tag]
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())


func _tally(results: Array) -> Vector2i:
	var only := OS.get_environment("MINIGOLF_ONLY")
	var failed := 0
	var total := 0
	for row in results:
		var hole := int(row.get("hole", 0))
		if only != "" and hole != int(only):
			continue
		var holed := bool(row.get("holed", false))
		total += int(row.get("strokes", 0))
		if not holed:
			failed += 1
		print("RESULT hole %02d %-22s par %d strokes %d %s" % [
			hole, str(row.get("name", "")), int(row.get("par", 0)),
			int(row.get("strokes", 0)), "PASS" if holed else "FAIL",
		])
	return Vector2i(total, failed)


func _write(results: Array) -> void:
	var file := FileAccess.open(SHOTS + "/results.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
