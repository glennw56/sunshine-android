extends Node
## Test-world mini-golf board client.
## Posts a finished round and reads the shared top 10.
## Offline play keeps the last list in user:// and shows it on the gate board.
## This never calls the patio, drinks, or Square hosts.

const Scores := preload("res://scripts/minigolf/scores.gd")

const QUEUE_PATH := "user://minigolf_outbox.cfg"
const GLOBAL_PATH := "user://minigolf_global.cfg"

signal score_posted(result: Dictionary)
signal top_updated(rows: Array, online: bool)

var _phase := ""
var _online := false
var _want_top := false
var _retry_armed := false


func _ready() -> void:
	call_deferred("flush")


func enabled() -> bool:
	return AppConfig != null and AppConfig.minigolf_api_origin() != ""


func display_rows() -> Dictionary:
	if _online:
		return {"rows": _read_global(), "source": "global"}
	var cached := _read_global()
	if not cached.is_empty():
		return {"rows": cached, "source": "cache"}
	return {"rows": Scores.entries(), "source": "local"}


func submit_round(holes: Array, total: int, par: int, duration_sec: int) -> void:
	if not enabled() or holes.size() != 18 or duration_sec < 1:
		return
	var counts: Array = []
	for hole in holes:
		counts.append(int(hole))
	var row := {
		"holes": counts,
		"total": total,
		"par": par,
		"duration_sec": duration_sec,
		"client_version": str(ProjectSettings.get_setting("application/config/version", "")),
	}
	var list := _read_queue()
	if not list.is_empty():
		var last: Dictionary = list[list.size() - 1]
		if int(last.get("total", -1)) == total and _same_holes(last.get("holes"), counts):
			flush()
			return
	list.append(row)
	if list.size() > 8:
		list = list.slice(list.size() - 8, list.size())
	_write_queue(list)
	print("BOARD queue %d" % list.size())
	flush()


func flush() -> void:
	_kick()


func fetch_top() -> void:
	_want_top = true
	_kick()


func _kick() -> void:
	if _phase != "" or not enabled():
		return
	var pending := _read_queue()
	if not pending.is_empty():
		var token := ""
		if GameSave:
			token = str(GameSave.session_token).strip_edges()
		if token == "":
			print("BOARD queue waiting for a session")
		else:
			_phase = "account"
			_request(HTTPClient.METHOD_POST, "/minigolf/account", {"display_name": Scores.player_name()})
			return
	if _want_top:
		_want_top = false
		_phase = "top"
		_request(HTTPClient.METHOD_GET, "/minigolf/top?limit=10", {})


func _request(method: int, path: String, body: Dictionary) -> void:
	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if GameSave:
		var token := str(GameSave.session_token).strip_edges()
		if token != "":
			headers.append("Authorization: Bearer " + token)
	var authed := false
	if GameSave:
		authed = str(GameSave.session_token).strip_edges() != ""
	var verb := "GET" if method == HTTPClient.METHOD_GET else "POST"
	print("BOARD send %s %s auth %s" % [verb, AppConfig.minigolf_api_origin() + path, "yes" if authed else "no"])
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, response_headers: PackedStringArray, response_body: PackedByteArray) -> void:
		_on_http(result, code, response_headers, response_body)
		if is_instance_valid(http):
			http.queue_free()
	, CONNECT_ONE_SHOT)
	var err := http.request(AppConfig.minigolf_api_origin() + path, headers, method, payload)
	if err != OK:
		_phase = ""
		_online = false
		print("BOARD request failed ", err)
		http.queue_free()
		_arm_retry()


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var phase := _phase
	_phase = ""
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300 and bool(data.get("ok", false))
	if phase == "account":
		if ok:
			var pending := _read_queue()
			if pending.is_empty():
				_kick()
				return
			var row: Dictionary = pending[0]
			_phase = "score"
			_request(HTTPClient.METHOD_POST, "/minigolf/score", {
				"holes": row.get("holes", []),
				"total": int(row.get("total", 0)),
				"par": int(row.get("par", 0)),
				"duration_sec": int(row.get("duration_sec", 0)),
				"client_version": str(row.get("client_version", "")),
			})
			return
		print("BOARD account result %d code %d bytes %d %s" % [result, code, body.size(), str(data.get("error", ""))])
		# An expired session still gets one score post, with no name in the body,
		# so the score route can reject it and the round stays queued.
		if (code == 401 or code == 403) and not _read_queue().is_empty():
			var row: Dictionary = _read_queue()[0]
			_phase = "score"
			_request(HTTPClient.METHOD_POST, "/minigolf/score", {
				"holes": row.get("holes", []),
				"total": int(row.get("total", 0)),
				"par": int(row.get("par", 0)),
				"duration_sec": int(row.get("duration_sec", 0)),
				"client_version": str(row.get("client_version", "")),
			})
			return
		_arm_retry()
		return
	elif phase == "score":
		if ok:
			_dequeue()
			print("BOARD posted rank %s new_best %s" % [str(data.get("rank", "")), str(data.get("new_best", false))])
			score_posted.emit(data)
			_want_top = true
		elif code == 400:
			_dequeue()
			print("BOARD reject %s" % str(data.get("error", "")))
		else:
			print("BOARD post failed result %d code %d bytes %d %s" % [result, code, body.size(), str(data.get("error", ""))])
			_arm_retry()
			return
	elif phase == "top":
		if ok:
			var rows: Array = data.get("rows", [])
			_write_global(rows)
			_online = true
			print("BOARD online %d" % rows.size())
			top_updated.emit(rows, true)
		else:
			_online = false
			print("BOARD offline")
			top_updated.emit(_read_global(), false)
	_kick()


func _arm_retry() -> void:
	if _retry_armed:
		return
	_retry_armed = true
	_retry_later()


func _retry_later() -> void:
	await get_tree().create_timer(4.0).timeout
	_retry_armed = false
	_kick()


func _same_holes(stored: Variant, counts: Array) -> bool:
	if not stored is Array or stored.size() != counts.size():
		return false
	for i in counts.size():
		if int(stored[i]) != int(counts[i]):
			return false
	return true


func _dequeue() -> void:
	var list := _read_queue()
	if list.is_empty():
		return
	list.pop_front()
	_write_queue(list)


func _read_queue() -> Array:
	return _read_rows(QUEUE_PATH)


func _write_queue(list: Array) -> void:
	_write_rows(QUEUE_PATH, list)


func _read_global() -> Array:
	return _read_rows(GLOBAL_PATH)


func _write_global(rows: Array) -> void:
	_write_rows(GLOBAL_PATH, rows)


func _read_rows(path: String) -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return []
	var parsed: Variant = JSON.parse_string(str(cfg.get_value("board", "rows", "[]")))
	if parsed is Array:
		return parsed
	return []


func _write_rows(path: String, rows: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("board", "rows", JSON.stringify(rows))
	cfg.save(path)
