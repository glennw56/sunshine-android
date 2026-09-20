extends SceneTree
## Editor / CI two-client patio proof (HTTPS tick — same path phones use when WSS TLS fails).
##   godot --headless --path . --script res://tools/two_client_patio.gd
## Optional env SUNSHINE_EXPLORE_URL overrides project.godot.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var code := await _prove()
	quit(code)


func _prove() -> int:
	var origin := OS.get_environment("SUNSHINE_EXPLORE_URL").strip_edges().rstrip("/")
	if origin == "":
		origin = str(ProjectSettings.get_setting("sunshine/explore_base_url", "")).strip_edges().rstrip("/")
	if origin == "":
		push_error("TWO-CLIENT FAIL no explore origin")
		return 1
	var ada: Dictionary = await _tick(origin, {
		"protocol": 1,
		"player_id": "plr_editor_ada",
		"display_name": "Ada",
		"x": 1.0,
		"y": 0.02,
		"z": 11.0,
	})
	var _bo: Dictionary = await _tick(origin, {
		"protocol": 1,
		"player_id": "plr_editor_bo",
		"display_name": "Bo",
		"x": -1.4,
		"y": 0.02,
		"z": 10.2,
	})
	var again: Dictionary = await _tick(origin, {
		"protocol": 1,
		"net_id": str(ada.get("net_id", "")),
		"player_id": "plr_editor_ada",
		"display_name": "Ada",
		"x": 1.2,
		"y": 0.02,
		"z": 10.7,
	})
	var names: PackedStringArray = PackedStringArray()
	var rows: Variant = again.get("players", [])
	if rows is Array:
		for row in rows:
			if row is Dictionary:
				names.append(str(row.get("display_name", "")))
	print("TWO-CLIENT origin=", origin, " names=", names)
	if names.find("Ada") < 0 or names.find("Bo") < 0:
		push_error("TWO-CLIENT FAIL both display names should appear")
		return 1
	var sent: Dictionary = await _tick(origin, {
		"protocol": 1,
		"net_id": str(ada.get("net_id", "")),
		"player_id": "plr_editor_ada",
		"display_name": "Ada",
		"event_seq": int(ada.get("event_seq") or 0),
		"chat": "hello once",
	})
	var chats: Array = []
	var events: Variant = sent.get("events", [])
	if events is Array:
		for ev in events:
			if ev is Dictionary and str(ev.get("t", "")) == "chat":
				chats.append(ev)
	if chats.size() != 1 or str(chats[0].get("body", "")) != "hello once":
		push_error("TWO-CLIENT FAIL chat should appear once on the send tick")
		return 1
	var cursor := int(sent.get("event_seq") or 0)
	var replay: Dictionary = await _tick(origin, {
		"protocol": 1,
		"net_id": str(ada.get("net_id", "")),
		"player_id": "plr_editor_ada",
		"display_name": "Ada",
		"event_seq": cursor,
	})
	var again_chats := 0
	var replay_events: Variant = replay.get("events", [])
	if replay_events is Array:
		for ev in replay_events:
			if ev is Dictionary and str(ev.get("t", "")) == "chat":
				again_chats += 1
	if again_chats != 0:
		push_error("TWO-CLIENT FAIL advanced event_seq still returned chat")
		return 1
	print("TWO-CLIENT OK")
	return 0


func _tick(origin: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	var err := http.request(
		origin + "/explore/tick",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		push_error("TWO-CLIENT FAIL request %s" % err)
		return {}
	var done: Array = await http.request_completed
	http.queue_free()
	if int(done[1]) < 200 or int(done[1]) >= 300:
		push_error("TWO-CLIENT FAIL HTTP %s" % done[1])
		return {}
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}
