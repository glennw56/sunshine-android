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
	for _i in 72:
		await process_frame
		await RenderingServer.frame_post_draw
	var hud := current_scene.get_node_or_null("HUD") if current_scene else null
	var net := root.get_node_or_null("ExploreNet")
	if hud == null or not hud.has_method("chat_log_texts") or net == null:
		push_error("CHAT FAIL HUD/ExploreNet hud=%s net=%s" % [hud, net])
		quit(1)
		return
	if hud.has_method("_ensure_room_ui"):
		hud.call("_ensure_room_ui")
	var heard: Array = []
	var collector := func(who: String, body: String) -> void:
		heard.append("%s: %s" % [who, body])
	net.connect("chat_received", collector)
	if hud.has_method("push_chat") and not net.is_connected("chat_received", Callable(hud, "push_chat")):
		net.connect("chat_received", Callable(hud, "push_chat"))
	await process_frame
	if net.has_method("reset_chat_dedupe_for_test"):
		net.call("reset_chat_dedupe_for_test")
	print("CHAT debug dock=", hud.get_node_or_null("Root/ChatDock"), " feed=", net.has_method("feed_chat_packet"))
	var packets := [
		{"t": "chat", "ok": true, "msg_id": "cht_qa_local_1", "seq": 91021, "ts": 91001, "display_name": "Ada", "body": "cookies up front"},
		{"t": "chat", "ok": true, "msg_id": "cht_qa_local_2", "seq": 91022, "ts": 91002, "display_name": "Ada", "body": "who wants a toss"},
		{"t": "chat", "ok": true, "msg_id": "cht_qa_cam_1", "seq": 91023, "ts": 91003, "display_name": "Cam", "body": "I do"},
	]
	var first_pass: Array = []
	for msg in packets:
		var raw := JSON.stringify(msg)
		print("CHAT debug json=", raw)
		first_pass.append(str(net.call("feed_chat_packet", raw)))
	var replay_pass: Array = []
	for msg in packets:
		replay_pass.append(str(net.call("feed_chat_packet", JSON.stringify(msg))))
		var echo: Dictionary = (msg as Dictionary).duplicate()
		echo.erase("msg_id")
		replay_pass.append(str(net.call("feed_chat_packet", JSON.stringify(echo))))
	net.call("ingest_room_events", packets)
	print("CHAT debug first=", first_pass, " replay=", replay_pass)
	var want := PackedStringArray([
		"Ada: cookies up front",
		"Ada: who wants a toss",
		"Cam: I do",
	])
	print("CHAT debug heard=", heard)
	if heard != Array(want):
		push_error("CHAT FAIL net emits expected %s got %s" % [want, heard])
		quit(1)
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var texts: PackedStringArray = hud.call("chat_log_texts")
	var got: Array = []
	for line in texts:
		if str(line).begins_with("Ada:") or str(line).begins_with("Cam:"):
			got.append(str(line))
	print("CHAT debug hud=", got)
	if got != Array(want):
		push_error("CHAT FAIL HUD expected %s got %s" % [want, got])
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
