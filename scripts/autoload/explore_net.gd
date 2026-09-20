extends Node
## Patio client. Prefer WebSocket; fall back to HTTPS /explore/tick if WSS TLS fails.

signal room_changed
signal chat_received(display_name: String, body: String)
signal remote_updated
signal throw_received(payload: Dictionary)

const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")

var socket: WebSocketPeer
var connected := false
var net_id: String = ""
var room_id: String = "patio"
var status_text: String = "Patio offline"
var remotes: Dictionary = {}
var _player: Node3D
var _send_acc: float = 0.0
var _seen_throws: Dictionary = {}
var _hello_sent := false
var _http_mode := false
var _http_busy := false
var _pending_throw: Dictionary = {}
var _pending_chat: String = ""
var muted_names: Dictionary = {}


func _process(delta: float) -> void:
	if _http_mode:
		if _player and is_instance_valid(_player):
			_send_acc += delta
			if _send_acc >= 0.12:
				_send_acc = 0.0
				_http_tick()
		return
	if socket == null:
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connected and not _hello_sent:
			connected = true
			_send_hello()
		while socket.get_available_packet_count() > 0:
			_on_packet(socket.get_packet().get_string_from_utf8())
		if _player and is_instance_valid(_player):
			_send_acc += delta
			if _send_acc >= 0.1:
				_send_acc = 0.0
				_send_state()
	elif state == WebSocketPeer.STATE_CLOSING or state == WebSocketPeer.STATE_CLOSED:
		if _hello_sent or connected:
			_use_http("Patio using HTTPS")
		elif socket.get_available_packet_count() == 0 and not _http_mode:
			_use_http("Patio using HTTPS")


func enter_patio(player: Node3D) -> void:
	_player = player
	status_text = "Joining patio…"
	room_changed.emit()
	_connect()


func leave_patio() -> void:
	_player = null
	_http_mode = false
	if socket:
		socket.close()
	_drop("Left patio")


func send_throw(origin: Vector3, direction: Vector3, proj_id: String) -> void:
	_seen_throws[proj_id] = true
	var payload := {
		"t": "throw",
		"proj_id": proj_id,
		"ox": origin.x,
		"oy": origin.y,
		"oz": origin.z,
		"dx": direction.x,
		"dy": direction.y,
		"dz": direction.z,
	}
	if _http_mode:
		_pending_throw = payload
		return
	if not connected:
		return
	_send(payload)


func send_chat(body: String) -> void:
	if _http_mode:
		_pending_chat = body
		return
	if not connected:
		chat_received.emit("Patio", "Not connected yet.")
		return
	_send({"t": "chat", "body": body})


func mute_display_name(display_name: String) -> void:
	var key := display_name.strip_edges()
	if key == "":
		return
	muted_names[key] = true


func player_count() -> int:
	return remotes.size() + (1 if connected or _http_mode else 0)


func _connect() -> void:
	if socket:
		socket.close()
	socket = WebSocketPeer.new()
	_hello_sent = false
	connected = false
	_http_mode = false
	var url := AppConfig.explore_ws_url()
	if url == "":
		_use_http("Patio using HTTPS")
		return
	var err := socket.connect_to_url(url)
	if err != OK:
		_use_http("Patio using HTTPS")


func _use_http(reason: String) -> void:
	if socket:
		socket.close()
	socket = null
	_http_mode = true
	connected = false
	status_text = reason
	room_changed.emit()
	_http_tick()


func _send_hello() -> void:
	_hello_sent = true
	var ticket := await _mint_ticket()
	_send({
		"t": "hello",
		"protocol": CosContracts.PROTOCOL_VERSION,
		"player_id": ProfileStore.player_id,
		"username": ProfileStore.username,
		"display_name": ProfileStore.display_name if ProfileStore.display_name != "" else "Sunshine Guest",
		"avatar": ProfileStore.current_avatar(),
		"room_id": "patio",
		"ticket": ticket,
	})


func _mint_ticket() -> Dictionary:
	var url := AppConfig.explore_ticket_api()
	if url == "":
		return {}
	var body := JSON.stringify({"player_id": ProfileStore.player_id, "room_id": "patio"})
	var result: Dictionary = await AccountClient.request_account_json(url, HTTPClient.METHOD_POST, body, false)
	if bool(result.get("ok", false)) and result.get("data") is Dictionary:
		return result["data"]
	return {}


