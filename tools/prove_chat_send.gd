extends SceneTree
## Send several chats over HTTPS tick (phone fallback) and prove each appears once.
##   SUNSHINE_EXPLORE_URL=http://127.0.0.1:8088 DISPLAY=:1 godot --path . \
##     --rendering-method gl_compatibility --resolution 720x1280 \
##     -s res://tools/prove_chat_send.gd


const ARTIFACT_DIR := "/opt/cursor/artifacts"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	quit(await _prove())


func _prove() -> int:
	var net: Node = root.get_node_or_null("ExploreNet")
	if net == null:
		push_error("CHAT-SEND FAIL ExploreNet missing")
		return 1
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CHAT-SEND FAIL explore scene")
		return 1
	for _i in 30:
		await process_frame
		await RenderingServer.frame_post_draw
	var hud := current_scene.get_node_or_null("HUD")
	if hud == null:
		push_error("CHAT-SEND FAIL HUD")
		return 1
	net.call("_use_http", "Patio using HTTPS")
	var player: Node = current_scene.get_node_or_null("Player")
	if player:
		net.set("_player", player)
	for _i in 20:
		await process_frame
	_clear_chat(hud)
	var bodies := ["hello once", "second line", "third line"]
	for body in bodies:
		net.call("send_chat", body)
		var waited := 0
		while waited < 90:
			await process_frame
			waited += 1
			if _has_body(hud, body):
				break
		if not _has_body(hud, body):
			push_error("CHAT-SEND FAIL missing %s in %s" % [body, _line_texts(hud)])
			return 1
		for _j in 90:
			await process_frame
	var after_send := _chat_count(hud)
	if after_send != 3:
		push_error("CHAT-SEND FAIL expected 3 after send, got %d %s" % [after_send, _line_texts(hud)])
		return 1
	if not _shot("explore_chat_sent_three"):
		return 1
	for _i in 80:
		await process_frame
	var after_wait := _chat_count(hud)
	if after_wait != 3:
		push_error("CHAT-SEND FAIL log grew after idle ticks: %d %s" % [after_wait, _line_texts(hud)])
		return 1
	if not _shot("explore_chat_sent_three_after_idle"):
		return 1
	print("CHAT-SEND OK lines=", after_wait, " texts=", _line_texts(hud), " seq=", net.get("_event_seq"))
	net.call("leave_patio")
	return 0


func _chat_count(hud: Node) -> int:
	var lines := hud.get_node_or_null("Root/ChatDock/Col/ChatLog/Lines")
	return lines.get_child_count() if lines else -1


func _has_body(hud: Node, body: String) -> bool:
	for line in _line_texts(hud):
		if str(line).find(body) >= 0:
			return true
	return false


func _line_texts(hud: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var lines := hud.get_node_or_null("Root/ChatDock/Col/ChatLog/Lines")
	if lines == null:
		return out
	for row in lines.get_children():
		var parts: PackedStringArray = PackedStringArray()
		for child in row.get_children():
			if child is Label:
				parts.append((child as Label).text)
		out.append(" ".join(parts))
	return out


func _clear_chat(hud: Node) -> void:
	var lines := hud.get_node_or_null("Root/ChatDock/Col/ChatLog/Lines")
	if lines == null:
		return
	for child in lines.get_children():
		lines.remove_child(child)
		child.queue_free()


func _shot(stem: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("CHAT-SEND FAIL shot %s" % stem)
		return false
	var err := img.save_png("%s/%s.png" % [ARTIFACT_DIR, stem])
	print("CHAT-SEND shot ", stem, " err=", err)
	return err == OK
