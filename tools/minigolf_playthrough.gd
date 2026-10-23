extends SceneTree
## Full test-world playthrough: Christmas yard, open north gate, rewarded-ad
## prompt (including the retry card), then all 18 holes to the scorecard.
##   godot --path . -s res://tools/minigolf_playthrough.gd

const Access := preload("res://scripts/minigolf/access.gd")
const SHOTS := "/opt/cursor/artifacts/minigolf"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	OS.set_environment("MINIGOLF_BOT", "1")
	var cfg: Node = root.get_node("AppConfig")
	cfg.set("test_world", true)
	Access.revoke()
	Access.clear_round()
	var packed := load("res://scenes/explore/explore_test.tscn") as PackedScene
	var boot := packed.instantiate()
	root.add_child(boot)
	current_scene = boot
	for _i in 12:
		await process_frame
	var explore := boot.get_node("Explore")
	var world: Node = explore.get_node("World")
	var player: Node3D = explore.get_node("Player")
	var yard := world.get_node_or_null("ChristmasYard") as Node3D
	var gate := world.get_node_or_null("MiniGolfGate") as Node
	if yard == null or gate == null:
		push_error("PLAYTHROUGH missing ChristmasYard or MiniGolfGate")
		quit(1)
		return
	if yard.find_child("TreeBig", true, false) == null or yard.find_child("Santa", true, false) == null:
		push_error("PLAYTHROUGH Christmas props did not load")
		quit(1)
		return
	if player.find_child("Hat_Santa", true, false) != null or player.find_child("Hat_Elf", true, false) != null:
		push_error("PLAYTHROUGH hats were parented to the player")
		quit(1)
		return
	player.global_position = yard.global_position + Vector3(0.0, 0.4, 9.0)
	player.rotation.y = 0.0
	if player.has_method("snap_to_ground"):
		player.call("snap_to_ground")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_shot("christmas")
	player.global_position = Vector3(0.0, 0.4, -99.0)
	player.rotation.y = 0.0
	if player.has_method("snap_to_ground"):
		player.call("snap_to_ground")
	for _i in 8:
		await process_frame
	if not bool(gate.call("prompt_open")):
		push_error("PLAYTHROUGH gate prompt did not open")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	_shot("gate_prompt")
	if Access.is_unlocked():
		push_error("PLAYTHROUGH course was unlocked before the ad")
		quit(1)
		return
	gate.call("show_failure", "The ad didn't load. Check your connection and try again.")
	await process_frame
	await RenderingServer.frame_post_draw
	_shot("ad_retry")
	if Access.is_unlocked():
		push_error("PLAYTHROUGH a failed ad unlocked the course")
		quit(1)
		return
	gate.call("hide_failure")
	var unit := str(cfg.call("course_rewarded_unit"))
	print("PLAYTHROUGH ad unit ", unit)
	if unit != "ca-app-pub-3940256099942544/5224354917":
		push_error("PLAYTHROUGH expected the Google test rewarded unit, got " + unit)
		quit(1)
		return
	gate.call("start_watch")
	var saw_ad := false
	var course: Node = null
	for _i in 400:
		await process_frame
		if not saw_ad and _has_label("Test build rewarded ad"):
			saw_ad = true
			await RenderingServer.frame_post_draw
			_shot("ad_confirm")
		course = root.find_child("MiniGolf", true, false)
		if course:
			break
	if not saw_ad:
		push_error("PLAYTHROUGH rewarded confirm did not show")
		quit(1)
		return
	if course == null:
		push_error("PLAYTHROUGH course did not start after the ad")
		quit(1)
		return
	if not Access.is_unlocked():
		push_error("PLAYTHROUGH ad success did not unlock 24 hours")
		quit(1)
		return
	print("PLAYTHROUGH entered course, unlock seconds ", Access.seconds_left())
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


func _has_label(text: String) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and str((n as Label).text).find(text) >= 0 and (n as CanvasItem).visible:
			return true
		for child in n.get_children():
			stack.append(child)
	return false


func _shot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("PLAYTHROUGH screenshot failed " + tag)
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
