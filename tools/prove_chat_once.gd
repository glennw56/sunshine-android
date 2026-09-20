extends SceneTree
## Prove Explore chat ingest is not an infinite re-read.
##   DISPLAY=:1 godot --path . --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/prove_chat_once.gd
## Optional SUNSHINE_EXPLORE_URL points ticks at a local patio.


const ARTIFACT_DIR := "/opt/cursor/artifacts"
const REVIEW_DIR := "res://export/review"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var code := await _prove()
	quit(code)


func _prove() -> int:
	var heard: Array = []
	ExploreNet.chat_received.connect(func(who: String, body: String) -> void:
		heard.append("%s: %s" % [who, body])
	)
	var replay := {
		"net_id": "net_prove",
		"event_seq": 3,
		"players": [],
		"projectiles": [],
		"events": [
			{"t": "chat", "ok": true, "seq": 1, "msg_id": "msg_a", "display_name": "Ada", "body": "alpha"},
			{"t": "chat", "ok": true, "seq": 2, "msg_id": "msg_b", "display_name": "Bo", "body": "bravo"},
			{"t": "chat", "ok": true, "seq": 3, "msg_id": "msg_c", "display_name": "Cam", "body": "charlie"},
		],
	}
	for _i in 24:
		ExploreNet._apply_tick(replay)
	if heard.size() != 3:
		push_error("CHAT-ONCE FAIL ingest replayed chats: %s" % str(heard))
		return 1
	if ExploreNet._event_seq != 3:
		push_error("CHAT-ONCE FAIL event_seq should advance to 3, got %s" % ExploreNet._event_seq)
		return 1
	print("CHAT-ONCE ingest OK heard=", heard, " event_seq=", ExploreNet._event_seq)

	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CHAT-ONCE FAIL explore scene")
		return 1
	for _i in 20:
		await process_frame
		await RenderingServer.frame_post_draw
	ExploreNet.leave_patio()
	heard.clear()

	var hud := current_scene.get_node_or_null("HUD") if current_scene else null
	if hud == null:
		push_error("CHAT-ONCE FAIL HUD missing")
		return 1
	_clear_chat_lines(hud)
	for _i in 8:
		ExploreNet._apply_tick(replay)
		await process_frame
	var after_first := _chat_line_count(hud)
	if after_first != 3:
		push_error("CHAT-ONCE FAIL HUD should show 3 lines after first ingest, got %d" % after_first)
		return 1
	if not _shot("explore_chat_three_once"):
		return 1

	for _i in 20:
		ExploreNet._apply_tick(replay)
		await process_frame
	var after_replay := _chat_line_count(hud)
	if after_replay != 3:
		push_error("CHAT-ONCE FAIL HUD grew on replay: %d" % after_replay)
		return 1
	if not _shot("explore_chat_still_three_after_replay"):
		return 1

	var extra := {
		"net_id": "net_prove",
		"event_seq": 4,
		"players": [],
		"events": [
			{"t": "chat", "ok": true, "seq": 4, "msg_id": "msg_d", "display_name": "Ada", "body": "delta"},
		],
	}
	ExploreNet._apply_tick(extra)
	for _i in 8:
		ExploreNet._apply_tick(replay)
		ExploreNet._apply_tick(extra)
		await process_frame
		await RenderingServer.frame_post_draw
	var after_delta := _chat_line_count(hud)
	if after_delta != 4:
		push_error("CHAT-ONCE FAIL HUD should add one new line, got %d" % after_delta)
		return 1
	if heard.size() != 4:
		push_error("CHAT-ONCE FAIL signal count should stay 4, got %s" % str(heard))
		return 1
	if not _shot("explore_chat_four_still_once"):
		return 1
	print("CHAT-ONCE HUD OK lines=", after_delta, " heard=", heard)
	ExploreNet.leave_patio()
	return 0


func _chat_line_count(hud: Node) -> int:
	var lines := hud.get_node_or_null("Root/ChatDock/Col/ChatLog/Lines")
	return lines.get_child_count() if lines else -1


func _clear_chat_lines(hud: Node) -> void:
	var lines := hud.get_node_or_null("Root/ChatDock/Col/ChatLog/Lines")
	if lines == null:
		return
	for child in lines.get_children():
		lines.remove_child(child)
		child.queue_free()


func _shot(stem: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
	var review := ProjectSettings.globalize_path(REVIEW_DIR)
	DirAccess.make_dir_recursive_absolute(review)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CHAT-ONCE FAIL screenshot %s" % stem)
		return false
	var art := "%s/%s.png" % [ARTIFACT_DIR, stem]
	var disk := review.path_join("%s.png" % stem)
	var err_a := img.save_png(art)
	var err_b := img.save_png(disk)
	print("CHAT-ONCE shot ", stem, " ", img.get_width(), "x", img.get_height(), " art=", err_a, " review=", err_b)
	return err_a == OK and err_b == OK