func _send_state() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var moving := false
	if _player is CharacterBody3D:
		var vel: Vector3 = (_player as CharacterBody3D).velocity
		moving = Vector2(vel.x, vel.z).length() > 0.15
	_send({
		"t": "state",
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"z": _player.global_position.z,
		"yaw": _player.rotation.y,
		"moving": moving,
		"display_name": ProfileStore.display_name,
		"avatar": ProfileStore.current_avatar(),
	})


func _http_tick() -> void:
	if _http_busy or _player == null or not is_instance_valid(_player):
		return
	_http_busy = true
	var moving := false
	if _player is CharacterBody3D:
		var vel: Vector3 = (_player as CharacterBody3D).velocity
		moving = Vector2(vel.x, vel.z).length() > 0.15
	var body := {
		"protocol": CosContracts.PROTOCOL_VERSION,
		"net_id": net_id,
		"player_id": ProfileStore.player_id,
		"username": ProfileStore.username,
		"display_name": ProfileStore.display_name if ProfileStore.display_name != "" else "Sunshine Guest",
		"avatar": ProfileStore.current_avatar(),
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"z": _player.global_position.z,
		"yaw": _player.rotation.y,
		"moving": moving,
	}
	if not _pending_throw.is_empty():
		body["throw"] = _pending_throw
		_pending_throw = {}
	if _pending_chat != "":
		body["chat"] = _pending_chat
		_pending_chat = ""
	var result: Dictionary = await AccountClient.request_account_json(
		AppConfig.explore_tick_api(), HTTPClient.METHOD_POST, JSON.stringify(body), false
	)
	_http_busy = false
	if not bool(result.get("ok", false)):
		status_text = "Patio HTTPS failed"
		room_changed.emit()
		return
	var data: Variant = result.get("data", {})
	if data is Dictionary:
		_apply_tick(data)


func _apply_tick(data: Dictionary) -> void:
	if str(data.get("net_id", "")) != "":
		net_id = str(data.get("net_id"))
	status_text = "Patio · live"
	_http_mode = true
	_ingest_players(data.get("players", []))
	var events: Variant = data.get("events", [])
	if events is Array:
		for ev in events:
			if ev is Dictionary:
				_on_packet(JSON.stringify(ev))
	remote_updated.emit()
	room_changed.emit()


func _send(payload: Dictionary) -> void:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(JSON.stringify(payload))


func _on_packet(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return
	var msg: Dictionary = parsed
	var kind := str(msg.get("t", ""))
	if kind == "welcome":
		net_id = str(msg.get("net_id", ""))
		room_id = str(msg.get("room_id", "patio"))
		status_text = "Patio · live"
		_ingest_players(msg.get("players", []))
		room_changed.emit()
		return
	if kind == "snapshot" or kind == "join":
		if kind == "join" and msg.get("player") is Dictionary:
			_upsert_remote(msg["player"])
		_ingest_players(msg.get("players", []))
		remote_updated.emit()
		room_changed.emit()
		return
	if kind == "leave":
		remotes.erase(str(msg.get("net_id", "")))
		remote_updated.emit()
		room_changed.emit()
		return
	if kind == "throw":
		var proj := str(msg.get("proj_id", ""))
		if proj != "" and _seen_throws.has(proj):
			return
		if proj != "":
			_seen_throws[proj] = true
		throw_received.emit(msg)
		return
	if kind == "chat":
		if bool(msg.get("ok", true)) == false:
			chat_received.emit("Patio", str(msg.get("error", "Chat blocked.")))
			return
		var who := str(msg.get("display_name", "Baker"))
		if muted_names.has(who):
			return
		chat_received.emit(who, str(msg.get("body", "")))
		return
	if str(msg.get("error", "")) != "":
		status_text = str(msg.get("error"))
		room_changed.emit()


func _ingest_players(rows: Variant) -> void:
	if not rows is Array:
		return
	for row in rows:
		if row is Dictionary:
			_upsert_remote(row)


func _upsert_remote(row: Dictionary) -> void:
	var nid := str(row.get("net_id", ""))
	if nid == "" or nid == net_id:
		return
	remotes[nid] = row


func _drop(reason: String) -> void:
	connected = false
	_hello_sent = false
	_http_mode = false
	net_id = ""
	remotes.clear()
	status_text = reason
	socket = null
	room_changed.emit()
	remote_updated.emit()
