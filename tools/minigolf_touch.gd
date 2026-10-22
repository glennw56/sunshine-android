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
	var cfg: Node = root.get_node("AppConfig")
	cfg.set("test_world", true)
	Access.grant()
	Access.clear_round()
	_phone(1080, 2400)
	var packed := load("res://scenes/minigolf/course.tscn") as PackedScene
	var course := packed.instantiate()
	root.add_child(course)
	current_scene = course
	if not await _wait_state(course, "aim", 8.0):
		push_error("TOUCH never reached aim")
		quit(1)
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
	var failed := 0
	var total := 0
	for row in results:
		var holed := bool(row.get("holed", false))
		total += int(row.get("strokes", 0))
		if not holed:
			failed += 1
		print("RESULT hole %02d %-22s par %d strokes %d %s" % [
			int(row.get("hole", 0)), str(row.get("name", "")), int(row.get("par", 0)),
			int(row.get("strokes", 0)), "PASS" if holed else "FAIL",
		])
	print("PLAYTHROUGH total %d failed %d" % [total, failed])
	quit(0 if failed == 0 else 2)


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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	DisplayServer.window_set_size(Vector2i(width, height))
	root.size = Vector2i(width, height)
	print("TOUCH viewport ", root.size)


func _shot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("TOUCH screenshot failed " + tag)
		return
	var path := "%s/%s.png" % [SHOTS, tag]
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())


func _write(results: Array) -> void:
	var file := FileAccess.open(SHOTS + "/results.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
