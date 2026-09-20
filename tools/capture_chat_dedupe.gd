extends SceneTree
## Prove each patio chat line is drawn once after WSS + HTTPS replays.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/capture_chat_dedupe.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CHAT FAIL explore")
		quit(1)
		return
	for _i in 36:
		await process_frame
		await RenderingServer.frame_post_draw
	var hud := current_scene.get_node_or_null("HUD") if current_scene else null
	if hud == null or not hud.has_method("chat_log_texts"):
		push_error("CHAT FAIL HUD chat log")
		quit(1)
		return
	var packets := [
		{"t": "chat", "ok": true, "msg_id": "cht_local_1", "seq": 21, "ts": 1001, "display_name": "Ada", "body": "cookies up front"},
		{"t": "chat", "ok": true, "msg_id": "cht_local_2", "seq": 22, "ts": 1002, "display_name": "Ada", "body": "who wants a toss"},
		{"t": "chat", "ok": true, "msg_id": "cht_cam_1", "seq": 23, "ts": 1003, "display_name": "Cam", "body": "I do"},
	]
	for msg in packets:
		ExploreNet._on_packet(JSON.stringify(msg))
	## Same ids over WSS echo, HTTPS tick, and a ts-less copy.
	for msg in packets:
		ExploreNet._on_packet(JSON.stringify(msg))
		var echo := msg.duplicate()
		echo.erase("msg_id")
		ExploreNet._on_packet(JSON.stringify(echo))
	ExploreNet.ingest_room_events(packets)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var texts: PackedStringArray = hud.call("chat_log_texts")
	var want := PackedStringArray([
		"Ada: cookies up front",
		"Ada: who wants a toss",
		"Cam: I do",
	])
	var got: Array = []
	for line in texts:
		if str(line).begins_with("Ada:") or str(line).begins_with("Cam:"):
			got.append(str(line))
	if got != Array(want):
		push_error("CHAT FAIL expected %s got %s" % [want, got])
		quit(1)
		return
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CHAT FAIL image")
		quit(1)
		return
	var disk := disk_dir.path_join("explore_chat_dedupe.png")
	var err := img.save_png(disk)
	print("CHAT DEDUPE PASS lines=", got, " -> ", disk, " err=", err)
	quit(0 if err == OK else 1)
